#!/usr/bin/env python3
"""Genere et sert une page de revue pour les resultats d'evaluation.

Lit le dossier de l'espace de travail, decouvre les essais (dossiers avec
outputs/), embarque toutes les donnees de sortie dans une page HTML
autonome, et la sert via un petit serveur HTTP. Les retours s'enregistrent
automatiquement dans feedback.json, dans l'espace de travail.

Usage :
    python generate_review.py <chemin-espace-de-travail> [--port PORT] [--skill-name NOM]
    python generate_review.py <chemin-espace-de-travail> --previous-feedback /chemin/vers/ancien/feedback.json

Aucune dependance au-dela de la bibliotheque standard de Python.
"""

import argparse
import base64
import json
import mimetypes
import os
import re
import signal
import subprocess
import sys
import time
import webbrowser
from functools import partial
from http.server import HTTPServer, BaseHTTPRequestHandler
from pathlib import Path

# Fichiers exclus des listes de sorties
METADATA_FILES = {"transcript.md", "user_notes.md", "metrics.json"}

# Extensions rendues en texte incorpore
TEXT_EXTENSIONS = {
    ".txt", ".md", ".json", ".csv", ".py", ".js", ".ts", ".tsx", ".jsx",
    ".yaml", ".yml", ".xml", ".html", ".css", ".sh", ".rb", ".go", ".rs",
    ".java", ".c", ".cpp", ".h", ".hpp", ".sql", ".r", ".toml",
}

# Extensions rendues en image incorporee
IMAGE_EXTENSIONS = {".png", ".jpg", ".jpeg", ".gif", ".svg", ".webp"}

# Types MIME forces pour les extensions courantes
MIME_OVERRIDES = {
    ".svg": "image/svg+xml",
    ".xlsx": "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
    ".docx": "application/vnd.openxmlformats-officedocument.wordprocessingml.document",
    ".pptx": "application/vnd.openxmlformats-officedocument.presentationml.presentation",
}


def get_mime_type(path: Path) -> str:
    ext = path.suffix.lower()
    if ext in MIME_OVERRIDES:
        return MIME_OVERRIDES[ext]
    mime, _ = mimetypes.guess_type(str(path))
    return mime or "application/octet-stream"


def find_runs(workspace: Path) -> list[dict]:
    """Trouve recursivement les dossiers qui contiennent un sous-dossier outputs/."""
    runs: list[dict] = []
    _find_runs_recursive(workspace, workspace, runs)
    # « r.get("eval_id") if ... is not None else float("inf") », PAS
    # « r.get("eval_id", float("inf")) » : .get() ne rend son defaut QUE si
    # la CLE manque, jamais quand elle vaut explicitement None — ce que
    # build_run() ecrit des que eval_metadata.json manque ou n'a pas
    # d'eval_id. Comparer None a un entier leve TypeError des le premier tri,
    # et find_runs() est appele a CHAQUE requete par ReviewHandler.do_GET :
    # un seul dossier sans metadonnees rendait le visualiseur entier
    # inaccessible (500 sur chaque chargement).
    runs.sort(key=lambda r: (
        r.get("eval_id") if r.get("eval_id") is not None else float("inf"),
        r["id"],
    ))
    return runs


def _find_runs_recursive(root: Path, current: Path, runs: list[dict]) -> None:
    if not current.is_dir():
        return

    outputs_dir = current / "outputs"
    if outputs_dir.is_dir():
        run = build_run(root, current)
        if run:
            runs.append(run)
        return

    skip = {"node_modules", ".git", "__pycache__", "skill", "inputs"}
    for child in sorted(current.iterdir()):
        if child.is_dir() and child.name not in skip:
            _find_runs_recursive(root, child, runs)


