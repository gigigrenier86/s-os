#!/usr/bin/env python3
"""
Agrege les resultats individuels d'essais en statistiques de synthese.

Lit les fichiers grading.json des dossiers d'essai et produit :
- run_summary avec moyenne, ecart-type, min, max pour chaque metrique
- l'ecart entre les configurations with_skill et without_skill

Usage :
    python aggregate_benchmark.py <dossier_benchmark>

Exemple :
    python aggregate_benchmark.py benchmarks/2026-01-15T10-30-00/

Le script accepte deux dispositions de dossiers :

    Disposition reelle (celle que produit le workflow documente dans
    SKILL.md et agents/grader.md — aucun niveau run-N/, grading.json est
    directement le frere de outputs/) :
    <dossier_benchmark>/
    └── eval-N/
        ├── with_skill/
        │   ├── outputs/…
        │   └── grading.json
        └── without_skill/
            ├── outputs/…
            └── grading.json

    Disposition a essais multiples (un dossier run-N/ par essai, pour
    plusieurs passages de la meme configuration) :
    <dossier_benchmark>/
    └── eval-N/
        ├── with_skill/
        │   ├── run-1/grading.json
        │   └── run-2/grading.json
        └── without_skill/
            ├── run-1/grading.json
            └── run-2/grading.json

    Disposition heritee (avec un sous-dossier runs/) :
    <dossier_benchmark>/
    └── runs/
        └── eval-N/
            ├── with_skill/
            │   └── run-1/grading.json
            └── without_skill/
                └── run-1/grading.json
"""

import argparse
import json
import math
import sys
from datetime import datetime, timezone
from pathlib import Path


def calculate_stats(values: list[float]) -> dict:
    """Calcule moyenne, ecart-type, min, max pour une liste de valeurs."""
    if not values:
        return {"mean": 0.0, "stddev": 0.0, "min": 0.0, "max": 0.0}

    n = len(values)
    mean = sum(values) / n

    if n > 1:
        variance = sum((x - mean) ** 2 for x in values) / (n - 1)
        stddev = math.sqrt(variance)
    else:
        stddev = 0.0

    return {
        "mean": round(mean, 4),
        "stddev": round(stddev, 4),
        "min": round(min(values), 4),
        "max": round(max(values), 4)
    }


