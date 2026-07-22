import QtQuick
import ArrowEscape

// The playfield. The board is drawn at a fixed cell size onto `content`, which is
// zoomable (pinch / wheel) and pannable (drag) so large late-game boards that
// exceed the screen can still be navigated — like the reference game.
Item {
    id: root

    property var board
    property int hintId: -1
    property bool colorful: false      // Pro: colour each snake
    property real baseCell: 42

    clip: true

    readonly property int  cols: board ? board.cols : 1
    readonly property int  rows: board ? board.rows : 1
    readonly property real boardW: cols * baseCell
    readonly property real boardH: rows * baseCell

    readonly property real minScale: Math.min(1, fitScale() * 0.6)
    readonly property real maxScale: 3.0
    function fitScale() {
        if (boardW <= 0 || boardH <= 0) return 1;
        return Math.min(width / boardW, height / boardH, 1.0) * 0.96;
    }

    // Reset to a centred, fit-to-view position (called on new level / resize).
    function resetView() {
        const s = fitScale();
        _busy = true;
        content.rotation = 0;
        content.scale = s;
        content.x = (width - boardW * s) / 2;
        content.y = (height - boardH * s) / 2;
        _busy = false;
    }

    // Straighten a board tilted by a rotating pinch (smoothly, keeping zoom/pan).
    function resetOrientation() { unrotate.restart(); }
    NumberAnimation {
        id: unrotate
        target: content; property: "rotation"; to: 0
        duration: 200; easing.type: Easing.OutCubic
        onStopped: root.clampView()
    }

    // Zoom by `factor` keeping the view point (x, y) fixed under the cursor.
    function zoomAt(x, y, factor) {
        const ns = Math.max(minScale, Math.min(maxScale, content.scale * factor));
        const px = (x - content.x) / content.scale;
        const py = (y - content.y) / content.scale;
        content.scale = ns;
        content.x = x - px * ns;
        content.y = y - py * ns;
    }

    property bool _busy: false
    function clampView() {
        if (_busy) return;
        _busy = true;
        const s = content.scale;
        const w = boardW * s, h = boardH * s;
        // If the content is smaller than the viewport, centre it; else keep it
        // covering the viewport (can't drag it off into empty space).
        content.x = (w <= width)  ? (width  - w) / 2 : Math.max(width  - w, Math.min(0, content.x));
        content.y = (h <= height) ? (height - h) / 2 : Math.max(height - h, Math.min(0, content.y));
        _busy = false;
    }

    onWidthChanged: resetView()
    onHeightChanged: resetView()
    Component.onCompleted: resetView()
    Connections {
        target: root.board
        function onBoardChanged() { root.resetView(); dots.requestPaint(); }
    }

    // Hint state. Returns true only when a NEW hint was actually revealed, so the
    // caller can charge a hint only then — repeated taps while a hint is already
    // showing (or when there's nothing to hint) cost nothing.
    function showHint() {
        if (!board) return false;
        if (hintId !== -1) return false;         // a hint is already on screen
        const id = board.hint();
        if (id <= 0) return false;               // nothing hintable (e.g. board solved)
        hintId = id; hintTimer.restart();
        return true;
    }
    Timer { id: hintTimer; interval: 2600; onTriggered: root.hintId = -1 }

    Item {
        id: content
        objectName: "boardContent"   // dev hooks (AE_INPUTTEST) locate this
        width: root.boardW
        height: root.boardH
        transformOrigin: Item.TopLeft
        onXChanged: root.clampView()
        onYChanged: root.clampView()
        onScaleChanged: root.clampView()

        // Dot grid behind the snakes.
        Canvas {
            id: dots
            anchors.fill: parent
            visible: !(root.board && root.board.pictureMode)
            onPaint: {
                const ctx = getContext("2d");
                ctx.reset();
                ctx.fillStyle = Theme.dot;
                const cs = root.baseCell;
                const rad = Math.max(1.4, cs * 0.055);
                for (var r = 0; r < root.rows; ++r)
                    for (var c = 0; c < root.cols; ++c) {
                        ctx.beginPath();
                        ctx.arc(c * cs + cs / 2, r * cs + cs / 2, rad, 0, 2 * Math.PI);
                        ctx.fill();
                    }
            }
            Connections { target: Theme; function onDarkChanged() { dots.requestPaint(); } }
        }

        Repeater {
            id: snakes
            model: root.board
            delegate: ArrowSnake {
                cellSize: root.baseCell
                gridCols: root.cols
                gridRows: root.rows
                board: root.board
                hintId: root.hintId
                colorful: root.colorful
                onTapped: (id) => root.board.tap(id)
            }
        }
    }

    // ── Navigation: pan (drag) + zoom (pinch / wheel) ──
    // These cooperate with the snakes' per-cell TapHandlers via passive grabs:
    // the DragHandler takes over (and cancels the tap) once the press moves
    // past the drag threshold, so panning works from anywhere on the board.
    DragHandler {
        target: content
        acceptedButtons: Qt.LeftButton | Qt.MiddleButton
    }
    PinchHandler {
        target: content
        minimumScale: root.minScale
        maximumScale: root.maxScale
    }
    WheelHandler {
        target: null
        onWheel: (ev) => {
            // Wayland/touchpads send scroll-phase begin/end markers with a ZERO
            // delta, and hi-res wheels send many small deltas. Naively mapping
            // "delta > 0 ? in : out" zooms OUT on every marker, cancelling the
            // gesture — so ignore empty events and scale by the actual delta
            // (±120 = one classic notch = ×1.12), falling back to pixelDelta.
            var dy = ev.angleDelta.y !== 0 ? ev.angleDelta.y : ev.pixelDelta.y * 2;
            if (dy === 0)
                return;
            root.zoomAt(ev.x, ev.y, Math.pow(1.12, dy / 120));
        }
    }

    // ── Zoom controls: an always-visible fallback (and affordance) for zoom,
    // independent of wheel/pinch hardware. Fit re-centres at fit-to-view scale.
    component ZoomBtn: Rectangle {
        property alias label: zt.text
        signal clicked
        width: 40; height: 40; radius: 20
        color: Theme.surface
        opacity: 0.92
        border.width: 1
        border.color: Qt.rgba(Theme.ink.r, Theme.ink.g, Theme.ink.b, 0.25)
        Text { id: zt; anchors.centerIn: parent; color: Theme.ink
               font.pixelSize: 16; font.weight: Font.Bold }
        TapHandler { onTapped: parent.clicked() }
        HoverHandler { cursorShape: Qt.PointingHandCursor }
    }
    Column {
        anchors { right: parent.right; bottom: parent.bottom; margins: 10 }
        spacing: 8
        ZoomBtn { label: "+";   onClicked: root.zoomAt(root.width / 2, root.height / 2, 1.25) }
        ZoomBtn { label: "−";   onClicked: root.zoomAt(root.width / 2, root.height / 2, 1 / 1.25) }
        ZoomBtn { label: qsTr("Fit"); onClicked: root.resetView() }
        // Straighten-up appears only once a pinch has actually tilted the board.
        ZoomBtn { label: "↺"; visible: content.rotation !== 0
                  onClicked: root.resetOrientation() }
    }
}
