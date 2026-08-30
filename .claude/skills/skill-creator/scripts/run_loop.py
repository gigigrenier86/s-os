#!/usr/bin/env python3
"""Lance la boucle evaluation + amelioration jusqu'a tout reussir ou atteindre le maximum d'iterations.

Combine run_eval.py et improve_description.py dans une boucle, en gardant
l'historique et en rendant la meilleure description trouvee. Prend en charge
une separation entrainement/test pour eviter le surapprentissage.
"""

import argparse
import json
import random
import sys
import tempfile
import time
import webbrowser
from pathlib import Path

from scripts.generate_report import generate_html
from scripts.improve_description import improve_description
from scripts.run_eval import find_project_root, run_eval
from scripts.utils import parse_skill_md


def split_eval_set(eval_set: list[dict], holdout: float, seed: int = 42) -> tuple[list[dict], list[dict]]:
    """Separe le jeu d'evaluation en entrainement et test, stratifie par should_trigger."""
    random.seed(seed)

    # Separe selon should_trigger
    trigger = [e for e in eval_set if e["should_trigger"]]
    no_trigger = [e for e in eval_set if not e["should_trigger"]]

    # Melange chaque groupe
    random.shuffle(trigger)
    random.shuffle(no_trigger)

    # Calcule les points de coupure
    n_trigger_test = max(1, int(len(trigger) * holdout))
    n_no_trigger_test = max(1, int(len(no_trigger) * holdout))

    # Separe
    test_set = trigger[:n_trigger_test] + no_trigger[:n_no_trigger_test]
    train_set = trigger[n_trigger_test:] + no_trigger[n_no_trigger_test:]

    return train_set, test_set