def load_run_results(benchmark_dir: Path) -> dict:
    """
    Charge tous les resultats d'essais depuis un dossier de benchmark.

    Rend un dict indexe par nom de configuration (ex. "with_skill"/
    "without_skill", ou "new_skill"/"old_skill"), chacun portant une liste
    de resultats d'essai.
    """
    # Les deux dispositions sont acceptees : dossiers d'eval directement
    # sous benchmark_dir, ou sous runs/.
    runs_dir = benchmark_dir / "runs"
    if runs_dir.exists():
        search_dir = runs_dir
    elif list(benchmark_dir.glob("eval-*")):
        search_dir = benchmark_dir
    else:
        print(f"Aucun dossier d'evaluation trouve dans {benchmark_dir} ni {benchmark_dir / 'runs'}")
        return {}

    results: dict[str, list] = {}

    for eval_idx, eval_dir in enumerate(sorted(search_dir.glob("eval-*"))):
        metadata_path = eval_dir / "eval_metadata.json"
        eval_name = None
        if metadata_path.exists():
            try:
                with open(metadata_path) as mf:
                    metadata = json.load(mf)
                eval_id = metadata.get("eval_id", eval_idx)
                # LE NOM DESCRIPTIF DEMANDE PAR SKILL.md (« donne un nom
                # descriptif a chaque eval, pas juste "eval-0" ») N'ETAIT
                # JAMAIS LU ICI : le visualiseur retombe alors sur
                # « Eval N » a la place du nom choisi par l'utilisateur.
                eval_name = metadata.get("eval_name")
            except (json.JSONDecodeError, OSError):
                eval_id = eval_idx
        else:
            try:
                eval_id = int(eval_dir.name.split("-")[1])
            except ValueError:
                eval_id = eval_idx

        # Decouvre les dossiers de configuration plutot que de figer leurs noms
        for config_dir in sorted(eval_dir.iterdir()):
            if not config_dir.is_dir():
                continue

            # DEUX FORMES POSSIBLES POUR UNE CONFIG : soit des sous-dossiers
            # run-N/ (plusieurs essais de la meme configuration), soit — la
            # disposition REELLEMENT produite par le workflow documente
            # (SKILL.md, agents/grader.md) — un grading.json directement
            # dans le dossier de configuration, frere de outputs/. Ignorer
            # la seconde forme faisait sauter SILENCIEUSEMENT chaque
            # configuration produite par le workflow documente : le
            # benchmark sortait vide, sans le moindre avertissement.
            run_dirs = sorted(config_dir.glob("run-*"))
            if run_dirs:
                candidats = []
                for run_dir in run_dirs:
                    try:
                        run_number = int(run_dir.name.split("-")[1])
                    except (IndexError, ValueError):
                        continue
                    candidats.append((run_number, run_dir))
            elif (config_dir / "grading.json").exists():
                candidats = [(1, config_dir)]
            else:
                # Ni l'une ni l'autre forme : pas une config (inputs, etc.)
                continue

            config = config_dir.name
            if config not in results:
                results[config] = []

            for run_number, run_dir in candidats:
                grading_file = run_dir / "grading.json"

                if not grading_file.exists():
                    print(f"Avertissement : grading.json introuvable dans {run_dir}")
                    continue

                try:
                    with open(grading_file) as f:
                        grading = json.load(f)
                except json.JSONDecodeError as e:
                    print(f"Avertissement : JSON invalide dans {grading_file} : {e}")
                    continue

                # Extrait les metriques
                result = {
                    "eval_id": eval_id,
                    "eval_name": eval_name,
                    "run_number": run_number,
                    "pass_rate": grading.get("summary", {}).get("pass_rate", 0.0),
                    "passed": grading.get("summary", {}).get("passed", 0),
                    "failed": grading.get("summary", {}).get("failed", 0),
                    "total": grading.get("summary", {}).get("total", 0),
                }

                # Duree — cherchee d'abord dans grading.json, puis dans le
                # timing.json voisin. LES DEUX LECTURES SONT INDEPENDANTES :
                # grading.json porte la duree mais jamais les tokens (voir
                # references/schemas.md), donc coupler la lecture des
                # tokens a « la duree manquait » faisait qu'elle n'etait
                # JAMAIS lue sur le chemin normal — result["tokens"]
                # retombait alors sur metrics["output_chars"], un compte de
                # CARACTERES pris pour un compte de jetons, silencieusement
                # faux d'un facteur ~4.
                timing = grading.get("timing", {})
                result["time_seconds"] = timing.get("total_duration_seconds", 0.0)
                timing_file = run_dir / "timing.json"
                if timing_file.exists():
                    try:
                        with open(timing_file) as tf:
                            timing_data = json.load(tf)
                        if result["time_seconds"] == 0.0:
                            result["time_seconds"] = timing_data.get("total_duration_seconds", 0.0)
                        result["tokens"] = timing_data.get("total_tokens", 0)
                    except json.JSONDecodeError:
                        pass

                # Extrait les autres metriques, si presentes
                metrics = grading.get("execution_metrics", {})
                result["tool_calls"] = metrics.get("total_tool_calls", 0)
                if not result.get("tokens"):
                    result["tokens"] = metrics.get("output_chars", 0)
                result["errors"] = metrics.get("errors_encountered", 0)

                # Extrait les attentes — le visualiseur exige : text, passed, evidence
                raw_expectations = grading.get("expectations", [])
                for exp in raw_expectations:
                    if "text" not in exp or "passed" not in exp:
                        print(f"Avertissement : une attente de {grading_file} n'a pas les champs requis (text, passed, evidence) : {exp}")
                result["expectations"] = raw_expectations

                # Extrait les notes de user_notes_summary
                notes_summary = grading.get("user_notes_summary", {})
                notes = []
                notes.extend(notes_summary.get("uncertainties", []))
                notes.extend(notes_summary.get("needs_review", []))
                notes.extend(notes_summary.get("workarounds", []))
                result["notes"] = notes

                results[config].append(result)

    return results


