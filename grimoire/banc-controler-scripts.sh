#!/usr/bin/bash
# GRIMOIRE — valider un script AVANT de le lancer
# PREUVE : 2026-08-21, appliqué à seagate.ps1 et poser-sur-seagate.sh. A
#          confirmé zéro octet > 127, LF, ParseFile propre, bash -n propre.
#          Coût : une seconde. Chacun de ces contrôles correspond à un cycle
#          de CI ou de banc réellement perdu.
# POUR   : tout dépôt édité sous Windows dont les scripts tournent sous Linux,
#          et tout script de banc PowerShell.
#
# QUATRE CONTRÔLES, QUATRE ÉCHECS DÉJÀ PAYÉS
#
#  1. CRLF -> « bad interpreter: /bin/bash^M » dans le conteneur. Silencieux
#     à l'écriture, fatal à l'exécution. .gitattributes force le LF ; ce
#     contrôle vérifie que rien ne l'a contourné.
#
#  2. BIT D'EXÉCUTION PERDU -> un script créé sous Windows entre dans git en
#     100644, et « RUN /ctx/script.sh » rend « Permission denied » — APRÈS
#     avoir téléchargé toute l'image de base. Donc tard, et pour rien.
#     Deux parades, à poser toutes les deux : git update-index --chmod=+x,
#     et appeler « bash /ctx/script.sh » plutôt que le script seul.
#
#  3. UTF-8 DANS UN .ps1 -> PowerShell 5.1 le lit en CP1252, un tiret cadratin
#     devient un délimiteur de chaîne, et la ligne cesse d'être analysée. Le
#     symptôme typique est un « -ForegroundColor Cyan » affiché en clair.
#
#  4. SOURCE DE COPY ABSENTE -> git ne suit pas les dossiers vides. Un
#     « COPY files/ / » visant un chemin qui n'existe pas côté serveur échoue
#     APRÈS le téléchargement complet de l'image de base. Quatre minutes pour
#     une erreur qui se lit en une seconde.

controler_scripts() {
    # Usage : controler_scripts [dossier]   (défaut : le dépôt entier)
    local ou="${1:-.}" faute=0 f

    echo "=== Fins de ligne ==="
    while IFS= read -r f; do
        if grep -q $'\r' "$f" 2>/dev/null; then
            echo "  CRLF : $f" >&2; faute=1
        fi
    done < <(find "$ou" -type f \( -name '*.sh' -o -name '*.ps1' -o -name '*.yml' \) -not -path '*/.git/*')
    [ "$faute" -eq 0 ] && echo "  toutes en LF"

    echo "=== Syntaxe bash ==="
    while IFS= read -r f; do
        head -1 "$f" | grep -q '^#!' || { echo "  sans shebang : $f" >&2; faute=1; }
        bash -n "$f" 2>/dev/null   || { echo "  syntaxe : $f" >&2;      faute=1; }
    done < <(find "$ou" -type f -name '*.sh' -not -path '*/.git/*')
    echo "  fait"

    echo "=== ASCII strict des .ps1 ==="
    while IFS= read -r f; do
        if LC_ALL=C grep -qn '[^ -~\t]' "$f" 2>/dev/null; then
            echo "  NON-ASCII : $f" >&2
            LC_ALL=C grep -n '[^ -~\t]' "$f" | head -3 >&2
            faute=1
        fi
    done < <(find "$ou" -type f -name '*.ps1' -not -path '*/.git/*')
    echo "  fait"

    echo "=== Bit d'exécution enregistré dans git ==="
    git -C "$ou" ls-files -s -- '*.sh' 2>/dev/null | grep -v '^100755' | while read -r l; do
        echo "  pas exécutable : $l" >&2
    done
    echo "  fait"

    [ "$faute" -eq 0 ] && echo "VERDICT : rien à signaler." || echo "VERDICT : voir ci-dessus." >&2
    return "$faute"
}

# Le pendant PowerShell, à lancer côté Windows — ParseFile rend son verdict
# sans exécuter une seule ligne du script :
#
#   $e = $null
#   [void][System.Management.Automation.Language.Parser]::ParseFile($chemin, [ref]$null, [ref]$e)
#   if ($e.Count) { $e | ForEach-Object { "ligne $($_.Extent.StartLineNumber) : $($_.Message)" } }
#
# Et le contrôle d'encodage qui compte vraiment, parce qu'il reproduit
# exactement ce que fera PowerShell 5.1 :
#
#   ([System.IO.File]::ReadAllBytes($chemin) | Where-Object { $_ -gt 127 }).Count   # doit rendre 0
