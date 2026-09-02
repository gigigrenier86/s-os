"""Sora — l'assistant IA local de S, un routeur intention -> outil.

CE QUE SORA EST, ET CE QU'ELLE N'EST PAS. Pas un chatbot general : un
routeur qui choisit entre DEUX outils deja existants — regler(), le meme
que la barre laterale appelle deja pour chaque reglage, et lancer(), le
meme dispatch qu'un clic sur une etoile declenche deja (voir Pont.lancer
dans s-constellation) — ou repond simplement en francais si rien de tout
ca ne s'applique. Aucune logique de lancement n'est reecrite ici ; ce
fichier ne fait qu'interroger le modele et appeler ce qui existe deja.

LE MODELE : Qwen3-4B-Instruct-2507 (licence Apache 2.0, verifiee via
l'API Hugging Face elle-meme — voir build_files/50-sora.sh pour la
provenance et l'empreinte exactes), servi par llama-server residant
(s-sora.service), jamais rechargé a chaque question — charger 2,3 Go de
poids a chaque appel serait absurde, meme raison que le serveur wine
residant.

POURQUOI un JSON SCHEMA plutot qu'un simple prompt qui espere. llama-server
sait contraindre sa sortie token par token (grammaire GBNF derivee d'un
json_schema, verifie dans sa propre aide et sa documentation) — la reponse
NE PEUT PAS etre autre chose qu'un objet valide portant les champs
attendus. Pas de parsing fragile d'une reponse en langage libre.

STATELESS PAR CHOIX. Chaque appel envoie system+user, jamais un historique
de conversation garde d'un appel a l'autre — Sora est un routeur de
commandes, pas un compagnon de discussion au long cours ; ajouter une
memoire de conversation grossirait le contexte envoye a chaque question
pour un gain hors de la portee demandee (« un minimum conversationnelle »).
"""
import json
import time
import urllib.error
import urllib.request

URL_SERVEUR = "http://127.0.0.1:8613/v1/chat/completions"
URL_SANTE = "http://127.0.0.1:8613/health"
DELAI = 30

_SCHEMA = {
    "type": "object",
    "properties": {
        "action": {"type": "string", "enum": ["regler", "lancer", "repondre"]},
        "cle": {"type": "string"},
        "valeur": {},
        "ident": {"type": "string"},
        "phrase": {"type": "string"},
    },
    "required": ["action", "phrase"],
    "additionalProperties": False,
}


def _outils_regler():
    """Une ligne par reglage connu — cle, type, et ses choix s'il en a.

    Derive de reglages.rapides() EN DIRECT, jamais une liste recopiee a
    la main qui pourrait diverger silencieusement du vrai etat des
    reglages (meme piege que ce depot a deja nomme ailleurs : deux
    sources qui doivent rester d'accord finissent par diverger)."""
    import reglages
    lignes = []
    try:
        for r in reglages.rapides():
            morceau = "%s (%s)" % (r["cle"], r["type"])
            if r["type"] == "choix":
                morceau += " valeurs possibles: " + \
                    "|".join(c["cle"] for c in r.get("choix", []))
            lignes.append(morceau)
    except Exception:  # noqa: BLE001
        pass
    return lignes


def _idents_lancables(limite=200):
    """id -> nom, tel que noyau.inventaire() les connait — bornee pour ne
    pas gonfler le prompt sans limite sur une machine a des centaines
    d'applications. Un identifiant que Sora ne connaitrait pas retombe de
    toute facon sur une recherche web via Pont.lancer, jamais une erreur
    brutale."""
    import noyau
    lignes = []
    try:
        apps = noyau.inventaire()
        for i, (ident, app) in enumerate(apps.items()):
            if i >= limite:
                break
            lignes.append("%s = %s" % (ident, app.get("nom", ident)))
    except Exception:  # noqa: BLE001
        pass
    return lignes


def _prompt_systeme():
    reglages_connus = "\n".join(_outils_regler())
    apps_connues = "\n".join(_idents_lancables())
    return (
        "Tu es Sora, l'assistant du systeme S. Tu recois une phrase en "
        "francais et tu rends UN SEUL objet JSON.\n\n"
        "Trois actions possibles :\n"
        "- \"regler\" : change un reglage. Donne \"cle\" et \"valeur\".\n"
        "  Reglages connus (cle (type), choix possibles s'il y en a) :\n"
        + reglages_connus + "\n\n"
        "- \"lancer\" : ouvre une application ou un fichier. Donne "
        "\"ident\". Identifiants connus (id = nom) :\n"
        + apps_connues + "\n"
        "  Pour une commande shell explicite, utilise \"cmd:<commande>\". "
        "Pour un identifiant inconnu, mets le nom tel que demande — une "
        "recherche web se fera automatiquement.\n\n"
        "- \"repondre\" : rien a faire, juste repondre en francais dans "
        "\"phrase\".\n\n"
        "\"phrase\" est TOUJOURS presente : une courte confirmation en "
        "francais de ce que tu fais, ou ta reponse si tu ne fais rien."
    )