def aggregate_results(results: dict) -> dict:
    """
    Agrege les resultats d'essais en statistiques de synthese.

    Rend run_summary avec les statistiques de chaque configuration, et l'ecart.
    """
    run_summary = {}
    configs = list(results.keys())

    for config in configs:
        runs = results.get(config, [])

        if not runs:
            run_summary[config] = {
                "pass_rate": {"mean": 0.0, "stddev": 0.0, "min": 0.0, "max": 0.0},
                "time_seconds": {"mean": 0.0, "stddev": 0.0, "min": 0.0, "max": 0.0},
                "tokens": {"mean": 0, "stddev": 0, "min": 0, "max": 0}
            }
            continue

        pass_rates = [r["pass_rate"] for r in runs]
        times = [r["time_seconds"] for r in runs]
        tokens = [r.get("tokens", 0) for r in runs]

        run_summary[config] = {
            "pass_rate": calculate_stats(pass_rates),
            "time_seconds": calculate_stats(times),
            "tokens": calculate_stats(tokens)
        }

    # Calcule l'ecart entre les deux premieres configurations (s'il y en a deux)
    if len(configs) >= 2:
        primary = run_summary.get(configs[0], {})
        baseline = run_summary.get(configs[1], {})
    else:
        primary = run_summary.get(configs[0], {}) if configs else {}
        baseline = {}

    delta_pass_rate = primary.get("pass_rate", {}).get("mean", 0) - baseline.get("pass_rate", {}).get("mean", 0)
    delta_time = primary.get("time_seconds", {}).get("mean", 0) - baseline.get("time_seconds", {}).get("mean", 0)
    delta_tokens = primary.get("tokens", {}).get("mean", 0) - baseline.get("tokens", {}).get("mean", 0)

    run_summary["delta"] = {
        "pass_rate": f"{delta_pass_rate:+.2f}",
        "time_seconds": f"{delta_time:+.1f}",
        "tokens": f"{delta_tokens:+.0f}"
    }

    return run_summary


def generate_benchmark(benchmark_dir: Path, skill_name: str = "", skill_path: str = "") -> dict:
    """
    Genere le benchmark.json complet a partir des resultats d'essais.
    """
    results = load_run_results(benchmark_dir)
    run_summary = aggregate_results(results)

    # Construit le tableau runs pour benchmark.json
    runs = []
    for config in results:
        for result in results[config]:
            runs.append({
                "eval_id": result["eval_id"],
                "eval_name": result.get("eval_name"),
                "configuration": config,
                "run_number": result["run_number"],
                "result": {
                    "pass_rate": result["pass_rate"],
                    "passed": result["passed"],
                    "failed": result["failed"],
                    "total": result["total"],
                    "time_seconds": result["time_seconds"],
                    "tokens": result.get("tokens", 0),
                    "tool_calls": result.get("tool_calls", 0),
                    "errors": result.get("errors", 0)
                },
                "expectations": result["expectations"],
                "notes": result["notes"]
            })

    # Determine les identifiants d'eval a partir des resultats
    eval_ids = sorted(set(
        r["eval_id"]
        for config in results.values()
        for r in config
    ))

    # LA VALEUR REELLE, PAS UNE CONSTANTE FIGEE : « 3 » etait ecrit en dur
    # ici et repris tel quel dans benchmark.md, quel que soit le nombre
    # d'essais vraiment charges — or le workflow documente n'en fait qu'UN
    # par configuration. Le rapport annoncait donc presque toujours un
    # chiffre faux.
    runs_per_configuration = max((len(r) for r in results.values()), default=0)

    benchmark = {
        "metadata": {
            "skill_name": skill_name or "<nom-du-skill>",
            "skill_path": skill_path or "<chemin/vers/le-skill>",
            "executor_model": "<nom-du-modele>",
            "analyzer_model": "<nom-du-modele>",
            "timestamp": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
            "evals_run": eval_ids,
            "runs_per_configuration": runs_per_configuration
        },
        "runs": runs,
        "run_summary": run_summary,
        "notes": []  # A remplir par l'analyseur
    }

    return benchmark


