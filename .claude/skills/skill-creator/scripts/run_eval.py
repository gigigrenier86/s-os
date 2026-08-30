#!/usr/bin/env python3
"""Lance l'evaluation de declenchement pour une description de skill.

Teste si la description d'un skill fait declencher Claude (lire le skill)
pour un jeu de requetes. Rend les resultats en JSON.
"""

import argparse
import json
import os
import select
import subprocess
import sys
import time
import uuid
from concurrent.futures import ProcessPoolExecutor, as_completed
from pathlib import Path

from scripts.utils import parse_skill_md


def find_project_root() -> Path:
    """Trouve la racine du projet en remontant depuis cwd, a la recherche de .claude/.

    Reproduit la facon dont Claude Code trouve sa racine de projet, pour que
    le fichier de commande cree se retrouve la ou « claude -p » ira le chercher.
    """
    current = Path.cwd()
    for parent in [current, *current.parents]:
        if (parent / ".claude").is_dir():
            return parent
    return current


def run_single_query(
    query: str,
    skill_name: str,
    skill_description: str,
    timeout: int,
    project_root: str,
    model: str | None = None,
) -> bool:
    """Lance une seule requete et rend si le skill s'est declenche.

    Cree un fichier de commande dans .claude/commands/ pour qu'il apparaisse
    dans la liste des skills disponibles de Claude, puis lance « claude -p »
    avec la requete brute. Utilise --include-partial-messages pour detecter
    le declenchement tot, depuis les evenements de flux (content_block_start)
    plutot que d'attendre le message complet de l'assistant, qui n'arrive
    qu'apres l'execution des outils.
    """
    unique_id = uuid.uuid4().hex[:8]
    clean_name = f"{skill_name}-skill-{unique_id}"
    project_commands_dir = Path(project_root) / ".claude" / "commands"
    command_file = project_commands_dir / f"{clean_name}.md"

    try:
        project_commands_dir.mkdir(parents=True, exist_ok=True)
        # Bloc scalaire YAML pour ne pas casser sur des guillemets dans la description
        indented_desc = "\n  ".join(skill_description.split("\n"))
        command_content = (
            f"---\n"
            f"description: |\n"
            f"  {indented_desc}\n"
            f"---\n\n"
            f"# {skill_name}\n\n"
            f"Ce skill gere : {skill_description}\n"
        )
        command_file.write_text(command_content)

        cmd = [
            "claude",
            "-p", query,
            "--output-format", "stream-json",
            "--verbose",
            "--include-partial-messages",
        ]
        if model:
            cmd.extend(["--model", model])

        # Retire CLAUDECODE de l'environnement pour permettre d'imbriquer
        # « claude -p » dans une session Claude Code. Le garde-fou vise les
        # conflits de terminal interactif ; un sous-processus programmatique
        # est sans risque.
        env = {k: v for k, v in os.environ.items() if k != "CLAUDECODE"}

        process = subprocess.Popen(
            cmd,
            stdout=subprocess.PIPE,
            stderr=subprocess.DEVNULL,
            cwd=project_root,
            env=env,
        )

        triggered = False
        start_time = time.time()
        buffer = ""
        # Etat pour la detection par evenements de flux
        pending_tool_name = None
        accumulated_json = ""

        try:
            while time.time() - start_time < timeout:
                if process.poll() is not None:
                    remaining = process.stdout.read()
                    if remaining:
                        buffer += remaining.decode("utf-8", errors="replace")
                    break

                ready, _, _ = select.select([process.stdout], [], [], 1.0)
                if not ready:
                    continue

                chunk = os.read(process.stdout.fileno(), 8192)
                if not chunk:
                    break
                buffer += chunk.decode("utf-8", errors="replace")

                while "\n" in buffer:
                    line, buffer = buffer.split("\n", 1)
                    line = line.strip()
                    if not line:
                        continue

                    try:
                        event = json.loads(line)
                    except json.JSONDecodeError:
                        continue

                    # Detection precoce par evenements de flux
                    if event.get("type") == "stream_event":
                        se = event.get("event", {})
                        se_type = se.get("type", "")

                        if se_type == "content_block_start":
                            cb = se.get("content_block", {})
                            if cb.get("type") == "tool_use":
                                tool_name = cb.get("name", "")
                                if tool_name in ("Skill", "Read"):
                                    pending_tool_name = tool_name
                                    accumulated_json = ""
                                else:
                                    # UN AUTRE OUTIL AVANT LE BON N'EST PAS UN
                                    # ECHEC DE DECLENCHEMENT. Claude planifie
                                    # parfois (TodoWrite, une exploration par
                                    # Bash/Glob…) avant d'appeler Skill/Read —
                                    # arreter net ici prenait ce plan legitime
                                    # pour un refus, biaisant systematiquement
                                    # l'optimiseur de description vers des
                                    # reponses impulsives. On reinitialise et
                                    # on continue d'ecouter le reste du tour.
                                    pending_tool_name = None
                                    accumulated_json = ""

                        elif se_type == "content_block_delta" and pending_tool_name:
                            delta = se.get("delta", {})
                            if delta.get("type") == "input_json_delta":
                                accumulated_json += delta.get("partial_json", "")
                                if clean_name in accumulated_json:
                                    return True

                        elif se_type in ("content_block_stop", "message_stop"):
                            if pending_tool_name:
                                return clean_name in accumulated_json
                            if se_type == "message_stop":
                                return False

                    # Repli : le message complet de l'assistant
                    elif event.get("type") == "assistant":
                        message = event.get("message", {})
                        for content_item in message.get("content", []):
                            if content_item.get("type") != "tool_use":
                                continue
                            tool_name = content_item.get("name", "")
                            tool_input = content_item.get("input", {})
                            if tool_name == "Skill" and clean_name in tool_input.get("skill", ""):
                                triggered = True
                            elif tool_name == "Read" and clean_name in tool_input.get("file_path", ""):
                                triggered = True
                        # RENDU APRES LA BOUCLE, PAS DEDANS : rendre au
                        # premier element de contenu ignorait tout ce qui
                        # suivait — un TodoWrite en premier bloc masquait le
                        # vrai appel a Skill place juste apres.
                        return triggered

                    elif event.get("type") == "result":
                        return triggered
        finally:
            # Nettoie le processus quelle que soit la sortie (retour, exception, delai)
            if process.poll() is None:
                process.kill()
                process.wait()

        return triggered
    finally:
        if command_file.exists():
            command_file.unlink()


