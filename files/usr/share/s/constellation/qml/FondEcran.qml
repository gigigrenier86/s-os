import QtQuick
import "Fonds.js" as Fonds

// Un fond d'ecran : peint par Fonds.js, ou une image de l'utilisateur.
//
// UN SEUL COMPOSANT POUR TOUS LES ENDROITS QUI MONTRENT UN FOND — le bureau,
// les vignettes du choix, le fond flou de la barre de Windows et de son menu
// Demarrer. Chacun lui donne une taille ; il peint a cette taille, et c'est
// tout ce qu'il sait faire. Un fond peint deux fois a deux endroits finirait
// par diverger, ce depot le repete depuis « s-partage ».
//
// LA REGLE DE LA PAGE D'ORIGINE TIENT : le canevas ne se repeint que si le fond,
// ses couleurs ou sa taille changent. Au repos, il ne coute rien.
Item {
    id: racine

    property string fondId: Theme.fondId
    property string theme: Theme.nom
    property var options: Theme.optionsFond

    readonly property bool estImage: fondId.indexOf("image:") === 0
    readonly property string cheminImage: estImage ? fondId.substring(6) : ""

    Canvas {
        id: toile
        anchors.fill: parent
        visible: !racine.estImage
        renderStrategy: Canvas.Cooperative
        onPaint: {
            // Meme garde et meme temoin que les vignettes d'avant : une taille
            // impossible ne peint rien, ET le dit. Voir le carnet du 2026-08-25.
            if (!isFinite(width) || !isFinite(height) || width <= 0 || height <= 0) {
                console.warn("fond " + racine.fondId + " : dimensions refusees "
                             + width + "x" + height);
                return;
            }
            var g = getContext("2d");
            g.reset();
            Fonds.peindreFond(g, racine.fondId, width, height, racine.options, racine.theme);
        }
        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()
    }

    // UNE IMAGE DECODEE A LA TAILLE OU ON LA MONTRE, JAMAIS A LA SIENNE. Une
    // photo de vingt-quatre megapixels decodee telle quelle pese quatre-vingt-
    // seize megaoctets ; a la taille de l'ecran, huit — et dans le fond flou de
    // la barre, quelques kilo-octets. « sourceSize » le decide, et « Crop » la
    // couvre comme le ferait un fond de bureau.
    Image {
        anchors.fill: parent
        visible: racine.estImage
        source: racine.estImage ? "file://" + racine.cheminImage : ""
        sourceSize.width: Math.max(1, Math.round(racine.width))
        sourceSize.height: Math.max(1, Math.round(racine.height))
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        cache: false
        smooth: true
    }

    onFondIdChanged: if (!estImage) toile.requestPaint()
    onOptionsChanged: if (!estImage) toile.requestPaint()
    onThemeChanged: if (!estImage) toile.requestPaint()
}
