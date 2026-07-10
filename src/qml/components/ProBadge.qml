import QtQuick
import ArrowEscape

// A golden crown + theme-coloured "Pro" label, shown while the user has Pro
// access (paid or trial).
Rectangle {
    id: root
    property string label: qsTr("Pro")

    implicitWidth: row.implicitWidth + 16
    implicitHeight: 24
    radius: height / 2
    color: Qt.rgba(Theme.gold.r, Theme.gold.g, Theme.gold.b, 0.18)

    Row {
        id: row
        anchors.centerIn: parent
        spacing: 4
        Icon {
            name: "crown"; size: 14; color: Theme.gold
            anchors.verticalCenter: parent.verticalCenter
        }
        Text {
            text: root.label; color: Theme.title
            font.pixelSize: 12; font.weight: Font.Bold
            anchors.verticalCenter: parent.verticalCenter
        }
    }
}
