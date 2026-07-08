import QtQuick
import ArrowEscape

// A soft filled pill button used for primary actions on the win/lose overlays.
Item {
    id: root
    property string text: ""
    property color fill: Theme.select
    property color ink: "#ffffff"
    signal clicked

    implicitWidth: label.implicitWidth + 44
    implicitHeight: 48

    Rectangle {
        anchors.fill: parent
        radius: height / 2
        color: ma.pressed ? Qt.darker(root.fill, 1.10)
             : ma.containsMouse ? Qt.lighter(root.fill, 1.06)
             : root.fill
        Behavior on color { ColorAnimation { duration: 120 } }
        scale: ma.pressed ? 0.97 : 1.0
        Behavior on scale { NumberAnimation { duration: 90 } }

        Text {
            id: label
            anchors.centerIn: parent
            text: root.text
            color: root.ink
            font.pixelSize: 17
            font.weight: Font.DemiBold
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