def run_eval(
    eval_set: list[dict],
    skill_name: str,
    description: str,
    num_workers: int,
    timeout: int,
    project_root: Path,
    runs_per_query: int = 1,
    trigger_threshold: float = 0.5,
    model: str | None = None,
) -> dict:
    """Lance le jeu d'evaluation complet et rend les resultats."""
    results = []

    with ProcessPoolExecutor(max_workers=num_workers) as executor:
        future_to_info = {}
        for item in eval_set:
            for run_idx in range(runs_per_query):
                future = executor.submit(
                    run_single_query,
                    item["query"],
                    skill_name,
                    description,
                    timeout,
                    str(project_root),
                    model,
                )
                future_to_info[future] = (item, run_idx)

        query_triggers: dict[str, list[bool]] = {}
        query_items: dict[str, dict] = {}
        for future in as_completed(future_to_info):
            item, _ = future_to_info[future]
            query = item["query"]
            query_items[query] = item
            if query not in query_triggers:
                query_triggers[query] = []
            try:
                query_triggers[query].append(future.result())
            except Exception as e:
                print(f"Avertissement : requete echouee : {e}", file=sys.stderr)
                query_triggers[query].append(False)

    for query, triggers in query_triggers.items():
        item = query_items[query]
        trigger_rate = sum(triggers) / len(triggers)
        should_trigger = item["should_trigger"]
        if should_trigger:
            did_pass = trigger_rate >= trigger_threshold
        else:
            did_pass = trigger_rate < trigger_threshold
        results.append({
            "query": query,
            "should_trigger": should_trigger,
            "trigger_rate": trigger_rate,
            "triggers": sum(triggers),
            "runs": len(triggers),
            "pass": did_pass,
        })

    passed = sum(1 for r in results if r["pass"])
    total = len(results)

    return {
        "skill_name": skill_name,
        "description": description,
        "results": results,
        "summary": {
            "total": total,
            "passed": passed,
            "failed": total - passed,
        },
    }


def main():
    parser = argparse.ArgumentParser(description="Lance l'evaluation de declenchement pour une description de skill")
    parser.add_argument("--eval-set", required=True, help="Chemin vers le fichier JSON du jeu d'evaluation")
    parser.add_argument("--skill-path", required=True, help="Chemin vers le dossier du skill")
    parser.add_argument("--description", default=None, help="Description a tester, en remplacement")
    parser.add_argument("--num-workers", type=int, default=10, help="Nombre d'ouvriers paralleles")
    parser.add_argument("--timeout", type=int, default=30, help="Delai par requete, en secondes")
    parser.add_argument("--runs-per-query", type=int, default=3, help="Nombre d'essais par requete")
    parser.add_argument("--trigger-threshold", type=float, default=0.5, help="Seuil du taux de declenchement")
    parser.add_argument("--model", default=None, help="Modele a utiliser pour claude -p (par defaut : celui configure par l'utilisateur)")
    parser.add_argument("--verbose", action="store_true", help="Affiche la progression sur stderr")
    args = parser.parse_args()

    eval_set = json.loads(Path(args.eval_set).read_text())
    skill_path = Path(args.skill_path)

    if not (skill_path / "SKILL.md").exists():
        print(f"Erreur : aucun SKILL.md trouve dans {skill_path}", file=sys.stderr)
        sys.exit(1)

    name, original_description, content = parse_skill_md(skill_path)
    description = args.description or original_description
    project_root = find_project_root()

    if args.verbose:
        print(f"Evaluation : {description}", file=sys.stderr)

    output = run_eval(
        eval_set=eval_set,
        skill_name=name,
        description=description,
        num_workers=args.num_workers,
        timeout=args.timeout,
        project_root=project_root,
        runs_per_query=args.runs_per_query,
        trigger_threshold=args.trigger_threshold,
        model=args.model,
    )

    if args.verbose:
        summary = output["summary"]
        print(f"Resultats : {summary['passed']}/{summary['total']} reussis", file=sys.stderr)
        for r in output["results"]:
            status = "REUSSI" if r["pass"] else "ECHEC"
            rate_str = f"{r['triggers']}/{r['runs']}"
            print(f"  [{status}] taux={rate_str} attendu={r['should_trigger']}: {r['query'][:70]}", file=sys.stderr)

    print(json.dumps(output, indent=2))


if __name__ == "__main__":
    main()
