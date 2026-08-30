#!/usr/bin/env python3
"""
Script de validation rapide pour les skills - version minimale
"""

import sys
import os
import re
import yaml
from pathlib import Path

def validate_skill(skill_path):
    """Validation de base d'un skill"""
    skill_path = Path(skill_path)

    # SKILL.md doit exister
    skill_md = skill_path / 'SKILL.md'
    if not skill_md.exists():
        return False, "SKILL.md introuvable"

    # Lit et valide l'en-tete
    content = skill_md.read_text()
    if not content.startswith('---'):
        return False, "Aucun en-tete YAML trouve"

    # Extrait l'en-tete
    match = re.match(r'^---\n(.*?)\n---', content, re.DOTALL)
    if not match:
        return False, "Format d'en-tete invalide"

    frontmatter_text = match.group(1)

    # Analyse l'en-tete YAML
    try:
        frontmatter = yaml.safe_load(frontmatter_text)
        if not isinstance(frontmatter, dict):
            return False, "L'en-tete doit etre un dictionnaire YAML"
    except yaml.YAMLError as e:
        return False, f"YAML invalide dans l'en-tete : {e}"

    # Proprietes autorisees
    ALLOWED_PROPERTIES = {'name', 'description', 'license', 'allowed-tools', 'metadata', 'compatibility'}

    # Verifie l'absence de proprietes inattendues (hors cles imbriquees sous metadata)
    unexpected_keys = set(frontmatter.keys()) - ALLOWED_PROPERTIES
    if unexpected_keys:
        return False, (
            f"Cle(s) inattendue(s) dans l'en-tete de SKILL.md : {', '.join(sorted(unexpected_keys))}. "
            f"Proprietes autorisees : {', '.join(sorted(ALLOWED_PROPERTIES))}"
        )

    # Verifie les champs requis
    if 'name' not in frontmatter:
        return False, "'name' manquant dans l'en-tete"
    if 'description' not in frontmatter:
        return False, "'description' manquant dans l'en-tete"

    # Extrait le nom pour validation
    name = frontmatter.get('name', '')
    if not isinstance(name, str):
        return False, f"Le nom doit etre une chaine, recu {type(name).__name__}"
    name = name.strip()
    if name:
        # Verifie la convention de nommage (kebab-case : minuscules et tirets)
        if not re.match(r'^[a-z0-9-]+$', name):
            return False, f"Le nom « {name} » doit etre en kebab-case (minuscules, chiffres et tirets seulement)"
        if name.startswith('-') or name.endswith('-') or '--' in name:
            return False, f"Le nom « {name} » ne peut pas commencer/finir par un tiret ni contenir de tirets consecutifs"
        # Verifie la longueur du nom (64 caracteres maximum, selon la spec)
        if len(name) > 64:
            return False, f"Le nom est trop long ({len(name)} caracteres). Maximum : 64 caracteres."

    # Extrait et valide la description
    description = frontmatter.get('description', '')
    if not isinstance(description, str):
        return False, f"La description doit etre une chaine, recu {type(description).__name__}"
    description = description.strip()
    if description:
        # Verifie l'absence de chevrons
        if '<' in description or '>' in description:
            return False, "La description ne peut pas contenir de chevrons (< ou >)"
        # Verifie la longueur de la description (1024 caracteres maximum, selon la spec)
        if len(description) > 1024:
            return False, f"La description est trop longue ({len(description)} caracteres). Maximum : 1024 caracteres."

    # Valide le champ compatibility s'il est present (optionnel)
    compatibility = frontmatter.get('compatibility', '')
    if compatibility:
        if not isinstance(compatibility, str):
            return False, f"Compatibility doit etre une chaine, recu {type(compatibility).__name__}"
        if len(compatibility) > 500:
            return False, f"Compatibility est trop long ({len(compatibility)} caracteres). Maximum : 500 caracteres."

    return True, "Le skill est valide !"

if __name__ == "__main__":
    if len(sys.argv) != 2:
        print("Usage : python quick_validate.py <dossier_du_skill>")
        sys.exit(1)

    valid, message = validate_skill(sys.argv[1])
    print(message)
    sys.exit(0 if valid else 1)
