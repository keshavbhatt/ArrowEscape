import QtQuick
import ArrowEscape

// One arrow "snake": a winding line through several cells drawn as a thick
// rounded ink stroke with a clean arrowhead at the head.
//
// Launch: the snake does NOT rigidly slide — it *threads* forward. The head
// travels straight out in its direction while the body follows the head's trail
// along its own path, straightening as it goes and slithering off the edge, just
// like the reference game. This is done by sliding a fixed-length window along a
// "track" = the body path continued straight past the head to beyond the edge.
Item {
    id: snake

    // ── From the model ──
    required property int arrowId
    required property int dir
    required property bool escaping
    required property var cells        // array of points {x: col, y: row}, tail → head

    // ── Injected by Board.qml ──
    property real cellSize: 48
    property int  gridCols: 1
    property int  gridRows: 1
    property var  board
    property int  hintId: -1

    readonly property bool hinted: hintId === arrowId
    readonly property real m: cellSize * 0.6
    property real redAmt: 0
    property real launchArc: 0          // distance the thread window has advanced

    signal tapped(int id)

    function _lerp(a, b, t) {
        return Qt.rgba(a.r + (b.r - a.r) * t, a.g + (b.g - a.g) * t, a.b + (b.b - a.b) * t, 1);
    }

    // Static bounding box of the path, in cell coordinates.
    readonly property var bb: {
        var minc = 1e9, minr = 1e9, maxc = -1e9, maxr = -1e9;
        for (var i = 0; i < cells.length; ++i) {
            var p = cells[i];
            minc = Math.min(minc, p.x); minr = Math.min(minr, p.y);
            maxc = Math.max(maxc, p.x); maxr = Math.max(maxr, p.y);
        }
        return { minc: minc, minr: minr, maxc: maxc, maxr: maxr };
    }

    // While launching, the snake threads across the whole board, so it draws onto
    // a board-sized canvas (only the few launching snakes pay this cost). At rest
    // it uses a tight bbox canvas.
    readonly property real ox: escaping ? 0 : (bb.minc * cellSize - m)
    readonly property real oy: escaping ? 0 : (bb.minr * cellSize - m)
    x: ox
    y: oy
    width:  escaping ? gridCols * cellSize : (bb.maxc - bb.minc + 1) * cellSize + 2 * m
    height: escaping ? gridRows * cellSize : (bb.maxr - bb.minr + 1) * cellSize + 2 * m

    Canvas {
        id: canvas
        anchors.fill: parent
        onPaint: {
            const cs = snake.cellSize;
            const ctx = getContext("2d");
            ctx.reset();
            ctx.lineCap = "round";
            ctx.lineJoin = "round";
            var col = snake.hinted ? Theme.select : Theme.ink;
            if (snake.redAmt > 0)
                col = snake._lerp(Theme.ink, Theme.blockRed, snake.redAmt);
            ctx.strokeStyle = col;
            const lw = cs * (snake.hinted ? 0.15 : 0.13);
            ctx.lineWidth = lw;

            const dv = [[0, -1], [1, 0], [0, 1], [-1, 0]][snake.dir];
            // cell (col,row) → local pixel centre
            function pc(p) { return { x: p.x * cs + cs / 2 - snake.ox, y: p.y * cs + cs / 2 - snake.oy }; }

            // Draw an arrow given a local polyline (tail → head). The head is a
            // small FILLED TRIANGLE with softly rounded corners — exactly like the
            // reference game.
            function drawArrow(pts) {
                const head = pts[pts.length - 1];
                // Shaft up to the head centre (the triangle covers the join).
                ctx.beginPath();
                ctx.moveTo(pts[0].x, pts[0].y);
                for (var i = 1; i < pts.length; ++i) ctx.lineTo(pts[i].x, pts[i].y);
                ctx.stroke();
                // Filled triangle head: tip forward, base perpendicular behind it.
                const px = -dv[1], py = dv[0];           // perpendicular to the head dir
                const tip  = { x: head.x + dv[0] * cs * 0.36, y: head.y + dv[1] * cs * 0.36 };
                const bcx = head.x - dv[0] * cs * 0.02, bcy = head.y - dv[1] * cs * 0.02;
                const half = cs * 0.21;
                ctx.beginPath();
                ctx.moveTo(tip.x, tip.y);
                ctx.lineTo(bcx + px * half, bcy + py * half);
                ctx.lineTo(bcx - px * half, bcy - py * half);
                ctx.closePath();
                ctx.fillStyle = col;
                ctx.fill();
                ctx.lineWidth = cs * 0.05;                // round the triangle corners
                ctx.stroke();
                ctx.lineWidth = lw;                       // restore for the next snake
            }

            if (!snake.escaping) {
                var pts = snake.cells.map(pc);
                drawArrow(pts);
                return;
            }

            // ── Threading launch ──
            // track = body centres (tail→head) then continue straight past the head.
            var body = snake.cells.map(pc);
            var head = body[body.length - 1];
            var exit = { x: head.x + dv[0] * (snake.gridCols + snake.gridRows) * cs,
                         y: head.y + dv[1] * (snake.gridCols + snake.gridRows) * cs };
            var track = body.concat([exit]);
            // cumulative arc length
            var arc = [0];
            for (var i = 1; i < track.length; ++i)
                arc.push(arc[i - 1] + Math.hypot(track[i].x - track[i - 1].x, track[i].y - track[i - 1].y));
            var L = arc[body.length - 1];              // body arc length
            function sample(s) {
                if (s <= 0) return track[0];
                if (s >= arc[arc.length - 1]) return track[track.length - 1];
                for (var i = 1; i < track.length; ++i) {
                    if (s <= arc[i]) {
                        var t = (s - arc[i - 1]) / (arc[i] - arc[i - 1]);
                        return { x: track[i - 1].x + (track[i].x - track[i - 1].x) * t,
                                 y: track[i - 1].y + (track[i].y - track[i - 1].y) * t };
                    }
                }
                return track[track.length - 1];
            }
            var a = snake.launchArc;                   // window = [a, a+L] along the track
            var end = a + L;
            var pts2 = [ sample(a) ];
            for (var i = 1; i < track.length; ++i)
                if (arc[i] > a && arc[i] < end) pts2.push(track[i]);
            pts2.push(sample(end));
            drawArrow(pts2);
        }
    }

    onHintedChanged:   canvas.requestPaint()
    onRedAmtChanged:   canvas.requestPaint()
    onLaunchArcChanged: canvas.requestPaint()
    onWidthChanged:    canvas.requestPaint()
    onHeightChanged:   canvas.requestPaint()
    Connections { target: Theme; function onDarkChanged() { canvas.requestPaint(); } }

    // Invisible per-cell hit areas (disabled once launching).
    Repeater {
        model: snake.escaping ? [] : snake.cells
        delegate: MouseArea {
            required property var modelData
            x: (modelData.x - snake.bb.minc) * snake.cellSize + snake.m
            y: (modelData.y - snake.bb.minr) * snake.cellSize + snake.m
            width: snake.cellSize
            height: snake.cellSize
            cursorShape: Qt.PointingHandCursor
            onClicked: snake.tapped(snake.arrowId)
        }
    }

    // Threading launch animation. Distance = body length + head-to-edge + a cell,
    // so the tail clears the edge. Duration scales with distance for even speed.
    NumberAnimation {
        id: fly
        target: snake
        property: "launchArc"
        from: 0
        easing.type: Easing.InQuad          // accelerate out — a quick "whoosh"
        onStopped: if (snake.board) snake.board.finishEscape(snake.arrowId)
    }
    onEscapingChanged: {
        if (!escaping) return;
        var head = cells[cells.length - 1];
        var edgeCells = [head.y, gridCols - 1 - head.x, gridRows - 1 - head.y, head.x][dir];
        var travelCells = (cells.length - 1) + edgeCells + 1.2;
        fly.to = travelCells * cellSize;
        fly.duration = Math.min(620, Math.max(240, travelCells * 34));
        fly.start();
    }

    // Blocked tap: red flash + small shake.
    SequentialAnimation {
        id: redFlash
        NumberAnimation { target: snake; property: "redAmt"; to: 1; duration: 70 }
        NumberAnimation { target: snake; property: "redAmt"; to: 0; duration: 320 }
    }
    property real _shakeX: 0
    SequentialAnimation {
        id: shake
        NumberAnimation { target: snake; property: "_shakeX"; to: -5; duration: 45 }
        NumberAnimation { target: snake; property: "_shakeX"; to:  5; duration: 70 }
        NumberAnimation { target: snake; property: "_shakeX"; to:  0; duration: 55 }
    }
    transform: Translate { x: snake._shakeX }

    Connections {
        target: snake.board
        function onBlocked(id) {
            if (id === snake.arrowId) { redFlash.restart(); shake.restart(); }
        }
    }
}