def run_loop(
    eval_set: list[dict],
    skill_path: Path,
    description_override: str | None,
    num_workers: int,
    timeout: int,
    max_iterations: int,
    runs_per_query: int,
    trigger_threshold: float,
    holdout: float,
    model: str,
    verbose: bool,
    live_report_path: Path | None = None,
    log_dir: Path | None = None,
) -> dict:
    """Lance la boucle evaluation + amelioration."""
    # SANS CETTE GARDE, --max-iterations 0 (ou negatif) LAISSE « history »
    # VIDE : la boucle for ne tourne jamais, et max(history, ...) plus bas
    # leve ValueError au lieu d'un message clair. argparse ne borne pas ce
    # parametre, donc rien d'autre ne l'empeche.
    if max_iterations < 1:
        raise ValueError(
            f"max_iterations doit valoir au moins 1 (recu {max_iterations})"
        )

    project_root = find_project_root()
    name, original_description, content = parse_skill_md(skill_path)
    current_description = description_override or original_description

    # Separe en entrainement/test si holdout > 0
    if holdout > 0:
        train_set, test_set = split_eval_set(eval_set, holdout)
        if verbose:
            print(f"Separation : {len(train_set)} entrainement, {len(test_set)} test (holdout={holdout})", file=sys.stderr)
    else:
        train_set = eval_set
        test_set = []

    history = []
    exit_reason = "unknown"

    for iteration in range(1, max_iterations + 1):
        if verbose:
            print(f"\n{'='*60}", file=sys.stderr)
            print(f"Iteration {iteration}/{max_iterations}", file=sys.stderr)
            print(f"Description : {current_description}", file=sys.stderr)
            print(f"{'='*60}", file=sys.stderr)

        # Evalue entrainement + test ensemble, en un seul lot, pour paralleliser
        all_queries = train_set + test_set
        t0 = time.time()
        all_results = run_eval(
            eval_set=all_queries,
            skill_name=name,
            description=current_description,
            num_workers=num_workers,
            timeout=timeout,
            project_root=project_root,
            runs_per_query=runs_per_query,
            trigger_threshold=trigger_threshold,
            model=model,
        )
        eval_elapsed = time.time() - t0

        # Reseparer les resultats entre entrainement et test, par requete
        train_queries_set = {q["query"] for q in train_set}
        train_result_list = [r for r in all_results["results"] if r["query"] in train_queries_set]
        test_result_list = [r for r in all_results["results"] if r["query"] not in train_queries_set]

        train_passed = sum(1 for r in train_result_list if r["pass"])
        train_total = len(train_result_list)
        train_summary = {"passed": train_passed, "failed": train_total - train_passed, "total": train_total}
        train_results = {"results": train_result_list, "summary": train_summary}

        if test_set:
            test_passed = sum(1 for r in test_result_list if r["pass"])
            test_total = len(test_result_list)
            test_summary = {"passed": test_passed, "failed": test_total - test_passed, "total": test_total}
            test_results = {"results": test_result_list, "summary": test_summary}
        else:
            test_results = None
            test_summary = None

        history.append({
            "iteration": iteration,
            "description": current_description,
            "train_passed": train_summary["passed"],
            "train_failed": train_summary["failed"],
            "train_total": train_summary["total"],
            "train_results": train_results["results"],
            "test_passed": test_summary["passed"] if test_summary else None,
            "test_failed": test_summary["failed"] if test_summary else None,
            "test_total": test_summary["total"] if test_summary else None,
            "test_results": test_results["results"] if test_results else None,
            # Pour la compatibilite avec le generateur de rapport
            "passed": train_summary["passed"],
            "failed": train_summary["failed"],
            "total": train_summary["total"],
            "results": train_results["results"],
        })

        # Ecrit le rapport en direct si un chemin est fourni
        if live_report_path:
            partial_output = {
                "original_description": original_description,
                "best_description": current_description,
                "best_score": "en cours",
                "iterations_run": len(history),
                "holdout": holdout,
                "train_size": len(train_set),
                "test_size": len(test_set),
                "history": history,
            }
            live_report_path.write_text(generate_html(partial_output, auto_refresh=True, skill_name=name))

        if verbose:
            def print_eval_stats(label, results, elapsed):
                pos = [r for r in results if r["should_trigger"]]
                neg = [r for r in results if not r["should_trigger"]]
                tp = sum(r["triggers"] for r in pos)
                pos_runs = sum(r["runs"] for r in pos)
                fn = pos_runs - tp
                fp = sum(r["triggers"] for r in neg)
                neg_runs = sum(r["runs"] for r in neg)
                tn = neg_runs - fp
                total = tp + tn + fp + fn
                precision = tp / (tp + fp) if (tp + fp) > 0 else 1.0
                recall = tp / (tp + fn) if (tp + fn) > 0 else 1.0
                accuracy = (tp + tn) / total if total > 0 else 0.0
                print(f"{label}: {tp+tn}/{total} correct, precision={precision:.0%} rappel={recall:.0%} exactitude={accuracy:.0%} ({elapsed:.1f}s)", file=sys.stderr)
                for r in results:
                    status = "REUSSI" if r["pass"] else "ECHEC"
                    rate_str = f"{r['triggers']}/{r['runs']}"
                    print(f"  [{status}] taux={rate_str} attendu={r['should_trigger']}: {r['query'][:60]}", file=sys.stderr)

            print_eval_stats("Entrainement", train_results["results"], eval_elapsed)
            if test_summary:
                print_eval_stats("Test", test_results["results"], 0)

        # LA GARDE PORTE AUSSI SUR « total > 0 » : sans elle, un jeu
        # d'entrainement vide apres la separation holdout (frequent avec un
        # tres petit jeu d'evaluation) rend train_summary["failed"] == 0
        # TRIVIALEMENT vrai (0 == 0, sans qu'aucune requete n'ait ete
        # verifiee), et la boucle annonce a tort « tout est reussi » des la
        # premiere iteration sans jamais appeler improve_description.
        if train_summary["total"] > 0 and train_summary["failed"] == 0:
            exit_reason = f"all_passed (iteration {iteration})"
            if verbose:
                print(f"\nToutes les requetes d'entrainement ont reussi a l'iteration {iteration} !", file=sys.stderr)
            break

        if iteration == max_iterations:
            exit_reason = f"max_iterations ({max_iterations})"
            if verbose:
                print(f"\nNombre maximal d'iterations atteint ({max_iterations}).", file=sys.stderr)
            break

        # Ameliore la description a partir des resultats d'entrainement
        if verbose:
            print(f"\nAmelioration de la description…", file=sys.stderr)

        t0 = time.time()
        # Retire les scores de test de l'historique pour que le modele
        # d'amelioration ne puisse pas les voir
        blinded_history = [
            {k: v for k, v in h.items() if not k.startswith("test_")}
            for h in history
        ]
        new_description = improve_description(
            skill_name=name,
            skill_content=content,
            current_description=current_description,
            eval_results=train_results,
            history=blinded_history,
            model=model,
            # SANS CE PARAMETRE, LE SCORE DE TEST N'ETAIT JAMAIS TRANSMIS :
            # improve_description() sait le mettre dans son resume
            # (« Train: X, Test: Y »), mais rien ici ne le lui passait — le
            # holdout calculait un vrai score de test a chaque iteration
            # sans que le modele d'amelioration ne le voie jamais, ce qui
            # videait une partie du but de la separation entrainement/test
            # (detecter le surapprentissage).
            test_results=test_results,
            log_dir=log_dir,
            iteration=iteration,
        )
        improve_elapsed = time.time() - t0

        if verbose:
            print(f"Proposee ({improve_elapsed:.1f}s) : {new_description}", file=sys.stderr)

        current_description = new_description

    # Trouve la meilleure iteration par le score de TEST (ou d'entrainement, sans jeu de test)
    if test_set:
        best = max(history, key=lambda h: h["test_passed"] or 0)
        best_score = f"{best['test_passed']}/{best['test_total']}"
    else:
        best = max(history, key=lambda h: h["train_passed"])
        best_score = f"{best['train_passed']}/{best['train_total']}"

    if verbose:
        print(f"\nMotif de sortie : {exit_reason}", file=sys.stderr)
        print(f"Meilleur score : {best_score} (iteration {best['iteration']})", file=sys.stderr)

    return {
        "exit_reason": exit_reason,
        "original_description": original_description,
        "best_description": best["description"],
        "best_score": best_score,
        "best_train_score": f"{best['train_passed']}/{best['train_total']}",
        "best_test_score": f"{best['test_passed']}/{best['test_total']}" if test_set else None,
        "final_description": current_description,
        "iterations_run": len(history),
        "holdout": holdout,
        "train_size": len(train_set),
        "test_size": len(test_set),
        "history": history,
    }


