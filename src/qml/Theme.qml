pragma Singleton
import QtQuick

// App-wide design tokens. The reference games are drawn as ink on parchment:
// a warm cream page, thin brown strokes, no fills. The only colour is the blue
// highlight on the selected/hinted arrow and the blue water-drop lives.
QtObject {
    id: theme

    property bool dark: false

    // ── Surfaces (parchment) ──
    readonly property color bg:      dark ? "#2a2620" : "#efe7d6"
    readonly property color surface: dark ? "#332e26" : "#f5efe1"
    readonly property color band:    dark ? "#3d372c" : "#d9c9a6"   // bottom banner

    // ── Ink (the arrows) ── richer brown, closer to the reference
    readonly property color ink:     dark ? "#cdb082" : "#7a5a37"
    readonly property color inkDim:  dark ? "#6f6350" : "#a98f68"

    // ── Accents ──
    readonly property color select:  "#3ea0e6"   // highlighted / hinted arrow
    readonly property color drop:     "#5bb3ea"   // water-drop lives
    readonly property color good:     "#57b98a"
    readonly property color blockRed: "#c0563a"   // blocked-tap flash

    // Faint dot marking each empty grid cell (shows through where arrows cleared).
    readonly property color dot:     dark ? Qt.rgba(0.85, 0.78, 0.62, 0.20)
                                          : Qt.rgba(0.50, 0.40, 0.26, 0.30)

    // Per-snake colours for the optional (Pro) "Colorful arrows" mode. Two
    // variants so they stay legible on both the cream and the dark parchment.
    readonly property var arrowPalette: dark
        ? ["#ef7a5f", "#45c7b4", "#7b93ea", "#e6b452", "#a97be0", "#7bc267", "#e87ba6", "#5cb8e8"]
        : ["#c9573b", "#2b9a8a", "#4666c4", "#bd8526", "#8f5bbf", "#529c40", "#cc567f", "#2f96cf"]
    function arrowColor(i) {
        var p = arrowPalette;
        return p[((i % p.length) + p.length) % p.length];
    }

    // ── Text ──
    readonly property color title:   dark ? "#d9a24e" : "#a9772e"
    readonly property color text:    dark ? "#e7dcc6" : "#6f5a3a"
    readonly property color textDim: dark ? "#9a8f7a" : "#a8987a"

    // ── Metrics ──
    readonly property int rsm: 8
    readonly property int r:   14
    readonly property int rlg: 22

    readonly property string ui: Qt.application.font.family
}
