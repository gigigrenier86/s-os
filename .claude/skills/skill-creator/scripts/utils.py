"""Utilitaires partages par les scripts de skill-creator."""

from pathlib import Path



def parse_skill_md(skill_path: Path) -> tuple[str, str, str]:
    """Analyse un fichier SKILL.md et rend (nom, description, contenu_complet)."""
    content = (skill_path / "SKILL.md").read_text()
    lines = content.split("\n")

    if lines[0].strip() != "---":
        raise ValueError("SKILL.md sans en-tete (pas de --- d'ouverture)")

    end_idx = None
    for i, line in enumerate(lines[1:], start=1):
        if line.strip() == "---":
            end_idx = i
            break

    if end_idx is None:
        raise ValueError("SKILL.md sans en-tete (pas de --- de fermeture)")

    name = ""
    description = ""
    frontmatter_lines = lines[1:end_idx]
    i = 0
    while i < len(frontmatter_lines):
        line = frontmatter_lines[i]
        if line.startswith("name:"):
            name = line[len("name:"):].strip().strip('"').strip("'")
        elif line.startswith("description:"):
            value = line[len("description:"):].strip()
            # Les indicateurs YAML multiligne (>, |, >-, |-)
            if value in (">", "|", ">-", "|-"):
                continuation_lines: list[str] = []
                i += 1
                # UNE LIGNE VIDE NE TERMINE PAS UN BLOC YAML `>`/`|` — elle
                # marque juste une coupure de paragraphe a l'interieur du
                # bloc. S'arreter dessus tronquait toute description sur
                # plusieurs paragraphes des la premiere ligne vide.
                while i < len(frontmatter_lines):
                    ligne_courante = frontmatter_lines[i]
                    if ligne_courante.strip() == "":
                        i += 1
                        continue
                    if ligne_courante.startswith("  ") or ligne_courante.startswith("\t"):
                        continuation_lines.append(ligne_courante.strip())
                        i += 1
                    else:
                        break
                description = " ".join(continuation_lines)
                continue
            else:
                description = value.strip('"').strip("'")
        i += 1

    return name, description, content