def main():
    parser = argparse.ArgumentParser(description="Lance la boucle evaluation + amelioration")
    parser.add_argument("--eval-set", required=True, help="Chemin vers le fichier JSON du jeu d'evaluation")
    parser.add_argument("--skill-path", required=True, help="Chemin vers le dossier du skill")
    parser.add_argument("--description", default=None, help="Description de depart, en remplacement")
    parser.add_argument("--num-workers", type=int, default=10, help="Nombre d'ouvriers paralleles")
    parser.add_argument("--timeout", type=int, default=30, help="Delai par requete, en secondes")
    parser.add_argument("--max-iterations", type=int, default=5, help="Nombre maximal d'iterations d'amelioration")
    parser.add_argument("--runs-per-query", type=int, default=3, help="Nombre d'essais par requete")
    parser.add_argument("--trigger-threshold", type=float, default=0.5, help="Seuil du taux de declenchement")
    parser.add_argument("--holdout", type=float, default=0.4, help="Fraction du jeu d'evaluation reservee au test (0 pour desactiver)")
    parser.add_argument("--model", required=True, help="Modele pour l'amelioration")
    parser.add_argument("--verbose", action="store_true", help="Affiche la progression sur stderr")
    parser.add_argument("--report", default="auto", help="Genere un rapport HTML a ce chemin (par defaut : 'auto' pour un fichier temporaire, 'none' pour desactiver)")
    parser.add_argument("--results-dir", default=None, help="Sauvegarde toutes les sorties (results.json, report.html, log.txt) dans un sous-dossier horodate ici")
    args = parser.parse_args()

    eval_set = json.loads(Path(args.eval_set).read_text())
    skill_path = Path(args.skill_path)

    if not (skill_path / "SKILL.md").exists():
        print(f"Erreur : aucun SKILL.md trouve dans {skill_path}", file=sys.stderr)
        sys.exit(1)

    name, _, _ = parse_skill_md(skill_path)

    # Prepare le chemin du rapport en direct
    if args.report != "none":
        if args.report == "auto":
            timestamp = time.strftime("%Y%m%d_%H%M%S")
            live_report_path = Path(tempfile.gettempdir()) / f"skill_description_report_{skill_path.name}_{timestamp}.html"
        else:
            live_report_path = Path(args.report)
        # Ouvre le rapport tout de suite pour que l'utilisateur puisse suivre
        live_report_path.write_text("<html><body><h1>Demarrage de la boucle d'optimisation…</h1><meta http-equiv='refresh' content='5'></body></html>")
        webbrowser.open(str(live_report_path))
    else:
        live_report_path = None

    # Determine le dossier de sortie (cree avant run_loop pour que les journaux puissent s'y ecrire)
    if args.results_dir:
        timestamp = time.strftime("%Y-%m-%d_%H%M%S")
        results_dir = Path(args.results_dir) / timestamp
        results_dir.mkdir(parents=True, exist_ok=True)
    else:
        results_dir = None

    log_dir = results_dir / "logs" if results_dir else None

    output = run_loop(
        eval_set=eval_set,
        skill_path=skill_path,
        description_override=args.description,
        num_workers=args.num_workers,
        timeout=args.timeout,
        max_iterations=args.max_iterations,
        runs_per_query=args.runs_per_query,
        trigger_threshold=args.trigger_threshold,
        holdout=args.holdout,
        model=args.model,
        verbose=args.verbose,
        live_report_path=live_report_path,
        log_dir=log_dir,
    )

    # Sauvegarde la sortie JSON
    json_output = json.dumps(output, indent=2)
    print(json_output)
    if results_dir:
        (results_dir / "results.json").write_text(json_output)

    # Ecrit le rapport HTML final (sans rafraichissement automatique)
    if live_report_path:
        live_report_path.write_text(generate_html(output, auto_refresh=False, skill_name=name))
        print(f"\nRapport : {live_report_path}", file=sys.stderr)

    if results_dir and live_report_path:
        (results_dir / "report.html").write_text(generate_html(output, auto_refresh=False, skill_name=name))

    if results_dir:
        print(f"Resultats sauvegardes dans : {results_dir}", file=sys.stderr)


if __name__ == "__main__":
    main()
