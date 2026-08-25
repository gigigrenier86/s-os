pragma Singleton
import QtQuick

// LE BUREAU, ATTEIGNABLE DE PARTOUT.
//
// POURQUOI CE FICHIER EXISTE. Dans les delegues du menu Demarrer, l'identifiant
// racine du fichier — « bureau » — NE RESOUT PAS. Le journal de la machine le
// dit sans ambiguite, a deux endroits differents et a chaque clic :
//
//   Constellation.qml:403: ReferenceError: bureau is not defined
//   Constellation.qml:497: ReferenceError: bureau is not defined
//
// Consequence visible : epingler une application ne disait rien, et CHANGER DE
// FOND D'ECRAN NE FAISAIT RIEN DU TOUT. Les vignettes s'affichaient, le clic
// arrivait, et le gestionnaire mourait a sa premiere ligne.
//
// DEUX CORRECTIFS ONT ETE ESSAYES AVANT CELUI-CI, ET LE SECOND A ETE MESURE
// FAUX SUR LA MACHINE :
//
//   1. « Window.window » — un type attache, donc insensible aux identifiants.
//      Sauf qu'il ne s'attache qu'a un Item, et un TapHandler n'en est pas un :
//      « QML TapHandler: Window.window does only support types deriving from
//      Item », puis « TypeError: Value is null » a la ligne suivante.
//
//   2. Une propriete de contexte posee apres le chargement de la scene. Elle
//      aurait marche, mais elle force une reevaluation de toutes les liaisons
//      deja etablies — et ce fichier-la porte deja un commentaire expliquant
//      pourquoi le pont est pose AVANT le chargement.
//
// CE QUI RESOUT A COUP SUR DANS CES DELEGUES : un singleton. La preuve est sous
// les yeux — « Theme.texte2 » y est lu sans erreur, dans le meme delegue, a
// cinq lignes du gestionnaire qui echouait. Un singleton n'est pas cherche dans
// la chaine des contextes : c'est un type, resolu a la compilation.
//
// Le bureau se pose ici lui-meme au demarrage, et rien d'autre n'y touche.
QtObject {
    property var bureau: null
}
