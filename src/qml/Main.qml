import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtCore
import QtMultimedia
import ArrowEscape
import "components"

ApplicationWindow {
    id: win
    visible: true
    width: 480
    height: 820
    minimumWidth: 360
    minimumHeight: 560
    title: "ArrowEscape"
    color: Theme.bg

    ArrowBoard { id: game }

    property bool soundOn: true
    property bool settingsOpen: false
    property int  screen: 0            // 0 = level select, 1 = play
    property int  highestUnlocked: 1

    // Persisted progress + preferences.
    Settings {
        category: "ArrowEscape"
        property alias highestUnlocked: win.highestUnlocked
        property alias soundOn: win.soundOn
        property alias dark: themeProxy.dark
    }
    QtObject { id: themeProxy; property bool dark: false; onDarkChanged: Theme.dark = dark }
    Component.onCompleted: Theme.dark = themeProxy.dark

    readonly property string difficulty:
        game.level <= 5  ? qsTr("Easy")
      : game.level <= 15 ? qsTr("Normal")
      : game.level <= 40 ? qsTr("Hard")
      :                    qsTr("Expert")

    // ── Sound + progress ──────────────────────────────────────────────────────
    SoundEffect { id: sfxWhoosh; source: "qrc:/assets/sounds/whoosh.wav";  volume: 0.6 }
    SoundEffect { id: sfxBlock;  source: "qrc:/assets/sounds/blocked.wav"; volume: 0.5 }
    SoundEffect { id: sfxWin;    source: "qrc:/assets/sounds/win.wav";     volume: 0.7 }
    Connections {
        target: game
        function onEscaped(id) { if (win.soundOn) sfxWhoosh.play(); }
        function onBlocked(id) { if (win.soundOn) sfxBlock.play(); }
        function onWon() {
            if (win.soundOn) sfxWin.play();
            win.highestUnlocked = Math.max(win.highestUnlocked, game.level + 1);
        }
    }

    // ── Level-select screen ───────────────────────────────────────────────────────
    LevelSelect {
        anchors.fill: parent
        visible: win.screen === 0
        highestUnlocked: win.highestUnlocked
        onPlay: (lvl) => { game.startLevel(lvl); win.screen = 1; }
        onOpenSettings: win.settingsOpen = true
        onToggleTheme: Theme.dark = !Theme.dark
    }

    // ── Game screen ───────────────────────────────────────────────────────────────
    Item {
        id: gameScreen
        anchors.fill: parent
        visible: win.screen === 1

        Item {
            id: topbar
            anchors { top: parent.top; left: parent.left; right: parent.right }
            height: 108
            Item {
                id: titleRow
                anchors { top: parent.top; left: parent.left; right: parent.right; topMargin: 12 }
                height: 44
                IconButton {
                    anchors.left: parent.left
                    anchors.leftMargin: 8
                    anchors.verticalCenter: parent.verticalCenter
                    icon: "back"
                    onClicked: win.screen = 0
                }
                Column {
                    anchors.centerIn: parent
                    spacing: 0
                    Text { anchors.horizontalCenter: parent.horizontalCenter
                           text: qsTr("Level %1").arg(game.level)
                           color: Theme.title; font.pixelSize: 24; font.weight: Font.Bold }
                    Text { anchors.horizontalCenter: parent.horizontalCenter
                           text: win.difficulty; color: "#8a63c0"; font.pixelSize: 13; font.weight: Font.DemiBold }
                }
                IconButton {
                    anchors.right: gearBtn.left
                    anchors.verticalCenter: parent.verticalCenter
                    icon: Theme.dark ? "sun" : "moon"
                    onClicked: Theme.dark = !Theme.dark
                }
                IconButton {
                    id: gearBtn
                    anchors.right: parent.right
                    anchors.rightMargin: 10
                    anchors.verticalCenter: parent.verticalCenter
                    icon: "gear"
                    onClicked: win.settingsOpen = true
                }
            }
            RowLayout {
                anchors { left: parent.left; right: parent.right; top: titleRow.bottom
                          topMargin: 12; leftMargin: 18; rightMargin: 18 }
                spacing: 14
                Drops { count: game.drops; max: game.maxDrops }
                Item {
                    Layout.fillWidth: true
                    implicitHeight: 18
                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width; height: 12; radius: 6
                        color: Qt.rgba(Theme.ink.r, Theme.ink.g, Theme.ink.b, 0.16)
                        Rectangle {
                            height: parent.height; radius: parent.radius
                            width: Math.max(height, parent.width * game.progress)
                            color: Theme.drop
                            Behavior on width { NumberAnimation { duration: 260; easing.type: Easing.OutCubic } }
                        }
                        Rectangle {
                            width: 20; height: 20; radius: 10; color: Theme.surface
                            border.width: 1; border.color: Qt.rgba(Theme.ink.r, Theme.ink.g, Theme.ink.b, 0.2)
                            anchors.verticalCenter: parent.verticalCenter
                            x: Math.max(0, Math.min(parent.width - width, parent.width * game.progress - width / 2))
                            Behavior on x { NumberAnimation { duration: 260; easing.type: Easing.OutCubic } }
                            Text { anchors.centerIn: parent; text: "★"; font.pixelSize: 11; color: Theme.title }
                        }
                    }
                }
                Text { text: Math.round(game.progress * 100) + "%"
                       color: Theme.textDim; font.pixelSize: 15; font.weight: Font.DemiBold }
            }
        }

        Board {
            id: boardView
            board: game
            anchors { top: topbar.bottom; left: parent.left; right: parent.right; bottom: toolbar.top; margins: 12 }
        }

        RowLayout {
            id: toolbar
            anchors.bottom: parent.bottom
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottomMargin: 22
            spacing: 40
            RoundTool { icon: "restart"; onClicked: game.restart() }
            RoundTool { icon: "bulb";    onClicked: boardView.showHint() }
        }
    }

    // ── Cleared overlay ───────────────────────────────────────────────────────────
    Rectangle {
        anchors.fill: parent
        readonly property bool active: game.status === ArrowBoard.Won && win.screen === 1
        color: Qt.rgba(Theme.bg.r, Theme.bg.g, Theme.bg.b, 0.82)
        visible: opacity > 0
        opacity: active ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 260; easing.type: Easing.OutCubic } }
        MouseArea { anchors.fill: parent }
        Column {
            anchors.centerIn: parent
            spacing: 20
            Text { anchors.horizontalCenter: parent.horizontalCenter
                   text: qsTr("Cleared!"); color: Theme.title; font.pixelSize: 40; font.weight: Font.Bold }
            Text { anchors.horizontalCenter: parent.horizontalCenter
                   text: qsTr("The page is calm again."); color: Theme.text; font.pixelSize: 15 }
            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 12
                PillButton { text: qsTr("Levels")
                             fill: Qt.rgba(Theme.ink.r, Theme.ink.g, Theme.ink.b, 0.14); ink: Theme.text
                             onClicked: win.screen = 0 }
                PillButton { text: qsTr("Next level"); fill: Theme.good; onClicked: game.nextLevel() }
            }
        }
    }

    // ── Out-of-Lives dialog ────────────────────────────────────────────────────────
    Rectangle {
        anchors.fill: parent
        readonly property bool active: game.status === ArrowBoard.Lost && win.screen === 1
        color: Qt.rgba(0, 0, 0, 0.35)
        visible: opacity > 0
        opacity: active ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
        MouseArea { anchors.fill: parent }
        Rectangle {
            anchors.centerIn: parent
            width: 300; radius: Theme.rlg; color: Theme.surface
            implicitHeight: card.implicitHeight + 44
            Column {
                id: card
                anchors.centerIn: parent
                width: parent.width - 48
                spacing: 16
                Text { anchors.horizontalCenter: parent.horizontalCenter
                       text: qsTr("Out of Lives!"); color: Theme.text; font.pixelSize: 24; font.weight: Font.Bold }
                Drops { anchors.horizontalCenter: parent.horizontalCenter; count: 3; max: 3 }
                Text { anchors.horizontalCenter: parent.horizontalCenter; width: parent.width
                       horizontalAlignment: Text.AlignHCenter; wrapMode: Text.WordWrap
                       text: qsTr("Continue for free with 3 more lives."); color: Theme.textDim; font.pixelSize: 14 }
                PillButton { anchors.horizontalCenter: parent.horizontalCenter; width: parent.width
                             text: qsTr("Free Lives"); fill: "#c98a3c"; onClicked: game.addLives() }
                PillButton { anchors.horizontalCenter: parent.horizontalCenter; width: parent.width
                             text: qsTr("Levels"); fill: Qt.rgba(Theme.ink.r, Theme.ink.g, Theme.ink.b, 0.14)
                             ink: Theme.text; onClicked: { game.restart(); win.screen = 0 } }
            }
        }
    }

    // ── Settings dialog ────────────────────────────────────────────────────────────
    Rectangle {
        anchors.fill: parent
        color: Qt.rgba(0, 0, 0, 0.35)
        visible: opacity > 0
        opacity: win.settingsOpen ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
        MouseArea { anchors.fill: parent; onClicked: win.settingsOpen = false }
        Rectangle {
            anchors.centerIn: parent
            width: 320; radius: Theme.rlg; color: Theme.surface
            implicitHeight: scol.implicitHeight + 40
            MouseArea { anchors.fill: parent }
            Column {
                id: scol
                anchors.centerIn: parent
                width: parent.width - 40
                spacing: 6
                Item {
                    width: parent.width; height: 40
                    Text { anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter
                           text: qsTr("Settings"); color: Theme.text; font.pixelSize: 22; font.weight: Font.Bold }
                    IconButton { anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                                 icon: "close"; onClicked: win.settingsOpen = false }
                }
                ToggleRow { label: qsTr("Sound");     checked: win.soundOn; onToggled: win.soundOn = !win.soundOn }
                ToggleRow { label: qsTr("Dark mode"); checked: Theme.dark;  onToggled: Theme.dark = !Theme.dark }
            }
        }
    }

    // Keep the persisted `dark` alias in sync with the live Theme.
    Connections { target: Theme; function onDarkChanged() { themeProxy.dark = Theme.dark; } }

    // A soft round toolbar button with an SVG icon.
    component RoundTool: Item {
        property string icon: ""
        signal clicked
        implicitWidth: 62; implicitHeight: 62
        Rectangle {
            anchors.fill: parent
            radius: width / 2; color: Theme.surface
            border.width: 1; border.color: Qt.rgba(Theme.ink.r, Theme.ink.g, Theme.ink.b, 0.18)
            scale: tma.pressed ? 0.94 : 1.0
            Behavior on scale { NumberAnimation { duration: 90 } }
            Icon { anchors.centerIn: parent; name: parent.parent.icon; size: 26; color: Theme.ink }
        }
        MouseArea { id: tma; anchors.fill: parent; hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor; onClicked: parent.clicked() }
    }

    // A labelled on/off toggle row.
    component ToggleRow: Item {
        property string label: ""
        property bool checked: false
        signal toggled
        width: parent ? parent.width : 200
        height: 48
        Text { anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter
               text: label; color: Theme.text; font.pixelSize: 16 }
        Rectangle {
            anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
            width: 48; height: 28; radius: 14
            color: checked ? Theme.good : Qt.rgba(Theme.ink.r, Theme.ink.g, Theme.ink.b, 0.22)
            Behavior on color { ColorAnimation { duration: 160 } }
            Rectangle {
                width: 22; height: 22; radius: 11; color: "white"; y: 3
                x: parent.parent.checked ? parent.width - width - 3 : 3
                Behavior on x { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
            }
            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                        onClicked: parent.parent.toggled() }
        }
    }
}
