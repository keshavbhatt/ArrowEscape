import QtQuick
import ArrowEscape

// A row of water-drop lives (the reference games use blue droplets, not hearts).
// Spent drops fade to a faint outline rather than vanishing.
Row {
    id: root
    property int count: 3
    property int max: 3
    spacing: 6

    Repeater {
        model: root.max
        delegate: Canvas {
            required property int index
            readonly property bool filled: index < root.count
            width: 20; height: 24
            opacity: filled ? 1.0 : 0.35
            Behavior on opacity { NumberAnimation { duration: 220 } }

            onPaint: {
                const ctx = getContext("2d");
                ctx.reset();
                const w = width, h = height;
                ctx.beginPath();
                ctx.moveTo(w / 2, 1);
                ctx.bezierCurveTo(w * 0.98, h * 0.52, w * 0.86, h - 1, w / 2, h - 1);
                ctx.bezierCurveTo(w * 0.14, h - 1, w * 0.02, h * 0.52, w / 2, 1);
                ctx.closePath();
                if (filled) {
                    ctx.fillStyle = Theme.drop;
                    ctx.fill();
                } else {
                    ctx.strokeStyle = Theme.drop;
                    ctx.lineWidth = 2;
                    ctx.stroke();
                }
            }
            Connections { target: Theme; function onDarkChanged() { requestPaint(); } }
        }
    }
}