def interroger(texte, delai=DELAI):
    """Parle au serveur local, rend un dict {action, cle, valeur, ident,
    phrase}. Ne leve jamais : une panne du serveur rend une reponse
    « repondre » qui le dit, plutot que de faire planter l'appelant."""
    charge = {
        "model": "sora",
        "messages": [
            {"role": "system", "content": _prompt_systeme()},
            {"role": "user", "content": texte},
        ],
        "response_format": {
            "type": "json_schema",
            "json_schema": {"name": "action_sora", "strict": True, "schema": _SCHEMA},
        },
        "temperature": 0.3,
    }
    requete = urllib.request.Request(
        URL_SERVEUR, data=json.dumps(charge).encode("utf-8"),
        headers={"Content-Type": "application/json"}, method="POST")
    try:
        with urllib.request.urlopen(requete, timeout=delai) as reponse:
            corps = json.loads(reponse.read().decode("utf-8"))
        contenu = corps["choices"][0]["message"]["content"]
        resultat = json.loads(contenu)
    except (urllib.error.URLError, OSError, TimeoutError,
            KeyError, IndexError, ValueError) as err:
        return {"action": "repondre",
                "phrase": "Sora ne repond pas (%s)." % err}
    resultat.setdefault("action", "repondre")
    resultat.setdefault("phrase", "")
    return resultat


def executer(resultat, pont=None):
    """Applique le verdict de interroger(). « pont » est l'instance QObject
    vivante de s-constellation — None en test autonome, auquel cas
    « lancer » rend juste la phrase du modele sans rien ouvrir."""
    action = resultat.get("action")
    if action == "regler":
        import reglages
        try:
            ok, dit = reglages.regler(resultat.get("cle", ""),
                                      resultat.get("valeur"))
        except Exception as err:  # noqa: BLE001
            return "reglage impossible : %s" % err
        return dit if dit else resultat.get("phrase", "")
    if action == "lancer":
        ident = resultat.get("ident", "")
        if pont is None:
            return "%s (aucune fenetre pour lancer « %s »)" % (
                resultat.get("phrase", ""), ident)
        return pont.lancer(ident)
    return resultat.get("phrase", "")


def demander(texte, pont=None):
    return executer(interroger(texte), pont)


def amorcer(delai_serveur=120):
    """Envoie une question jetable au demarrage du service pour que le
    prefixe du prompt systeme soit deja en cache au premier VRAI appel de
    l'utilisateur — meme principe que l'amorce de s-windows.service (voir
    son ExecStartPost) : le cout du premier traitement est paye par
    systemd au demarrage de la session, jamais par le premier clic.

    MESURE SUR CETTE MACHINE (CPU Intel i5-8400T, 6 coeurs, ROCm absent) :
    le premier appel a llama-server, avec le vrai prompt systeme de Sora
    (1435 jetons, inventaire complet compris), a pris 411,6 s — pres de
    sept minutes. Le second appel, MEME prompt systeme, n'a pris que
    15,6 s : llama-server garde en cache le prefixe deja traite d'un appel
    a l'autre tant que le serveur residant ne redemarre pas. Sans cette
    amorce, la premiere phrase tapee par l'utilisateur dans une session
    paierait ces sept minutes en direct.

    Attend que le serveur reponde avant d'appeler, puisque
    ExecStartPost ne garantit que le lancement du processus, jamais qu'il
    ecoute deja — le modele met lui-meme environ 28 s a charger."""
    debut = time.time()
    pret = False
    while time.time() - debut < delai_serveur:
        try:
            urllib.request.urlopen(URL_SANTE, timeout=2)
            pret = True
            break
        except Exception:  # noqa: BLE001
            time.sleep(1)
    if not pret:
        return
    interroger("bonjour", delai=600)


if __name__ == "__main__":
    import sys
    if len(sys.argv) > 1 and sys.argv[1] == "--amorcer":
        amorcer()
