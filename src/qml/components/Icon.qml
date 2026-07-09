import QtQuick
import ArrowEscape

// A themeable vector icon rendered from real SVG markup (via Qt's SVG image
// backend) — replaces platform emoji so the UI is consistent everywhere. Pick an
// icon by `name`; the stroke colour follows `color`.
Item {
    id: root
    property string name: ""
    property color color: Theme.ink
    property real size: 22

    implicitWidth: size
    implicitHeight: size

    // Stroke-based (Feather-style) icon bodies, 24×24 viewBox.
    readonly property var _paths: ({
        "back":    '<polyline points="15 18 9 12 15 6"/>',
        "restart": '<polyline points="3 3 3 9 9 9"/><path d="M4 15a8 8 0 1 0 2-8.5L3 9"/>',
        "bulb":    '<line x1="9" y1="18" x2="15" y2="18"/><line x1="10" y1="22" x2="14" y2="22"/><path d="M12 2a7 7 0 0 0-4 12.7c.6.5 1 1.3 1 2.1V17h6v-.2c0-.8.4-1.6 1-2.1A7 7 0 0 0 12 2z"/>',
        "gear":    '<line x1="4" y1="8.5" x2="20" y2="8.5"/><line x1="4" y1="15.5" x2="20" y2="15.5"/><circle cx="10" cy="8.5" r="2.6"/><circle cx="15" cy="15.5" r="2.6"/>',
        "palette": '<path d="M12 2C6.5 2 2 6 2 11c0 4 3 7 7 7 1.4 0 2-.9 2-1.9 0-.5-.2-.9-.6-1.3-.3-.3-.5-.7-.5-1.2 0-1 .8-1.8 1.8-1.8H14c3.3 0 6-2.4 6-5.4C20 4.9 16.4 2 12 2z"/><circle cx="7.5" cy="10.5" r=".9"/><circle cx="12" cy="7.5" r=".9"/><circle cx="16.5" cy="10.5" r=".9"/>',
        "close":   '<line x1="18" y1="6" x2="6" y2="18"/><line x1="6" y1="6" x2="18" y2="18"/>',
        "lock":    '<rect x="5" y="11" width="14" height="10" rx="2"/><path d="M8 11V7a4 4 0 0 1 8 0v4"/>',
        "check":   '<polyline points="20 6 9 17 4 12"/>',
        "sun":     '<circle cx="12" cy="12" r="4"/><path d="M12 2v2M12 20v2M2 12h2M20 12h2M4.9 4.9l1.4 1.4M17.7 17.7l1.4 1.4M4.9 19.1l1.4-1.4M17.7 6.3l1.4-1.4"/>',
        "moon":    '<path d="M21 12.8A9 9 0 1 1 11.2 3a7 7 0 0 0 9.8 9.8z"/>'
    })

    // SVG only understands #RRGGBB (not Qt's #AARRGGBB), so pass the opaque RGB
    // and apply any alpha via the Image's opacity instead.
    function _hex() {
        function h(v) { return ("0" + Math.round(v * 255).toString(16)).slice(-2); }
        return "#" + h(color.r) + h(color.g) + h(color.b);
    }
    function _svg() {
        var body = _paths[name] || "";
        return '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="'
             + _hex() + '" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">'
             + body + '</svg>';
    }

    Image {
        anchors.fill: parent
        smooth: true
        fillMode: Image.PreserveAspectFit
        opacity: root.color.a
        sourceSize.width: root.size * 2
        sourceSize.height: root.size * 2
        source: "data:image/svg+xml;base64," + Qt.btoa(root._svg())
    }
}
