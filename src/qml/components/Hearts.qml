import QtQuick
import ArrowEscape

// A row of red-heart lives. Spent hearts fade to a faint outline.
Row {
    id: root
    property int count: 3
    property int max: 3
    spacing: 5

    Repeater {
        model: root.max
        delegate: Canvas {
            required property int index
            readonly property bool filled: index < root.count
            width: 20; height: 20
            opacity: filled ? 1.0 : 0.35
            Behavior on opacity { NumberAnimation { duration: 220 } }
            scale: filled ? 1.0 : 0.85
            Behavior on scale { NumberAnimation { duration: 200; easing.type: Easing.OutBack } }

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
                if (filled) {
                    ctx.fillStyle = Theme.heart;
                    ctx.fill();
                } else {
                    ctx.strokeStyle = Theme.heart;
                    ctx.lineWidth = 2;
                    ctx.stroke();
                }
            }
            Connections { target: Theme; function onDarkChanged() { requestPaint(); } }
        }
    }
}