def build_run(root: Path, run_dir: Path) -> dict | None:
    """Construit le dict d'un essai : requete, sorties, donnees de notation."""
    prompt = ""
    eval_id = None

    # Essaie eval_metadata.json
    for candidate in [run_dir / "eval_metadata.json", run_dir.parent / "eval_metadata.json"]:
        if candidate.exists():
            try:
                metadata = json.loads(candidate.read_text())
                prompt = metadata.get("prompt", "")
                eval_id = metadata.get("eval_id")
            except (json.JSONDecodeError, OSError):
                pass
            if prompt:
                break

    # Repli sur transcript.md
    if not prompt:
        for candidate in [run_dir / "transcript.md", run_dir / "outputs" / "transcript.md"]:
            if candidate.exists():
                try:
                    text = candidate.read_text()
                    match = re.search(r"## Eval Prompt\n\n([\s\S]*?)(?=\n##|$)", text)
                    if match:
                        prompt = match.group(1).strip()
                except OSError:
                    pass
                if prompt:
                    break

    if not prompt:
        prompt = "(No prompt found)"

    run_id = str(run_dir.relative_to(root)).replace("/", "-").replace("\\", "-")

    # Recueille les fichiers de sortie
    outputs_dir = run_dir / "outputs"
    output_files: list[dict] = []
    if outputs_dir.is_dir():
        for f in sorted(outputs_dir.iterdir()):
            if f.is_file() and f.name not in METADATA_FILES:
                output_files.append(embed_file(f))

    # Charge la notation, si presente
    grading = None
    for candidate in [run_dir / "grading.json", run_dir.parent / "grading.json"]:
        if candidate.exists():
            try:
                grading = json.loads(candidate.read_text())
            except (json.JSONDecodeError, OSError):
                pass
            if grading:
                break

    return {
        "id": run_id,
        "prompt": prompt,
        "eval_id": eval_id,
        "outputs": output_files,
        "grading": grading,
    }


def embed_file(path: Path) -> dict:
    """Lit un fichier et rend sa representation incorporee."""
    ext = path.suffix.lower()
    mime = get_mime_type(path)

    if ext in TEXT_EXTENSIONS:
        try:
            content = path.read_text(errors="replace")
        except OSError:
            content = "(Error reading file)"
        return {
            "name": path.name,
            "type": "text",
            "content": content,
        }
    elif ext in IMAGE_EXTENSIONS:
        try:
            raw = path.read_bytes()
            b64 = base64.b64encode(raw).decode("ascii")
        except OSError:
            return {"name": path.name, "type": "error", "content": "(Error reading file)"}
        return {
            "name": path.name,
            "type": "image",
            "mime": mime,
            "data_uri": f"data:{mime};base64,{b64}",
        }
    elif ext == ".pdf":
        try:
            raw = path.read_bytes()
            b64 = base64.b64encode(raw).decode("ascii")
        except OSError:
            return {"name": path.name, "type": "error", "content": "(Error reading file)"}
        return {
            "name": path.name,
            "type": "pdf",
            "data_uri": f"data:{mime};base64,{b64}",
        }
    elif ext == ".xlsx":
        try:
            raw = path.read_bytes()
            b64 = base64.b64encode(raw).decode("ascii")
        except OSError:
            return {"name": path.name, "type": "error", "content": "(Error reading file)"}
        return {
            "name": path.name,
            "type": "xlsx",
            "data_b64": b64,
        }
    else:
        # Binaire / inconnu — lien de telechargement en base64
        try:
            raw = path.read_bytes()
            b64 = base64.b64encode(raw).decode("ascii")
        except OSError:
            return {"name": path.name, "type": "error", "content": "(Error reading file)"}
        return {
            "name": path.name,
            "type": "binary",
            "mime": mime,
            "data_uri": f"data:{mime};base64,{b64}",
        }


def load_previous_iteration(workspace: Path) -> dict[str, dict]:
    """Charge les retours et sorties de l'iteration precedente.

    Rend une correspondance run_id -> {"feedback": str, "outputs": list[dict]}.
    """
    result: dict[str, dict] = {}

    # Charge les retours
    feedback_map: dict[str, str] = {}
    feedback_path = workspace / "feedback.json"
    if feedback_path.exists():
        try:
            data = json.loads(feedback_path.read_text())
            feedback_map = {
                r["run_id"]: r["feedback"]
                for r in data.get("reviews", [])
                if r.get("feedback", "").strip()
            }
        except (json.JSONDecodeError, OSError, KeyError):
            pass

    # Charge les essais (pour recuperer les sorties)
    prev_runs = find_runs(workspace)
    for run in prev_runs:
        result[run["id"]] = {
            "feedback": feedback_map.get(run["id"], ""),
            "outputs": run.get("outputs", []),
        }

    # Ajoute aussi les retours des run_id qui en avaient sans essai correspondant
    for run_id, fb in feedback_map.items():
        if run_id not in result:
            result[run_id] = {"feedback": fb, "outputs": []}

    return result


