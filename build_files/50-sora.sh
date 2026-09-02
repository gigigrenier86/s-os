#!/usr/bin/bash
# Sora — l'assistant IA local de S : le runtime et le modele, pre-cuits.
#
# DEMANDE DE L'UTILISATEUR LE 2026-09-01 : « pendant qu'on a peut-etre le
# temps... » puis, sur les cinq chantiers proposes, « tout, dans l'ordre ».
# Sora est le Chantier 1. Deux passes Wizard en direct ont precede ce
# script (voir CLAUDE.md) : la premiere a etabli le patron (llama-cpp +
# GGUF + serveur residant), la seconde — sur demande explicite « verifier
# si il y a mieux gratuit installable en local » — a fait tomber le choix
# initial (Qwen2.5-3B, dont la licence « Apache 2.0 » annoncee s'est
# revelee FAUSSE a la verification directe aupres de l'API Hugging Face :
# c'est en realite la licence non-commerciale Qwen Research License) au
# profit de Qwen3-4B-Instruct-2507, dont l'Apache 2.0 a ete revérifiee de
# la meme facon, a la source, pas par ouï-dire.
#
# LE PAQUET FEDORA OFFICIEL FORCE DES DEPENDANCES ROCm (~1 Gio, mortes sur
# toute machine sans GPU AMD — mesure sur cette machine, Intel UHD 630).
# Decision explicite de l'utilisateur : garder le paquet officiel tel
# quel plutot que compiler nous-memes une variante CPU-only — on ne
# reimplemente pas ce que l'amont maintient, meme au prix d'un peu de
# poids mort.
set -euxo pipefail

dnf5 install -y --setopt=install_weak_deps=False llama-cpp

# ---------------------------------------------------------- Verification --
if rpm -ql llama-cpp 2>/dev/null | grep -E '^/(var|opt)/|^/usr/local/'; then
    echo "ECHEC : llama-cpp a pose des fichiers hors de /usr et /etc." >&2
    exit 1
fi
[[ -x /usr/bin/llama-server ]] \
    || { echo "ECHEC : /usr/bin/llama-server absent apres installation." >&2; exit 1; }

# ---------------------------------------------------------------------------
# Le modele — Qwen3-4B-Instruct-2507, GGUF Q4_K_M, republie par unsloth.
#
# URL, TAILLE ET EMPREINTE VERIFIEES EN DIRECT AUPRES DE L'API HUGGING FACE
# (arborescence du depot, champ « oid » LFS) le 2026-09-01 — jamais devinees.
# La licence du DEPOT DU MODELE (Qwen/Qwen3-4B-Instruct-2507, pas le
# repackager GGUF) a ete lue via son API : "license": "apache-2.0".
DEST=/usr/share/s/sora
FICHIER=Qwen3-4B-Instruct-2507-Q4_K_M.gguf
URL="https://huggingface.co/unsloth/Qwen3-4B-Instruct-2507-GGUF/resolve/main/${FICHIER}"
SHA256_ATTENDU="3605803b982cb64aead44f6c1b2ae36e3acdb41d8e46c8a94c6533bc4c67e597"
TAILLE_ATTENDUE=2497281120

mkdir -p "$DEST"
TRAVAIL=/tmp/sora-precuisson
mkdir -p "$TRAVAIL"

curl -fsSL --retry 5 --retry-all-errors --max-time 600 \
    -o "$TRAVAIL/$FICHIER" "$URL"

TAILLE_OBTENUE="$(stat -c%s "$TRAVAIL/$FICHIER")"
if [ "$TAILLE_OBTENUE" -ne "$TAILLE_ATTENDUE" ]; then
    echo "ECHEC : taille du modele Sora inattendue." >&2
    echo "  attendue $TAILLE_ATTENDUE, obtenue $TAILLE_OBTENUE" >&2
    exit 1
fi

SHA256_OBTENU="$(sha256sum "$TRAVAIL/$FICHIER" | cut -d' ' -f1)"
if [ "$SHA256_ATTENDU" != "$SHA256_OBTENU" ]; then
    echo "ECHEC : le condensat du modele Sora ne correspond pas." >&2
    echo "  attendu $SHA256_ATTENDU" >&2
    echo "  obtenu  $SHA256_OBTENU" >&2
    exit 1
fi

install -m 0644 "$TRAVAIL/$FICHIER" "$DEST/$FICHIER"
rm -rf "$TRAVAIL"

echo "Sora : modele pre-cuit et verifie ($TAILLE_ATTENDUE octets)"
echo "=== 50-sora : fait ==="
