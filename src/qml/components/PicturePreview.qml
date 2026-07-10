import QtQuick
import ArrowEscape

// Draws a picture mask as a small filled silhouette — used for album tiles.
Item {
    id: root
    property var mask: []            // array of row strings, '#'/'1' = filled
    property color color: Theme.ink

    Canvas {
        id: cv
        anchors.fill: parent
        onPaint: {
            const ctx = getContext("2d");
            ctx.reset();
            const rows = root.mask.length;
            if (!rows) return;
            const cols = root.mask[0].length;
            const cs = Math.min(width / cols, height / rows);
            const ox = (width - cs * cols) / 2, oy = (height - cs * rows) / 2;
            ctx.fillStyle = root.color;
            for (var r = 0; r < rows; ++r)
                for (var c = 0; c < cols; ++c) {
                    const ch = root.mask[r].charAt(c);
                    if (ch === '#' || ch === '1')
                        ctx.fillRect(ox + c * cs, oy + r * cs, cs + 0.5, cs + 0.5);
                }
        }
    }
    onColorChanged: cv.requestPaint()
    onMaskChanged: cv.requestPaint()
    onWidthChanged: cv.requestPaint()
}
