import QtQuick
import QtQuick.Controls
import ArrowEscape
import "components"

// The landing screen — presents BOTH modes: a "Levels" card (the endless
// number-ladder mode) followed by the Picture Pack collections. Nothing is
// hidden behind a button.
Item {
    id: root

    property var catalog            // PictureCatalog
    property bool pro: false
    property bool trial: false
    property int  levelToContinue: 1
    signal play(var pic, string packId)
    signal openLevels()
    signal openSettings()
    signal toggleTheme()
    signal upgrade()

    Item {
        id: header
        anchors { top: parent.top; left: parent.left; right: parent.right }
        height: 64
        Text {
            anchors.centerIn: parent
            text: "ArrowEscape"; color: Theme.title
            font.pixelSize: 24; font.weight: Font.Bold
        }
        ProBadge {
            anchors.left: parent.left; anchors.leftMargin: 12
            anchors.verticalCenter: parent.verticalCenter
            visible: root.pro
            label: root.trial ? qsTr("Pro trial") : qsTr("Pro")
        }
        IconButton {
            anchors.right: setBtn.left
            anchors.verticalCenter: parent.verticalCenter
            icon: Theme.dark ? "sun" : "moon"; onClicked: root.toggleTheme()
        }
        IconButton {
            id: setBtn
            anchors.right: parent.right; anchors.rightMargin: 10
            anchors.verticalCenter: parent.verticalCenter
            icon: "gear"; onClicked: root.openSettings()
        }
        Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 1
                    color: Qt.rgba(Theme.ink.r, Theme.ink.g, Theme.ink.b, 0.10) }
    }

    Flickable {
        id: flick
        anchors { top: header.bottom; left: parent.left; right: parent.right; bottom: parent.bottom }
        contentWidth: width
        contentHeight: col.implicitHeight + 28
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

        Column {
            id: col
            x: 16; y: 14
            width: flick.width - 32
            spacing: 20

            // ── Levels card (primary "play" action) ──
            Rectangle {
                width: parent.width
                height: 96
                radius: 20
                color: Qt.rgba(Theme.select.r, Theme.select.g, Theme.select.b, 0.14)
                border.width: 1
                border.color: Qt.rgba(Theme.select.r, Theme.select.g, Theme.select.b, 0.4)
                scale: lma.pressed ? 0.98 : 1.0
                Behavior on scale { NumberAnimation { duration: 90 } }

                Rectangle {
                    id: lvlIcon
                    anchors.left: parent.left; anchors.leftMargin: 18
                    anchors.verticalCenter: parent.verticalCenter
                    width: 60; height: 60; radius: 16; color: Theme.select
                    Icon { anchors.centerIn: parent; name: "album"; size: 30; color: "#ffffff" }
                }
                Column {
                    anchors.left: lvlIcon.right; anchors.leftMargin: 16
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 3
                    Text { text: qsTr("Levels"); color: Theme.text; font.pixelSize: 20; font.weight: Font.Bold }
                    Text { text: qsTr("Continue — Level %1").arg(root.levelToContinue)
                           color: Theme.textDim; font.pixelSize: 14 }
                }
                Text { anchors.right: parent.right; anchors.rightMargin: 18
                       anchors.verticalCenter: parent.verticalCenter
                       text: "›"; color: Theme.select; font.pixelSize: 30 }
                MouseArea { id: lma; anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                            onClicked: root.openLevels() }
            }

            Text { text: qsTr("Collections"); color: Theme.title
                   font.pixelSize: 18; font.weight: Font.Bold }

            // ── Picture packs ──
            Repeater {
                model: root.catalog ? root.catalog.packs : []
                delegate: Column {
                    id: packCol
                    required property var modelData
                    readonly property bool locked: modelData.pro === true && !root.pro
                    width: col.width
                    spacing: 10

                    Row {
                        spacing: 7
                        Text { text: packCol.modelData.name; color: Theme.text
                               font.pixelSize: 16; font.weight: Font.Bold
                               anchors.verticalCenter: parent.verticalCenter }
                        // A gold crown marks a Pro pack in every state (locked, or
                        // playable via trial/purchase) so its value is always clear.
                        Icon {
                            visible: packCol.modelData.pro === true
                            anchors.verticalCenter: parent.verticalCenter
                            name: "crown"; size: 16; color: Theme.gold
                        }
                    }

                    Flow {
                        width: parent.width
                        spacing: 12
                        Repeater {
                            model: packCol.modelData.pictures
                            delegate: Item {
                                id: tile
                                required property var modelData
                                readonly property bool done:
                                    root.catalog && root.catalog.completed.indexOf(modelData.id) >= 0
                                readonly property bool locked: packCol.locked
                                width: 92; height: 104

                                Rectangle {
                                    anchors.fill: parent; radius: 16
                                    color: tile.done ? Qt.rgba(Theme.good.r, Theme.good.g, Theme.good.b, 0.14)
                                                     : Qt.rgba(Theme.ink.r, Theme.ink.g, Theme.ink.b, 0.05)
                                    border.width: 1
                                    border.color: tile.done ? Qt.rgba(Theme.good.r, Theme.good.g, Theme.good.b, 0.45)
                                                            : Qt.rgba(Theme.ink.r, Theme.ink.g, Theme.ink.b, 0.12)
                                    scale: ma.pressed && !tile.locked ? 0.93 : 1.0
                                    Behavior on scale { NumberAnimation { duration: 90 } }

                                    PicturePreview {
                                        anchors.centerIn: parent; anchors.verticalCenterOffset: -6
                                        width: 62; height: 62; mask: tile.modelData.mask
                                        opacity: tile.locked ? 0.25 : 1
                                        color: tile.done ? Theme.ink
                                             : Qt.rgba(Theme.ink.r, Theme.ink.g, Theme.ink.b, 0.30)
                                    }
                                    Text {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        anchors.bottom: parent.bottom; anchors.bottomMargin: 8
                                        text: tile.modelData.name; color: Theme.textDim; font.pixelSize: 11
                                        elide: Text.ElideRight; width: parent.width - 12
                                        horizontalAlignment: Text.AlignHCenter
                                    }
                                    Icon { anchors.right: parent.right; anchors.top: parent.top; anchors.margins: 6
                                           visible: tile.done; name: "check"; size: 15; color: Theme.good }
                                    Icon { anchors.centerIn: parent; anchors.verticalCenterOffset: -6
                                           visible: tile.locked; name: "lock"; size: 22
                                           color: Qt.rgba(Theme.ink.r, Theme.ink.g, Theme.ink.b, 0.4) }
                                }
                                MouseArea {
                                    id: ma; anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: tile.locked ? root.upgrade()
                                                           : root.play(tile.modelData, packCol.modelData.id)
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
