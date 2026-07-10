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
    property bool colorful: false      // Pro: each snake gets its own colour

    readonly property bool hinted: hintId === arrowId
    readonly property real m: cellSize * 0.6
    readonly property var dirVec: [[0, -1], [1, 0], [0, 1], [-1, 0]][dir]
    property real redAmt: 0
    property real hintNudge: 0          // bob distance along the launch direction
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

    // While launching, the snake threads across the whole board AND keeps flying
    // out past the grid — so its canvas is the board plus a wide margin on every
    // side (the surrounding play area clips it at the window edge). Only the few
    // launching snakes pay this cost. At rest it uses a tight bbox canvas.
    readonly property real m2: cellSize * 14      // fly-out reach beyond the grid
    readonly property real ox: escaping ? -m2 : (bb.minc * cellSize - m)
    readonly property real oy: escaping ? -m2 : (bb.minr * cellSize - m)

    x: ox
    y: oy
    width:  escaping ? gridCols * cellSize + 2 * m2 : (bb.maxc - bb.minc + 1) * cellSize + 2 * m
    height: escaping ? gridRows * cellSize + 2 * m2 : (bb.maxr - bb.minr + 1) * cellSize + 2 * m

    // ── Entrance animation ──
    // On load each arrow DRAWS itself from tail to head — the line is traced into
    // place and the arrowhead fades in at the end — so the board looks hand-sketched.
    // `drawProgress` is the fraction of the snake drawn (0 = nothing, 1 = whole).
    property real drawProgress: 0
    onDrawProgressChanged: canvas.requestPaint()

    // Stagger by distance from the nearest board edge (fills outside-in).
    readonly property real introDelay: {
        var cx = (bb.minc + bb.maxc) / 2, cy = (bb.minr + bb.maxr) / 2;
        var d = Math.min(cx, gridCols - 1 - cx, cy, gridRows - 1 - cy);
        return Math.max(0, d) * 26;
    }

    SequentialAnimation {
        running: true
        PauseAnimation { duration: snake.introDelay }
        NumberAnimation {
            target: snake; property: "drawProgress"; from: 0; to: 1
            duration: Math.max(220, Math.min(560, snake.cells.length * 55))
            easing.type: Easing.InOutSine
        }
    }

    Canvas {
        id: canvas
        anchors.fill: parent
        onPaint: {
            const cs = snake.cellSize;
            const ctx = getContext("2d");
            ctx.reset();
            ctx.lineCap = "round";
            ctx.lineJoin = "round";
            var col = snake.hinted ? Theme.select
                    : (snake.colorful ? Theme.arrowColor(snake.arrowId) : Theme.ink);
            if (snake.redAmt > 0)
                col = snake._lerp(col, Theme.blockRed, snake.redAmt);
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
                if (snake.drawProgress >= 1) {
                    drawArrow(pts);
                    return;
                }
                if (snake.drawProgress <= 0.0001)
                    return;                                   // not drawn yet

                // Trace the shaft from the tail up to `shaftFrac` of its length
                // (fully drawn a touch before the animation ends, so the head has
                // something to attach to).
                const shaftFrac = Math.min(1, snake.drawProgress / 0.85);
                var seg = [];
                for (var i = 1; i < pts.length; ++i)
                    seg.push(Math.hypot(pts[i].x - pts[i - 1].x, pts[i].y - pts[i - 1].y));
                var total = 0; for (var i = 0; i < seg.length; ++i) total += seg[i];
                var target = shaftFrac * total, acc = 0;
                var partial = [pts[0]];
                for (var i = 0; i < seg.length; ++i) {
                    if (acc + seg[i] <= target) { partial.push(pts[i + 1]); acc += seg[i]; }
                    else {
                        var t = seg[i] > 0 ? (target - acc) / seg[i] : 0;
                        partial.push({ x: pts[i].x + (pts[i + 1].x - pts[i].x) * t,
                                       y: pts[i].y + (pts[i + 1].y - pts[i].y) * t });
                        break;
                    }
                }
                if (partial.length >= 2) {
                    ctx.beginPath();
                    ctx.moveTo(partial[0].x, partial[0].y);
                    for (var i = 1; i < partial.length; ++i) ctx.lineTo(partial[i].x, partial[i].y);
                    ctx.stroke();
                }
                // Arrowhead grows/fades in over the last stretch of the draw.
                const ha = Math.max(0, Math.min(1, (snake.drawProgress - 0.8) / 0.2));
                if (ha > 0) {
                    const head = pts[pts.length - 1];
                    const px = -dv[1], py = dv[0];
                    const tip  = { x: head.x + dv[0] * cs * 0.36, y: head.y + dv[1] * cs * 0.36 };
                    const bcx = head.x - dv[0] * cs * 0.02, bcy = head.y - dv[1] * cs * 0.02;
                    const half = cs * 0.21 * ha;
                    ctx.globalAlpha = ha;
                    ctx.beginPath();
                    ctx.moveTo(tip.x, tip.y);
                    ctx.lineTo(bcx + px * half, bcy + py * half);
                    ctx.lineTo(bcx - px * half, bcy - py * half);
                    ctx.closePath();
                    ctx.fillStyle = col; ctx.fill();
                    ctx.globalAlpha = 1;
                }
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

    onHintedChanged:   { if (!hinted) hintNudge = 0; canvas.requestPaint(); }
    onColorfulChanged: canvas.requestPaint()
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
        // Travel until the whole snake clears the grid AND flies out to the window.
        var travelCells = (cells.length - 1) + edgeCells + 14;
        fly.to = travelCells * cellSize;
        fly.duration = Math.min(720, Math.max(260, travelCells * 30));
        fly.start();
    }

    // Blocked tap: the whole arrow flashes red (double pulse, held long enough to
    // read as "this one can't leave yet") plus a small shake.
    SequentialAnimation {
        id: redFlash
        NumberAnimation { target: snake; property: "redAmt"; to: 1;    duration: 60 }
        NumberAnimation { target: snake; property: "redAmt"; to: 0.45; duration: 130 }
        NumberAnimation { target: snake; property: "redAmt"; to: 1;    duration: 110 }
        PauseAnimation  { duration: 90 }
        NumberAnimation { target: snake; property: "redAmt"; to: 0;    duration: 420; easing.type: Easing.InQuad }
    }
    property real _shakeX: 0
    SequentialAnimation {
        id: shake
        NumberAnimation { target: snake; property: "_shakeX"; to: -5; duration: 45 }
        NumberAnimation { target: snake; property: "_shakeX"; to:  5; duration: 70 }
        NumberAnimation { target: snake; property: "_shakeX"; to:  0; duration: 55 }
    }

    // Hint: the arrow bobs toward its launch direction and springs back, on a
    // loop, so it's obvious both WHICH arrow and WHICH WAY it will leave.
    SequentialAnimation {
        id: hintBob
        running: snake.hinted && !snake.escaping
        loops: Animation.Infinite
        NumberAnimation { target: snake; property: "hintNudge"; to: snake.cellSize * 0.24
                          duration: 300; easing.type: Easing.OutQuad }
        NumberAnimation { target: snake; property: "hintNudge"; to: 0
                          duration: 520; easing.type: Easing.OutBounce }
        PauseAnimation  { duration: 160 }
    }
    transform: Translate {
        x: snake._shakeX + snake.dirVec[0] * snake.hintNudge
        y: snake.dirVec[1] * snake.hintNudge
    }

    Connections {
        target: snake.board
        function onBlocked(id) {
            if (id === snake.arrowId) { redFlash.restart(); shake.restart(); }
        }
    }
}
