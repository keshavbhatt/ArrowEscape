import QtQuick
import ArrowEscape

// The playfield. The board is drawn at a fixed cell size onto `content`, which is
// zoomable (pinch / wheel) and pannable (drag) so large late-game boards that
// exceed the screen can still be navigated — like the reference game.
Item {
    id: root

    property var board
    property int hintId: -1
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
        content.scale = s;
        content.x = (width - boardW * s) / 2;
        content.y = (height - boardH * s) / 2;
        _busy = false;
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

    // Hint state.
    function showHint() {
        if (!board) return;
        const id = board.hint();
        if (id > 0) { hintId = id; hintTimer.restart(); }
    }
    Timer { id: hintTimer; interval: 2600; onTriggered: root.hintId = -1 }

    Item {
        id: content
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
                onTapped: (id) => root.board.tap(id)
            }
        }
    }

    // ── Navigation: pan (drag) + zoom (pinch / wheel) ──
    DragHandler {
        target: content
        // A plain drag pans; taps still reach the per-cell hit areas.
    }
    PinchHandler {
        target: content
        minimumScale: root.minScale
        maximumScale: root.maxScale
    }
    WheelHandler {
        target: null
        acceptedModifiers: Qt.NoModifier
        onWheel: (ev) => {
            const factor = ev.angleDelta.y > 0 ? 1.12 : 1 / 1.12;
            const ns = Math.max(root.minScale, Math.min(root.maxScale, content.scale * factor));
            // Zoom toward the cursor.
            const px = (ev.x - content.x) / content.scale;
            const py = (ev.y - content.y) / content.scale;
            content.scale = ns;
            content.x = ev.x - px * ns;
            content.y = ev.y - py * ns;
        }
    }
}
