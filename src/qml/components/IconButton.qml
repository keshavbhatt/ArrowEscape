import QtQuick
import ArrowEscape

// A quiet round icon button (top bar). `icon` is an SVG icon name (see Icon.qml).
Item {
    id: root
    property string icon: ""
    property real iconSize: 22
    property color color: Theme.textDim
    signal clicked

    implicitWidth: 44
    implicitHeight: 44

    Rectangle {
        anchors.fill: parent
        radius: width / 2
        color: ma.pressed ? Qt.rgba(Theme.select.r, Theme.select.g, Theme.select.b, 0.18)
             : ma.containsMouse ? Qt.rgba(Theme.text.r, Theme.text.g, Theme.text.b, 0.08)
             : "transparent"
        Behavior on color { ColorAnimation { duration: 120 } }

        Icon {
            anchors.centerIn: parent
            name: root.icon
            size: root.iconSize
            color: root.color
        }
    }

    MouseArea {
        id: ma
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}
