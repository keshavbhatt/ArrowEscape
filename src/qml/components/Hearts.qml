import QtQuick
import ArrowEscape

// A row of red-heart lives. When a heart is lost it punches bigger, wobbles and
// flashes bright, then collapses to a faint outline — so losing a life reads.
Row {
    id: root
    property int count: 3
    property int max: 3
    spacing: 5

    Repeater {
        model: root.max
        delegate: Item {
            id: cell
            required property int index
            readonly property bool filled: index < root.count
            width: 20; height: 20

            // Animated state (driven imperatively so the lose animation and the
            // resting value never fight over a binding).
            property real st: filled ? 1.0 : 0.85     // scale
            property real spin: 0                      // wobble angle
            property real glow: 0                      // 0 = normal, 1 = bright flash
            opacity: filled ? 1.0 : 0.35
            Behavior on opacity { NumberAnimation { duration: 240 } }

            transform: [
                Scale    { origin.x: 10; origin.y: 10; xScale: cell.st; yScale: cell.st },
                Rotation { origin.x: 10; origin.y: 10; angle: cell.spin }
            ]

            onFilledChanged: {
                if (!filled) lose.restart();
                else regain.restart();          // e.g. after a refill
                hc.requestPaint();              // fill/outline changes with `filled`
            }
            onGlowChanged: hc.requestPaint()

            Canvas {
                id: hc
                anchors.fill: parent
                onPaint: {
                    const ctx = getContext("2d");
                    ctx.reset();
                    const w = width, h = height;
                    ctx.beginPath();
                    ctx.moveTo(w * 0.5, h * 0.30);
                    ctx.bezierCurveTo(w * 0.42, h * 0.15, w * 0.10, h * 0.18, w * 0.10, h * 0.42);
                    ctx.bezierCurveTo(w * 0.10, h * 0.63, w * 0.34, h * 0.76, w * 0.5, h * 0.89);
                    ctx.bezierCurveTo(w * 0.66, h * 0.76, w * 0.90, h * 0.63, w * 0.90, h * 0.42);
                    ctx.bezierCurveTo(w * 0.90, h * 0.18, w * 0.58, h * 0.15, w * 0.5, h * 0.30);
                    ctx.closePath();
                    // Show a filled heart while present, and keep it filled through the
                    // flash as it's being lost; only settle to an outline once cold.
                    if (cell.filled || cell.glow > 0.01) {
                        const base = Theme.heart, white = Qt.rgba(1, 1, 1, 1), g = cell.glow * 0.7;
                        ctx.fillStyle = Qt.rgba(base.r + (white.r - base.r) * g,
                                                base.g + (white.g - base.g) * g,
                                                base.b + (white.b - base.b) * g, 1);
                        ctx.fill();
                    } else {
                        ctx.strokeStyle = Theme.heart;
                        ctx.lineWidth = 2;
                        ctx.stroke();
                    }
                }
                Connections { target: Theme; function onDarkChanged() { hc.requestPaint(); } }
            }

            // Lost: punch up + bright flash, wobble, then collapse to the faint state.
            SequentialAnimation {
                id: lose
                ParallelAnimation {
                    NumberAnimation { target: cell; property: "st";   to: 1.45; duration: 90;  easing.type: Easing.OutQuad }
                    NumberAnimation { target: cell; property: "glow"; to: 1;    duration: 70 }
                }
                ParallelAnimation {
                    SequentialAnimation {
                        NumberAnimation { target: cell; property: "spin"; to: -20; duration: 55 }
                        NumberAnimation { target: cell; property: "spin"; to:  15; duration: 70 }
                        NumberAnimation { target: cell; property: "spin"; to:   0; duration: 70 }
                    }
                    NumberAnimation { target: cell; property: "st";   to: 0.85; duration: 300; easing.type: Easing.OutBack }
                    NumberAnimation { target: cell; property: "glow"; to: 0;    duration: 340 }
                }
            }

            // Regained (refill): a quick reassuring pop back to full size.
            SequentialAnimation {
                id: regain
                NumberAnimation { target: cell; property: "st"; to: 1.2;  duration: 120; easing.type: Easing.OutQuad }
                NumberAnimation { target: cell; property: "st"; to: 1.0;  duration: 180; easing.type: Easing.OutBack }
            }
        }
    }
}
