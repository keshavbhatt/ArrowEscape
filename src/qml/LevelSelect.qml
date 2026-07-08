import QtQuick
import QtQuick.Controls
import ArrowEscape
import "components"

// The level-select screen: a scrollable grid of level tiles. Completed levels
// show a check, the next level to play is highlighted, and locked levels show a
// padlock. There are 500+ levels, so the grid is virtualized.
Item {
    id: root

    property int highestUnlocked: 1
    property int totalLevels: 500
    signal play(int level)
    signal openSettings()
    signal toggleTheme()

    // ── Header ──
    Item {
        id: header
        anchors { top: parent.top; left: parent.left; right: parent.right }
        height: 64
        Text {
            anchors.centerIn: parent
            text: qsTr("Levels")
            color: Theme.title
            font.pixelSize: 24
            font.weight: Font.Bold
        }
        IconButton {
            anchors.right: setBtn.left
            anchors.verticalCenter: parent.verticalCenter
            icon: Theme.dark ? "sun" : "moon"
            onClicked: root.toggleTheme()
        }
        IconButton {
            id: setBtn
            anchors.right: parent.right
            anchors.rightMargin: 10
            anchors.verticalCenter: parent.verticalCenter
            icon: "gear"
            onClicked: root.openSettings()
        }
        Rectangle {
            anchors.bottom: parent.bottom
            width: parent.width; height: 1
            color: Qt.rgba(Theme.ink.r, Theme.ink.g, Theme.ink.b, 0.10)
        }
    }

    GridView {
        id: grid
        anchors { top: header.bottom; left: parent.left; right: parent.right; bottom: parent.bottom
                  topMargin: 8; leftMargin: 16; rightMargin: 16; bottomMargin: 8 }
        clip: true
        // Reserve room on the right for the scrollbar so it never overlaps a tile.
        readonly property int sbw: 14
        readonly property real avail: width - sbw
        readonly property int cols: Math.max(3, Math.floor(avail / 92))
        cellWidth: avail / cols
        cellHeight: cellWidth
        model: root.totalLevels
        boundsBehavior: Flickable.StopAtBounds
        ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

        // Start scrolled so the current level is visible.
        Component.onCompleted: positionViewAtIndex(Math.max(0, root.highestUnlocked - 1), GridView.Center)

        delegate: Item {
            required property int index
            readonly property int lvl: index + 1
            readonly property bool completed: lvl < root.highestUnlocked
            readonly property bool current:   lvl === root.highestUnlocked
            readonly property bool unlocked:  lvl <= root.highestUnlocked
            width: grid.cellWidth
            height: grid.cellHeight

            Rectangle {
                anchors.centerIn: parent
                width: parent.width - 12
                height: parent.height - 12
                radius: 16
                color: completed ? Qt.rgba(Theme.good.r, Theme.good.g, Theme.good.b, 0.16)
                     : current   ? Theme.surface
                     :             Qt.rgba(Theme.ink.r, Theme.ink.g, Theme.ink.b, 0.05)
                border.width: current ? 2 : 1
                border.color: current ? Theme.select
                            : completed ? Qt.rgba(Theme.good.r, Theme.good.g, Theme.good.b, 0.5)
                            : Qt.rgba(Theme.ink.r, Theme.ink.g, Theme.ink.b, 0.12)
                scale: tap.pressed && unlocked ? 0.93 : 1.0
                Behavior on scale { NumberAnimation { duration: 90 } }

                Column {
                    anchors.centerIn: parent
                    spacing: 3
                    visible: unlocked
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: lvl
                        color: current ? Theme.title : Theme.text
                        font.pixelSize: 22
                        font.weight: Font.Bold
                    }
                    Icon {
                        anchors.horizontalCenter: parent.horizontalCenter
                        visible: completed
                        name: "check"; size: 15; color: Theme.good
                    }
                }
                Icon {
                    anchors.centerIn: parent
                    visible: !unlocked
                    name: "lock"; size: 22
                    color: Qt.rgba(Theme.ink.r, Theme.ink.g, Theme.ink.b, 0.35)
                }

                MouseArea {
                    id: tap
                    anchors.fill: parent
                    enabled: unlocked
                    cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                    onClicked: root.play(lvl)
                }
            }
        }
    }
}
