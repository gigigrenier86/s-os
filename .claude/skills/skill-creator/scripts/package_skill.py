#!/usr/bin/env python3
"""
Emballeur de skill - cree un fichier .skill distribuable a partir d'un dossier

Usage :
    python -m scripts.package_skill <chemin/vers/le-skill> [dossier-de-sortie]

Exemple :
    python -m scripts.package_skill skills/public/mon-skill
    python -m scripts.package_skill skills/public/mon-skill ./dist
"""

import fnmatch
import sys
import zipfile
from pathlib import Path
from scripts.quick_validate import validate_skill

# Motifs exclus de l'emballage des skills.
EXCLUDE_DIRS = {"__pycache__", "node_modules"}
EXCLUDE_GLOBS = {"*.pyc"}
EXCLUDE_FILES = {".DS_Store"}
# Dossiers exclus seulement a la racine du skill (pas plus profond).
ROOT_EXCLUDE_DIRS = {"evals"}


def should_exclude(rel_path: Path) -> bool:
    """Vrai si ce chemin doit etre exclu de l'emballage."""
    parts = rel_path.parts
    if any(part in EXCLUDE_DIRS for part in parts):
        return True
    # rel_path est relatif au parent de skill_path, donc parts[0] est le nom
    # du dossier du skill et parts[1] (s'il existe) le premier sous-dossier.
    if len(parts) > 1 and parts[1] in ROOT_EXCLUDE_DIRS:
        return True
    name = rel_path.name
    if name in EXCLUDE_FILES:
        return True
    return any(fnmatch.fnmatch(name, pat) for pat in EXCLUDE_GLOBS)


def package_skill(skill_path, output_dir=None):
    """
    Emballe un dossier de skill dans un fichier .skill.

    Args :
        skill_path : chemin vers le dossier du skill
        output_dir : dossier de sortie optionnel pour le fichier .skill
                     (le dossier courant par defaut)

    Rend :
        Le chemin du fichier .skill cree, ou None en cas d'erreur
    """
    skill_path = Path(skill_path).resolve()

    # Le dossier du skill doit exister
    if not skill_path.exists():
        print(f"❌ Erreur : dossier de skill introuvable : {skill_path}")
        return None

    if not skill_path.is_dir():
        print(f"❌ Erreur : ce chemin n'est pas un dossier : {skill_path}")
        return None

    # SKILL.md doit exister
    skill_md = skill_path / "SKILL.md"
    if not skill_md.exists():
        print(f"❌ Erreur : SKILL.md introuvable dans {skill_path}")
        return None

    # Valider avant d'emballer
    print("🔍 Validation du skill…")
    valid, message = validate_skill(skill_path)
    if not valid:
        print(f"❌ Validation echouee : {message}")
        print("   Corrige les erreurs de validation avant d'emballer.")
        return None
    print(f"✅ {message}\n")

    # Determiner l'emplacement de sortie
    skill_name = skill_path.name
    if output_dir:
        output_path = Path(output_dir).resolve()
        output_path.mkdir(parents=True, exist_ok=True)
    else:
        output_path = Path.cwd()

    skill_filename = output_path / f"{skill_name}.skill"

    # Creer le fichier .skill (format zip)
    try:
        with zipfile.ZipFile(skill_filename, 'w', zipfile.ZIP_DEFLATED) as zipf:
            # Parcourt le dossier du skill, en excluant les artefacts de build
            for file_path in skill_path.rglob('*'):
                if not file_path.is_file():
                    continue
                arcname = file_path.relative_to(skill_path.parent)
                if should_exclude(arcname):
                    print(f"  Ignore : {arcname}")
                    continue
                zipf.write(file_path, arcname)
                print(f"  Ajoute : {arcname}")

        print(f"\n✅ Skill emballe avec succes vers : {skill_filename}")
        return skill_filename

    except Exception as e:
        print(f"❌ Erreur a la creation du fichier .skill : {e}")
        return None


def main():
    if len(sys.argv) < 2:
        print("Usage : python -m scripts.package_skill <chemin/vers/le-skill> [dossier-de-sortie]")
        print("\nExemple :")
        print("  python -m scripts.package_skill skills/public/mon-skill")
        print("  python -m scripts.package_skill skills/public/mon-skill ./dist")
        sys.exit(1)

    skill_path = sys.argv[1]
    output_dir = sys.argv[2] if len(sys.argv) > 2 else None

    print(f"📦 Emballage du skill : {skill_path}")
    if output_dir:
        print(f"   Dossier de sortie : {output_dir}")
    print()

    result = package_skill(skill_path, output_dir)

    if result:
        sys.exit(0)
    else:
        sys.exit(1)


if __name__ == "__main__":
    main()