def generate_markdown(benchmark: dict) -> str:
    """Genere le benchmark.md, lisible par un humain, a partir des donnees du benchmark."""
    metadata = benchmark["metadata"]
    run_summary = benchmark["run_summary"]

    # Determine les noms de configuration (hors "delta")
    configs = [k for k in run_summary if k != "delta"]
    config_a = configs[0] if len(configs) >= 1 else "config_a"
    config_b = configs[1] if len(configs) >= 2 else "config_b"
    label_a = config_a.replace("_", " ").title()
    label_b = config_b.replace("_", " ").title()

    lines = [
        f"# Benchmark du skill : {metadata['skill_name']}",
        "",
        f"**Modele** : {metadata['executor_model']}",
        f"**Date** : {metadata['timestamp']}",
        f"**Evals** : {', '.join(map(str, metadata['evals_run']))} ({metadata['runs_per_configuration']} essai(s) par configuration)",
        "",
        "## Resume",
        "",
        f"| Metrique | {label_a} | {label_b} | Ecart |",
        "|--------|------------|---------------|-------|",
    ]

    a_summary = run_summary.get(config_a, {})
    b_summary = run_summary.get(config_b, {})
    delta = run_summary.get("delta", {})

    # Taux de reussite
    a_pr = a_summary.get("pass_rate", {})
    b_pr = b_summary.get("pass_rate", {})
    lines.append(f"| Taux de reussite | {a_pr.get('mean', 0)*100:.0f}% ± {a_pr.get('stddev', 0)*100:.0f}% | {b_pr.get('mean', 0)*100:.0f}% ± {b_pr.get('stddev', 0)*100:.0f}% | {delta.get('pass_rate', '—')} |")

    # Duree
    a_time = a_summary.get("time_seconds", {})
    b_time = b_summary.get("time_seconds", {})
    lines.append(f"| Duree | {a_time.get('mean', 0):.1f}s ± {a_time.get('stddev', 0):.1f}s | {b_time.get('mean', 0):.1f}s ± {b_time.get('stddev', 0):.1f}s | {delta.get('time_seconds', '—')}s |")

    # Jetons
    a_tokens = a_summary.get("tokens", {})
    b_tokens = b_summary.get("tokens", {})
    lines.append(f"| Jetons | {a_tokens.get('mean', 0):.0f} ± {a_tokens.get('stddev', 0):.0f} | {b_tokens.get('mean', 0):.0f} ± {b_tokens.get('stddev', 0):.0f} | {delta.get('tokens', '—')} |")

    # Section notes
    if benchmark.get("notes"):
        lines.extend([
            "",
            "## Notes",
            ""
        ])
        for note in benchmark["notes"]:
            lines.append(f"- {note}")

    return "\n".join(lines)


def main():
    parser = argparse.ArgumentParser(
        description="Agrege les resultats d'essais d'un benchmark en statistiques de synthese"
    )
    parser.add_argument(
        "benchmark_dir",
        type=Path,
        help="Chemin vers le dossier du benchmark"
    )
    parser.add_argument(
        "--skill-name",
        default="",
        help="Nom du skill evalue"
    )
    parser.add_argument(
        "--skill-path",
        default="",
        help="Chemin vers le skill evalue"
    )
    parser.add_argument(
        "--output", "-o",
        type=Path,
        help="Chemin de sortie pour benchmark.json (par defaut : <dossier_benchmark>/benchmark.json)"
    )

    args = parser.parse_args()

    if not args.benchmark_dir.exists():
        print(f"Dossier introuvable : {args.benchmark_dir}")
        sys.exit(1)

    # Genere le benchmark
    benchmark = generate_benchmark(args.benchmark_dir, args.skill_name, args.skill_path)

    # Determine les chemins de sortie
    output_json = args.output or (args.benchmark_dir / "benchmark.json")
    output_md = output_json.with_suffix(".md")

    # Ecrit benchmark.json
    with open(output_json, "w") as f:
        json.dump(benchmark, f, indent=2)
    print(f"Genere : {output_json}")

    # Ecrit benchmark.md
    markdown = generate_markdown(benchmark)
    with open(output_md, "w") as f:
        f.write(markdown)
    print(f"Genere : {output_md}")

    # Affiche le resume
    run_summary = benchmark["run_summary"]
    configs = [k for k in run_summary if k != "delta"]
    delta = run_summary.get("delta", {})

    print(f"\nResume :")
    for config in configs:
        pr = run_summary[config]["pass_rate"]["mean"]
        label = config.replace("_", " ").title()
        print(f"  {label} : {pr*100:.1f}% de reussite")
    print(f"  Ecart :          {delta.get('pass_rate', '—')}")


if __name__ == "__main__":
    main()