def generate_html(
    runs: list[dict],
    skill_name: str,
    previous: dict[str, dict] | None = None,
    benchmark: dict | None = None,
) -> str:
    """Genere la page HTML autonome complete, donnees incorporees."""
    template_path = Path(__file__).parent / "viewer.html"
    template = template_path.read_text()

    # Construit les correspondances previous_feedback et previous_outputs pour le gabarit
    previous_feedback: dict[str, str] = {}
    previous_outputs: dict[str, list[dict]] = {}
    if previous:
        for run_id, data in previous.items():
            if data.get("feedback"):
                previous_feedback[run_id] = data["feedback"]
            if data.get("outputs"):
                previous_outputs[run_id] = data["outputs"]

    embedded = {
        "skill_name": skill_name,
        "runs": runs,
        "previous_feedback": previous_feedback,
        "previous_outputs": previous_outputs,
    }
    if benchmark:
        embedded["benchmark"] = benchmark

    # « </ » -> « <\/ » : json.dumps() n'echappe jamais les barres obliques,
    # et TEXT_EXTENSIONS embarque le contenu integral de fichiers .md/.html/
    # .js/.py comme valeurs de chaine JSON. N'IMPORTE QUEL contenu embarque
    # portant « </script> » (une transcription qui en parle, une preuve de
    # code HTML citee par le correcteur…) coupe alors la vraie balise
    # <script> du navigateur en plein milieu : EMBEDDED_DATA n'est jamais
    # defini, init() leve un ReferenceError, et la page reste blanche sans
    # la moindre explication a l'ecran. Le tokenizer HTML5 ferme le script
    # des qu'il voit « </script> » litteralement, meme a l'interieur d'une
    # chaine JavaScript — le contexte JS ne le protege pas.
    data_json = json.dumps(embedded).replace("</", r"<\/")

    return template.replace("/*__EMBEDDED_DATA__*/", f"const EMBEDDED_DATA = {data_json};")


# ---------------------------------------------------------------------------
# Serveur HTTP (bibliotheque standard seule, aucune dependance)
# ---------------------------------------------------------------------------

def _kill_port(port: int) -> None:
    """Termine tout processus qui ecoute sur ce port."""
    try:
        result = subprocess.run(
            ["lsof", "-ti", f":{port}"],
            capture_output=True, text=True, timeout=5,
        )
        for pid_str in result.stdout.strip().split("\n"):
            if pid_str.strip():
                try:
                    os.kill(int(pid_str.strip()), signal.SIGTERM)
                except (ProcessLookupError, ValueError):
                    pass
        if result.stdout.strip():
            time.sleep(0.5)
    except subprocess.TimeoutExpired:
        pass
    except FileNotFoundError:
        print("Note: lsof not found, cannot check if port is in use", file=sys.stderr)

class ReviewHandler(BaseHTTPRequestHandler):
    """Sert le HTML de revue et enregistre les retours.

    Regenere le HTML a chaque chargement de page, pour que rafraichir le
    navigateur recupere de nouvelles sorties d'eval sans redemarrer le serveur.
    """

    def __init__(
        self,
        workspace: Path,
        skill_name: str,
        feedback_path: Path,
        previous: dict[str, dict],
        benchmark_path: Path | None,
        *args,
        **kwargs,
    ):
        self.workspace = workspace
        self.skill_name = skill_name
        self.feedback_path = feedback_path
        self.previous = previous
        self.benchmark_path = benchmark_path
        super().__init__(*args, **kwargs)

    def do_GET(self) -> None:
        if self.path == "/" or self.path == "/index.html":
            # Regenere le HTML a chaque requete (rebalaie l'espace de travail)
            runs = find_runs(self.workspace)
            benchmark = None
            if self.benchmark_path and self.benchmark_path.exists():
                try:
                    benchmark = json.loads(self.benchmark_path.read_text())
                except (json.JSONDecodeError, OSError):
                    pass
            html = generate_html(runs, self.skill_name, self.previous, benchmark)
            content = html.encode("utf-8")
            self.send_response(200)
            self.send_header("Content-Type", "text/html; charset=utf-8")
            self.send_header("Content-Length", str(len(content)))
            self.end_headers()
            self.wfile.write(content)
        elif self.path == "/api/feedback":
            data = b"{}"
            if self.feedback_path.exists():
                data = self.feedback_path.read_bytes()
            self.send_response(200)
            self.send_header("Content-Type", "application/json")
            self.send_header("Content-Length", str(len(data)))
            self.end_headers()
            self.wfile.write(data)
        else:
            self.send_error(404)

    def do_POST(self) -> None:
        if self.path == "/api/feedback":
            length = int(self.headers.get("Content-Length", 0))
            body = self.rfile.read(length)
            try:
                data = json.loads(body)
                if not isinstance(data, dict) or "reviews" not in data:
                    raise ValueError("Expected JSON object with 'reviews' key")
                self.feedback_path.write_text(json.dumps(data, indent=2) + "\n")
                resp = b'{"ok":true}'
                self.send_response(200)
            except (json.JSONDecodeError, OSError, ValueError) as e:
                resp = json.dumps({"error": str(e)}).encode()
                self.send_response(500)
            self.send_header("Content-Type", "application/json")
            self.send_header("Content-Length", str(len(resp)))
            self.end_headers()
            self.wfile.write(resp)
        else:
            self.send_error(404)

    def log_message(self, format: str, *args: object) -> None:
        # Tait la journalisation des requetes pour garder le terminal propre
        pass


