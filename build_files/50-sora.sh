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
# LE PAQUET FEDORA OFFICIEL FORCE DES DEPENDANCES ROCm (~2,4 Gio, mortes sur
# toute machine sans GPU AMD — mesure sur cette machine, Intel UHD 630) —
# ET C'ETAIT PIRE QUE DU POIDS MORT. Mesure le 2026-09-01 : le binaire
# compile avec le backend ROCm/HIP DESACTIVE le chemin CPU optimise de
# llama.cpp (CPU_REPACK, un repack SIMD pour AVX2/AVX512), meme sur une
# machine sans aucun GPU AMD. Journal de chargement du paquet officiel :
# « tensor 'token_embd.weight' ... cannot be used with preferred buffer
# type CPU_REPACK, using CPU instead » — pour les 398 tenseurs, sans
# exception.
#
# COMPILE ICI SANS ROCm/CUDA/VULKAN, mesure sur cette machine, meme
# modele, memes 6 coeurs :
#   pp128 : 4,54 t/s (paquet officiel) -> 44,61 t/s (compile ici)  ~9,8x
#   tg32  : 3,67 t/s (paquet officiel) ->  9,65 t/s (compile ici)  ~2,6x
# Decision de l'utilisateur, prise en connaissance de ce chiffre : compiler
# nous-memes plutot que garder le paquet officiel. Revient sur la decision
# du soir meme — la mesure l'a emporte.
set -euxo pipefail

# EPINGLE AU TAG EXACT DEJA MESURE, JAMAIS « la derniere version » : b6153
# est le tag que le paquet Fedora llama-cpp-0:b6153-3.fc44 utilise deja
# (rpm -q llama-cpp --qf '%{VERSION}-%{RELEASE}'), donc la comparaison
# ci-dessus est loyale — meme source, seul le backend change.
LLAMA_TAG=b6153

dnf5 install -y --setopt=install_weak_deps=False cmake git

TRAVAIL_SRC=/tmp/llama-cpp-source
git clone --depth 1 --branch "$LLAMA_TAG" \
    https://github.com/ggml-org/llama.cpp "$TRAVAIL_SRC"
cd "$TRAVAIL_SRC"

# GGML_NATIVE=ON EST CE QUI ACTIVE CPU_REPACK ICI : sans backend GPU
# enregistre (HIP/CUDA/VULKAN tous a OFF), ggml choisit son chemin CPU le
# plus rapide pour les instructions du processeur qui compile — AVX2+FMA
# sur cette machine, verifie dans /proc/cpuinfo par 39-materiel.sh.
# LLAMA_CURL=OFF : sora.py telecharge deja le modele lui-meme via
# urllib, llama-server n'a pas besoin de son propre client HTTP.
# TOUT SE CONSTRUIT, PAS SEULEMENT « llama-server ». Trouve en le faisant,
# deux fois : cibler un seul target avec « --build ... --target » ne retire
# pas les regles d'installation des AUTRES targets du CMakeLists — « cmake
# --install » a echoue d'abord sur « test-tokenizer-0 », puis sur
# « llama-batched-bench », deux outils que le build cible n'avait jamais
# compiles. Chaque outil sous tools/ porte sa propre regle d'installation,
# independamment du target choisi a la construction — les desactiver un
# par un serait un jeu sans fin. On construit donc tout ce que le
# CMakeLists declare, seul « llama-server » nous interesse ensuite : les
# autres binaires (llama-cli, quantize...) sont retires avec le reste de
# l'arbre source, jamais copies vers l'image.
cmake -B build -DCMAKE_BUILD_TYPE=Release \
    -DGGML_HIP=OFF -DGGML_CUDA=OFF -DGGML_VULKAN=OFF \
    -DGGML_NATIVE=ON -DLLAMA_CURL=OFF
cmake --build build --config Release -j"$(nproc)"
cmake --install build --prefix /usr

[[ -x /usr/bin/llama-server ]] \
    || { echo "ECHEC : /usr/bin/llama-server absent apres compilation." >&2; exit 1; }

# Seul « llama-server » sert a Sora — construire tout le projet a evite le
# jeu de « --target » de tout a l'heure, mais rien n'oblige a garder les
# autres binaires (llama-cli, llama-quantize, llama-batched-bench...)
# dans l'image. Meme regle que partout ailleurs dans ce depot : ce dont S
# a besoin entre dans l'image, pas ce qu'un projet tiers construit par
# defaut. « find », pas une liste a la main qui divergerait au prochain
# tag de llama.cpp.
find /usr/bin -maxdepth 1 -name 'llama-*' ! -name 'llama-server' -delete
rm -rf /usr/lib64/cmake/ggml /usr/lib64/cmake/llama /usr/lib64/pkgconfig/llama.pc \
       /usr/include/ggml*.h /usr/include/gguf.h

# Ldconfig ne recharge pas tout seul le cache pour les .so tout juste
# poses par « cmake --install » — sans lui, le tout premier lancement de
# llama-server echouerait sur des bibliotheques introuvables.
ldconfig

cd /
rm -rf "$TRAVAIL_SRC"
dnf5 remove -y cmake git
dnf5 clean packages

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