def main() -> None:
    parser = argparse.ArgumentParser(description="Genere et sert la revue d'evaluation")
    parser.add_argument("workspace", type=Path, help="Chemin vers le dossier de l'espace de travail")
    parser.add_argument("--port", "-p", type=int, default=3117, help="Port du serveur (par defaut : 3117)")
    parser.add_argument("--skill-name", "-n", type=str, default=None, help="Nom du skill pour l'en-tete")
    parser.add_argument(
        "--previous-workspace", type=Path, default=None,
        help="Chemin vers l'espace de travail de l'iteration precedente (montre les anciennes sorties et retours en contexte)",
    )
    parser.add_argument(
        "--benchmark", type=Path, default=None,
        help="Chemin vers benchmark.json a afficher dans l'onglet Benchmark",
    )
    parser.add_argument(
        "--static", "-s", type=Path, default=None,
        help="Ecrit un HTML autonome a ce chemin plutot que de demarrer un serveur",
    )
    args = parser.parse_args()

    workspace = args.workspace.resolve()
    if not workspace.is_dir():
        print(f"Erreur : {workspace} n'est pas un dossier", file=sys.stderr)
        sys.exit(1)

    runs = find_runs(workspace)
    if not runs:
        print(f"Aucun essai trouve dans {workspace}", file=sys.stderr)
        sys.exit(1)

    skill_name = args.skill_name or workspace.name.replace("-workspace", "")
    feedback_path = workspace / "feedback.json"

    previous: dict[str, dict] = {}
    if args.previous_workspace:
        previous = load_previous_iteration(args.previous_workspace.resolve())

    benchmark_path = args.benchmark.resolve() if args.benchmark else None
    benchmark = None
    if benchmark_path and benchmark_path.exists():
        try:
            benchmark = json.loads(benchmark_path.read_text())
        except (json.JSONDecodeError, OSError):
            pass

    if args.static:
        html = generate_html(runs, skill_name, previous, benchmark)
        args.static.parent.mkdir(parents=True, exist_ok=True)
        args.static.write_text(html)
        print(f"\n  Visualiseur statique ecrit dans : {args.static}\n")
        sys.exit(0)

    # Termine tout processus deja present sur le port vise
    port = args.port
    _kill_port(port)
    handler = partial(ReviewHandler, workspace, skill_name, feedback_path, previous, benchmark_path)
    try:
        server = HTTPServer(("127.0.0.1", port), handler)
    except OSError:
        # Le port est toujours pris apres la tentative — en trouve un libre
        server = HTTPServer(("127.0.0.1", 0), handler)
        port = server.server_address[1]

    url = f"http://localhost:{port}"
    print(f"\n  Visualiseur d'evaluations")
    print(f"  ─────────────────────────────────")
    print(f"  URL :               {url}")
    print(f"  Espace de travail : {workspace}")
    print(f"  Retours :           {feedback_path}")
    if previous:
        print(f"  Precedent :         {args.previous_workspace} ({len(previous)} essai(s))")
    if benchmark_path:
        print(f"  Benchmark :         {benchmark_path}")
    print(f"\n  Ctrl+C pour arreter.\n")

    webbrowser.open(url)

    try:
        server.serve_forever()
    except KeyboardInterrupt:
        print("\nArrete.")
        server.server_close()


if __name__ == "__main__":
    main()
