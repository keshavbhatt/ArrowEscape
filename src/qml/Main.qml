import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Window
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
    PictureCatalog { id: catalog }

    property bool soundOn: true
    property bool musicOn: true
    property bool colorArrows: true          // Pro feature; on by default, off when free
    property int  hintsLeft: 3                // free hints per board; Pro is unlimited
    property real soundVolume: 0.6
    property real musicVolume: 0.5
    property bool settingsOpen: false
    property bool aboutOpen: false
    property int  screen: 0            // 0 = level select, 1 = play, 2 = collections
    property int  returnScreen: 0      // where the game's back arrow returns to
    property int  highestUnlocked: 1
    property string currentPictureId: ""     // set while playing a Picture Pack board
    property string currentPictureName: ""
    // Pro entitlement comes from the licensing backend (paid OR inside the trial).
    readonly property bool proEffective: LicenseController.pro
    // A few perks (unlimited hints, heart refills) are reserved for *purchased*
    // Pro — the trial does not include them, so they still nudge an upgrade.
    readonly property bool proPaid: LicenseController.hasPaidAccess
    property bool upgradeOpen: false
    property string upgradeFeature: qsTr("ArrowEscape Pro")
    readonly property string donateUrl: "https://www.paypal.me/keshavnrj/9"

    Connections {
        target: LicenseController
        function onUpgradeRequested(feature) {
            win.upgradeFeature = feature;
            win.upgradeOpen = true;
        }
        // React whenever the licence resolves or changes.
        function onStatusChanged()   { win.syncColorArrows(); }
        function onCheckingChanged()  { win.syncColorArrows(); }
    }
    function requestUpgrade(feature) { win.upgradeFeature = feature; win.upgradeOpen = true; }

    // ── Page slide navigation ──
    // Order the screens left→right by "depth" (home < levels < game) so a page
    // always slides in from the correct side no matter its numeric id: the current
    // page sits at x=0, shallower pages park off the left, deeper ones off the right.
    function pageDepth(s) { return s === 0 ? 0 : (s === 2 ? 1 : 2); }
    function pageX(id) {
        if (id === win.screen) return 0;
        return win.pageDepth(id) < win.pageDepth(win.screen) ? -win.width : win.width;
    }

    // Colourful arrows is Pro-only and on by default. Once the licence has
    // definitively resolved to free (trial ended / never Pro), switch it off.
    // Guard on !checking so the async resolution doesn't clear it for a real
    // Pro/trial user during the initial load.
    function syncColorArrows() {
        if (!LicenseController.checking && LicenseController.tier === "free")
            win.colorArrows = false;
    }

    // Persisted progress + preferences.
    Settings {
        category: "ArrowEscape"
        property alias highestUnlocked: win.highestUnlocked
        property alias soundOn: win.soundOn
        property alias musicOn: win.musicOn
        property alias soundVolume: win.soundVolume
        property alias musicVolume: win.musicVolume
        property alias colorArrows: win.colorArrows
        property alias dark: themeProxy.dark
    }
    QtObject { id: themeProxy; property bool dark: false; onDarkChanged: Theme.dark = dark }
    Component.onCompleted: {
        Theme.dark = themeProxy.dark;
        win.syncMusic();
        // Dev hook: force a licence tier (AE_TIER=free|trial|pro, debug builds).
        if (typeof aeTier !== "undefined" && aeTier && aeTier.length && LicenseController.debugSetTier)
            LicenseController.debugSetTier(aeTier);
        win.syncColorArrows();   // apply the free-tier lock to an already-cached status
        // Dev hook: jump straight into a Picture Pack board by id (AE_PIC).
        if (typeof aePic !== "undefined" && aePic && aePic.length) {
            for (var i = 0; i < catalog.packs.length; ++i) {
                var pics = catalog.packs[i].pictures;
                for (var j = 0; j < pics.length; ++j)
                    if (pics[j].id === aePic) {
                        win.currentPictureId = pics[j].id;
                        win.currentPictureName = pics[j].name;
                        game.startPicture(pics[j].cols, pics[j].rows, pics[j].mask.join("\n"), pics[j].seed);
                        win.returnScreen = 2; win.screen = 1;
                        return;
                    }
            }
        }
    }

    readonly property string difficulty:
        game.level <= 10  ? qsTr("Easy")
      : game.level <= 45  ? qsTr("Normal")
      : game.level <= 110 ? qsTr("Hard")
      : game.level <= 200 ? qsTr("Expert")
      :                     qsTr("Master")

    // ── Sound + progress ──────────────────────────────────────────────────────
    SoundEffect { id: sfxWhoosh; source: "qrc:/assets/sounds/whoosh.wav";  volume: win.soundVolume }
    SoundEffect { id: sfxBlock;  source: "qrc:/assets/sounds/blocked.wav"; volume: win.soundVolume * 0.85 }
    SoundEffect { id: sfxWin;    source: "qrc:/assets/sounds/win.wav";     volume: win.soundVolume }

    // Soft looping piano background music. A looping SoundEffect (not MediaPlayer)
    // keeps audio on the lightweight QAudioSink path — no ffmpeg/gstreamer media
    // backend, which keeps the snap small and confinement simple.
    SoundEffect {
        id: music
        source: "qrc:/assets/sounds/music.wav"
        loops: SoundEffect.Infinite
        volume: win.musicVolume
    }
    // Play the loop only while enabled AND the app is in the foreground — pause it
    // when minimized, hidden, or sent to the background; resume when it returns.
    // We check both `visibility` and `active`: some platforms (notably Wayland)
    // don't report a Minimized visibility, but the window does lose `active`.
    function syncMusic() {
        var foreground = win.active
                      && win.visibility !== Window.Minimized
                      && win.visibility !== Window.Hidden;
        if (win.musicOn && foreground)
            music.play();
        else
            music.stop();
    }
    onMusicOnChanged: syncMusic()
    onVisibilityChanged: syncMusic()
    onActiveChanged: syncMusic()
    Connections {
        target: game
        function onEscaped(id) { if (win.soundOn) sfxWhoosh.play(); }
        function onBlocked(id) { if (win.soundOn) sfxBlock.play(); }
        function onWon() {
            if (win.soundOn) sfxWin.play();
            if (game.pictureMode)
                catalog.markCompleted(win.currentPictureId);
            else
                win.highestUnlocked = Math.max(win.highestUnlocked, game.level + 1);
        }
        function onLevelChanged() { win.hintsLeft = 3; }   // fresh free hints per board
    }

    // ── Navigation host: the three screens slide horizontally between each other ──
    Item {
        id: pageHost
        anchors.fill: parent
        clip: true

    // ── Home: Levels + Picture Pack collections ──
    HomeScreen {
        width: pageHost.width; height: pageHost.height
        x: win.pageX(0)
        visible: x > -width && x < width
        Behavior on x { NumberAnimation { duration: 280; easing.type: Easing.OutCubic } }
        catalog: catalog
        pro: win.proEffective
        trial: LicenseController.tier === "trial"
        levelToContinue: win.highestUnlocked
        onOpenLevels: win.screen = 2
        onOpenSettings: win.settingsOpen = true
        onToggleTheme: Theme.dark = !Theme.dark
        onUpgrade: win.requestUpgrade(qsTr("Picture Packs"))
        onPlay: (pic, packId) => {
            win.currentPictureId = pic.id;
            win.currentPictureName = pic.name;
            win.returnScreen = 0;
            game.startPicture(pic.cols, pic.rows, pic.mask.join("\n"), pic.seed);
            win.screen = 1;
        }
    }

    // ── Levels (the number ladder, reached from the Home "Levels" card) ──
    LevelSelect {
        width: pageHost.width; height: pageHost.height
        x: win.pageX(2)
        visible: x > -width && x < width
        Behavior on x { NumberAnimation { duration: 280; easing.type: Easing.OutCubic } }
        highestUnlocked: win.highestUnlocked
        unlockAll: appDebug            // debug builds: every level is playable
        onBack: win.screen = 0
        onPlay: (lvl) => { win.returnScreen = 2; game.startLevel(lvl); win.screen = 1; }
        onOpenSettings: win.settingsOpen = true
        onToggleTheme: Theme.dark = !Theme.dark
    }

    // Debug-only: [ / ] jump between levels while playing.
    Shortcut { enabled: appDebug && win.screen === 1; sequence: "]"
               onActivated: game.nextLevel() }
    Shortcut { enabled: appDebug && win.screen === 1; sequence: "["
               onActivated: if (game.level > 1) game.startLevel(game.level - 1) }

    // ── Game screen ───────────────────────────────────────────────────────────────
    Item {
        id: gameScreen
        width: pageHost.width; height: pageHost.height
        x: win.pageX(1)
        visible: x > -width && x < width
        Behavior on x { NumberAnimation { duration: 280; easing.type: Easing.OutCubic } }

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
                    onClicked: win.screen = win.returnScreen
                }
                Column {
                    anchors.centerIn: parent
                    spacing: 0
                    Text { anchors.horizontalCenter: parent.horizontalCenter
                           text: game.pictureMode ? win.currentPictureName : qsTr("Level %1").arg(game.level)
                           color: Theme.title; font.pixelSize: 24; font.weight: Font.Bold }
                    Text { anchors.horizontalCenter: parent.horizontalCenter
                           text: game.pictureMode ? qsTr("Picture") : win.difficulty
                           color: "#8a63c0"; font.pixelSize: 13; font.weight: Font.DemiBold }
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
                Hearts { count: game.drops; max: game.maxDrops }
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

        // Debug-only level jumper.
        Rectangle {
            id: debugBar
            visible: appDebug
            anchors { top: topbar.bottom; left: parent.left; right: parent.right }
            height: appDebug ? 36 : 0
            color: Qt.rgba(Theme.select.r, Theme.select.g, Theme.select.b, 0.10)
            Row {
                anchors.centerIn: parent
                spacing: 10
                Text { anchors.verticalCenter: parent.verticalCenter
                       text: "DEBUG"; color: Theme.select; font.pixelSize: 12; font.weight: Font.Bold }
                TextField {
                    id: jump
                    width: 130; height: 26
                    padding: 4
                    placeholderText: qsTr("jump to level #")
                    font.pixelSize: 13
                    inputMethodHints: Qt.ImhDigitsOnly
                    validator: IntValidator { bottom: 1; top: 999999 }
                    onAccepted: {
                        const n = parseInt(text);
                        if (!isNaN(n) && n >= 1) { game.startLevel(n); }
                        text = ""; focus = false;
                    }
                }
                Text { anchors.verticalCenter: parent.verticalCenter
                       text: qsTr("[ ] = prev / next"); color: Theme.textDim; font.pixelSize: 11 }
            }
        }

        Board {
            id: boardView
            objectName: "boardView"      // dev hooks (AE_HINT) locate this
            board: game
            colorful: win.colorArrows && win.proEffective
            anchors { top: debugBar.bottom; left: parent.left; right: parent.right; bottom: toolbar.top; margins: 12 }
        }

        RowLayout {
            id: toolbar
            anchors.bottom: parent.bottom
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottomMargin: 22
            spacing: 40
            RoundTool { icon: "restart"; onClicked: game.restart() }
            RoundTool {
                objectName: "hintTool"          // dev hooks (AE_HINTSPAM) locate this
                icon: "bulb"
                badge: win.proPaid ? "∞" : String(win.hintsLeft)
                onClicked: {
                    if (win.proPaid) {
                        boardView.showHint();
                    } else if (win.hintsLeft > 0) {
                        // Charge a hint only when one is actually revealed.
                        if (boardView.showHint())
                            win.hintsLeft -= 1;
                    } else {
                        win.requestUpgrade(qsTr("Unlimited hints"));
                    }
                }
            }
        }
    }
    } // pageHost

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
                   text: game.pictureMode ? qsTr("Picture complete!") : qsTr("Cleared!")
                   color: Theme.title; font.pixelSize: 40; font.weight: Font.Bold }
            Text { anchors.horizontalCenter: parent.horizontalCenter
                   text: game.pictureMode ? qsTr("Added to your collection.") : qsTr("The page is calm again.")
                   color: Theme.text; font.pixelSize: 15 }
            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 12
                PillButton { text: game.pictureMode ? qsTr("Collections") : qsTr("Levels")
                             fill: Qt.rgba(Theme.ink.r, Theme.ink.g, Theme.ink.b, 0.14); ink: Theme.text
                             onClicked: win.screen = win.returnScreen }
                PillButton { visible: !game.pictureMode
                             text: qsTr("Next level"); fill: Theme.good; onClicked: game.nextLevel() }
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
                       text: qsTr("Out of Hearts!"); color: Theme.text; font.pixelSize: 24; font.weight: Font.Bold }
                Hearts { anchors.horizontalCenter: parent.horizontalCenter; count: 3; max: 3 }
                Text { anchors.horizontalCenter: parent.horizontalCenter; width: parent.width
                       horizontalAlignment: Text.AlignHCenter; wrapMode: Text.WordWrap
                       text: win.proPaid ? qsTr("Refill your hearts and keep going.")
                                         : qsTr("Refilling hearts to continue is a Pro feature.")
                       color: Theme.textDim; font.pixelSize: 14 }
                // Refill-to-continue is a purchased-Pro perk; everyone else restarts.
                PillButton {
                    anchors.horizontalCenter: parent.horizontalCenter; width: parent.width
                    text: win.proPaid ? qsTr("Refill hearts") : qsTr("Refill hearts  ·  Pro")
                    fill: win.proPaid ? Theme.good : Theme.gold
                    ink: win.proPaid ? "#ffffff" : Theme.goldInk
                    onClicked: win.proPaid ? game.addLives()
                                           : win.requestUpgrade(qsTr("Heart refills"))
                }
                PillButton { anchors.horizontalCenter: parent.horizontalCenter; width: parent.width
                             text: qsTr("Restart board")
                             fill: Qt.rgba(Theme.ink.r, Theme.ink.g, Theme.ink.b, 0.14)
                             ink: Theme.text; onClicked: game.restart() }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: game.pictureMode ? qsTr("Back to Collections") : qsTr("Back to Levels")
                    color: Theme.textDim; font.pixelSize: 13
                    MouseArea { anchors.fill: parent; anchors.margins: -6; cursorShape: Qt.PointingHandCursor
                                onClicked: { game.restart(); win.screen = win.returnScreen } }
                }
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
            transformOrigin: Item.Center
            scale: win.settingsOpen ? 1.0 : 0.90
            Behavior on scale { NumberAnimation { duration: 240; easing.type: Easing.OutBack } }
            MouseArea { anchors.fill: parent }
            Column {
                id: scol
                anchors.centerIn: parent
                width: parent.width - 44
                spacing: 4
                Item {
                    width: parent.width; height: 44
                    Text { anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter
                           text: qsTr("Settings"); color: Theme.text; font.pixelSize: 22; font.weight: Font.Bold }
                    IconButton { anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                                 icon: "close"; onClicked: win.settingsOpen = false }
                }

                SectionLabel { text: qsTr("Audio") }
                ToggleRow { label: qsTr("Music"); checked: win.musicOn; onToggled: win.musicOn = !win.musicOn }
                SliderRow { label: qsTr("Volume"); inset: 14; on: win.musicOn; value: win.musicVolume
                            onMoved: (v) => win.musicVolume = v }
                ToggleRow { label: qsTr("Sound"); checked: win.soundOn; onToggled: win.soundOn = !win.soundOn }
                SliderRow { label: qsTr("Volume"); inset: 14; on: win.soundOn; value: win.soundVolume
                            onMoved: (v) => win.soundVolume = v }

                Divider {}
                SectionLabel { text: qsTr("Appearance") }
                ToggleRow { label: qsTr("Dark mode"); checked: Theme.dark; onToggled: Theme.dark = !Theme.dark }
                ToggleRow { label: qsTr("Colorful arrows"); checked: win.colorArrows; pro: true
                            locked: !win.proEffective; onToggled: win.colorArrows = !win.colorArrows
                            onLockedTap: win.requestUpgrade(qsTr("Colorful arrows")) }

                Divider {}
                // ── Account / Pro ──
                Item {
                    width: parent.width; height: 26
                    visible: win.proEffective
                    Row {
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 8
                        ProBadge {
                            anchors.verticalCenter: parent.verticalCenter
                            label: LicenseController.tier === "trial" ? qsTr("Pro trial") : qsTr("Pro")
                        }
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            visible: LicenseController.tier === "trial"
                            text: qsTr("%1 days left").arg(LicenseController.evaluationDaysRemaining)
                            color: Theme.textDim; font.pixelSize: 12
                        }
                    }
                }
                Item { width: 1; height: win.proEffective ? 6 : 2 }
                // Upgrade is available to free AND trial users (only hidden once paid).
                PillButton {
                    width: parent.width
                    visible: !LicenseController.hasPaidAccess
                    text: LicenseController.tier === "trial" ? qsTr("Upgrade now") : qsTr("Upgrade to Pro")
                    fill: Theme.good
                    onClicked: { win.settingsOpen = false; win.requestUpgrade(qsTr("ArrowEscape Pro")); }
                }
                // Paid users get an Account entry to the same dialog (id / manage / donate).
                PillButton {
                    width: parent.width
                    visible: LicenseController.hasPaidAccess
                    text: qsTr("Account")
                    fill: Qt.rgba(Theme.title.r, Theme.title.g, Theme.title.b, 0.15); ink: Theme.title
                    onClicked: { win.settingsOpen = false; win.requestUpgrade(qsTr("ArrowEscape Pro")); }
                }
                Item { width: 1; height: 6 }
                PillButton {
                    width: parent.width
                    text: qsTr("About")
                    fill: Qt.rgba(Theme.ink.r, Theme.ink.g, Theme.ink.b, 0.12); ink: Theme.text
                    onClicked: { win.settingsOpen = false; win.aboutOpen = true; }
                }
            }
        }
    }

    // ── About dialog ───────────────────────────────────────────────────────────────
    Rectangle {
        anchors.fill: parent
        color: Qt.rgba(0, 0, 0, 0.35)
        visible: opacity > 0
        opacity: win.aboutOpen ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
        MouseArea { anchors.fill: parent; onClicked: win.aboutOpen = false }
        Rectangle {
            anchors.centerIn: parent
            width: 340; radius: Theme.rlg; color: Theme.surface
            implicitHeight: acol.implicitHeight + 36
            transformOrigin: Item.Center
            scale: win.aboutOpen ? 1.0 : 0.90
            Behavior on scale { NumberAnimation { duration: 240; easing.type: Easing.OutBack } }
            MouseArea { anchors.fill: parent }
            Column {
                id: acol
                anchors.centerIn: parent
                width: parent.width - 44
                spacing: 10

                Item {
                    width: parent.width; height: 22
                    IconButton { anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                                 icon: "close"; iconSize: 18; onClicked: win.aboutOpen = false }
                }
                Image {
                    anchors.horizontalCenter: parent.horizontalCenter
                    source: "qrc:/assets/icons/com.ktechpit.arrowescape.svg"
                    sourceSize: Qt.size(88, 88); width: 88; height: 88; smooth: true
                }
                Text { anchors.horizontalCenter: parent.horizontalCenter
                       text: Qt.application.name; color: Theme.text
                       font.pixelSize: 22; font.weight: Font.Bold }
                Text { anchors.horizontalCenter: parent.horizontalCenter
                       text: qsTr("Version %1").arg(Qt.application.version)
                       color: Theme.textDim; font.pixelSize: 12 }
                Text { width: parent.width; horizontalAlignment: Text.AlignHCenter; wrapMode: Text.WordWrap
                       text: qsTr("A calm arrow-untangling puzzle. Slide every arrow off the board, one clear path at a time.")
                       color: Theme.textDim; font.pixelSize: 13 }

                Rectangle { width: parent.width; height: 1
                            color: Qt.rgba(Theme.ink.r, Theme.ink.g, Theme.ink.b, 0.12) }

                AboutLink { label: qsTr("Website");         sub: "ktechpit.com"
                            url: "https://ktechpit.com/USS/public/product.php?slug=arrowescape" }
                AboutLink { label: qsTr("Report an issue"); sub: "GitHub"
                            url: "https://github.com/keshavbhatt/arrowescape-packaging/issues" }
                AboutLink { label: qsTr("Support the app"); sub: qsTr("Donate")
                            url: "https://www.paypal.me/keshavnrj/9" }
                AboutLink { label: qsTr("More apps");       sub: qsTr("by KTechpit")
                            url: "https://ktechpit.com/USS/public/products.php" }

                Rectangle { width: parent.width; height: 1
                            color: Qt.rgba(Theme.ink.r, Theme.ink.g, Theme.ink.b, 0.12) }

                Text { anchors.horizontalCenter: parent.horizontalCenter
                       text: qsTr("Made by Keshav Bhatt · KTechpit")
                       color: Theme.textDim; font.pixelSize: 12 }
                Text { anchors.horizontalCenter: parent.horizontalCenter
                       text: qsTr("© 2026 KTechpit. All rights reserved.")
                       color: Qt.rgba(Theme.textDim.r, Theme.textDim.g, Theme.textDim.b, 0.8)
                       font.pixelSize: 11 }
            }
        }
    }

    // Keep the persisted `dark` alias in sync with the live Theme.
    Connections { target: Theme; function onDarkChanged() { themeProxy.dark = Theme.dark; } }

    // A soft round toolbar button with an SVG icon.
    component RoundTool: Item {
        property string icon: ""
        property string badge: ""
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
        Rectangle {
            visible: badge.length > 0
            anchors.right: parent.right; anchors.top: parent.top
            width: Math.max(20, bt.implicitWidth + 8); height: 20; radius: 10
            color: Theme.select
            border.width: 2; border.color: Theme.bg
            Text { id: bt; anchors.centerIn: parent; text: badge; color: "white"
                   font.pixelSize: 11; font.weight: Font.Bold }
        }
        MouseArea { id: tma; anchors.fill: parent; hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor; onClicked: parent.clicked() }
    }

    // ── Upgrade to Pro dialog ──────────────────────────────────────────────────────
    Rectangle {
        anchors.fill: parent
        color: Qt.rgba(0, 0, 0, 0.4)
        visible: opacity > 0
        opacity: win.upgradeOpen ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
        MouseArea { anchors.fill: parent; onClicked: win.upgradeOpen = false }
        Rectangle {
            id: ucard
            anchors.centerIn: parent
            width: 330; radius: Theme.rlg; color: Theme.surface
            implicitHeight: ucol.implicitHeight + 40
            transformOrigin: Item.Center
            scale: win.upgradeOpen ? 1.0 : 0.90
            Behavior on scale { NumberAnimation { duration: 240; easing.type: Easing.OutBack } }
            MouseArea { anchors.fill: parent }

            readonly property string tier: LicenseController.tier
            readonly property bool isPro: tier === "pro"

            Column {
                id: ucol
                anchors.centerIn: parent
                width: parent.width - 44
                spacing: 12
                Item {
                    width: parent.width; height: 22
                    IconButton { anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                                 icon: "close"; iconSize: 18; onClicked: win.upgradeOpen = false }
                }
                Rectangle {
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: 66; height: 66; radius: 18
                    color: Qt.rgba(Theme.title.r, Theme.title.g, Theme.title.b, 0.16)
                    Icon { anchors.centerIn: parent
                           name: ucard.isPro ? "crown" : "check"; visible: ucard.isPro
                           size: 34; color: Theme.title }
                    Text { anchors.centerIn: parent; visible: !ucard.isPro
                           text: "★"; font.pixelSize: 34; color: Theme.title }
                }
                Text { anchors.horizontalCenter: parent.horizontalCenter
                       text: qsTr("ArrowEscape Pro"); color: Theme.text
                       font.pixelSize: 22; font.weight: Font.Bold }

                // Current-plan pill.
                ProBadge {
                    anchors.horizontalCenter: parent.horizontalCenter
                    label: ucard.isPro ? qsTr("Pro") : ucard.tier === "trial" ? qsTr("Pro trial") : qsTr("Free")
                }

                Text { width: parent.width; horizontalAlignment: Text.AlignHCenter; wrapMode: Text.WordWrap
                       text: ucard.isPro
                             ? qsTr("You have full access — thank you for supporting ArrowEscape.")
                             : qsTr("Unlock %1 and everything below — one purchase, yours forever.").arg(win.upgradeFeature)
                       color: Theme.textDim; font.pixelSize: 13 }
                Column {
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: 7
                    Repeater {
                        model: [qsTr("Every Picture Pack + all future packs"),
                                qsTr("Colorful arrows"), qsTr("A–Z Letters pack")]
                        delegate: Row {
                            spacing: 8
                            Icon { name: "check"; size: 16; color: Theme.good
                                   anchors.verticalCenter: parent.verticalCenter }
                            Text { text: modelData; color: Theme.text; font.pixelSize: 13
                                   anchors.verticalCenter: parent.verticalCenter }
                        }
                    }
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    visible: ucard.tier === "trial"
                    text: qsTr("Trial — %1 days left").arg(LicenseController.evaluationDaysRemaining)
                    color: Theme.title; font.pixelSize: 12; font.weight: Font.DemiBold
                }

                Divider {}

                // ── Account row: id + copy + refresh ──
                Item {
                    width: parent.width; height: 34
                    Text {
                        id: acctLbl
                        anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter
                        text: qsTr("Account"); color: Theme.textDim; font.pixelSize: 12
                    }
                    Text {
                        anchors.left: acctLbl.right; anchors.leftMargin: 10
                        anchors.right: acctActions.left; anchors.rightMargin: 8
                        anchors.verticalCenter: parent.verticalCenter
                        text: LicenseController.accountId || qsTr("—")
                        color: Theme.text; font.pixelSize: 12; font.family: "monospace"
                        elide: Text.ElideMiddle
                    }
                    Row {
                        id: acctActions
                        anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                        spacing: 2
                        // Copy account id.
                        IconButton {
                            iconSize: 16; icon: copyTimer.done ? "check" : "copy"
                            color: copyTimer.done ? Theme.good : Theme.textDim
                            enabled: LicenseController.accountId.length > 0
                            onClicked: { clipField.selectAll(); clipField.copy();
                                         clipField.deselect(); copyTimer.done = true; copyTimer.restart(); }
                        }
                        // Refresh licence status (spins while checking).
                        IconButton {
                            iconSize: 16; icon: "restart"; color: Theme.textDim
                            enabled: !LicenseController.checking
                            onClicked: LicenseController.refresh()
                            RotationAnimation on rotation {
                                running: LicenseController.checking
                                from: 0; to: 360; duration: 900; loops: Animation.Infinite
                            }
                            onEnabledChanged: if (enabled) rotation = 0
                        }
                    }
                    TextEdit { id: clipField; visible: false; text: LicenseController.accountId }
                    Timer { id: copyTimer; interval: 1400; property bool done: false; onTriggered: done = false }
                }

                // ── Actions: Upgrade (non-Pro) or Donate (Pro), + Manage ──
                PillButton { anchors.horizontalCenter: parent.horizontalCenter; width: parent.width
                             visible: !ucard.isPro
                             text: qsTr("Upgrade"); fill: Theme.good
                             onClicked: { LicenseController.openCheckout(); win.upgradeOpen = false } }
                PillButton { anchors.horizontalCenter: parent.horizontalCenter; width: parent.width
                             visible: ucard.isPro
                             text: qsTr("♥  Donate"); fill: Theme.heart
                             onClicked: Qt.openUrlExternally(win.donateUrl) }
                PillButton { anchors.horizontalCenter: parent.horizontalCenter; width: parent.width
                             text: ucard.isPro ? qsTr("Manage account") : qsTr("Restore / Manage")
                             fill: Qt.rgba(Theme.ink.r, Theme.ink.g, Theme.ink.b, 0.14); ink: Theme.text
                             onClicked: LicenseController.openPortal() }
            }
        }
    }

    // A tappable link row for the About dialog.
    component AboutLink: Item {
        property string label: ""
        property string sub: ""
        property string url: ""
        width: parent ? parent.width : 200
        height: 38
        Rectangle {
            anchors.fill: parent
            radius: Theme.rsm
            color: la.containsMouse ? Qt.rgba(Theme.ink.r, Theme.ink.g, Theme.ink.b, 0.07) : "transparent"
        }
        Text {
            anchors.left: parent.left; anchors.leftMargin: 8; anchors.verticalCenter: parent.verticalCenter
            text: parent.label; color: Theme.text; font.pixelSize: 13; font.weight: Font.DemiBold
        }
        Row {
            anchors.right: parent.right; anchors.rightMargin: 8; anchors.verticalCenter: parent.verticalCenter
            spacing: 6
            Text { text: sub; color: Theme.textDim; font.pixelSize: 12; anchors.verticalCenter: parent.verticalCenter }
            Text { text: "↗"; color: Theme.select; font.pixelSize: 13; anchors.verticalCenter: parent.verticalCenter }
        }
        MouseArea {
            id: la
            anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
            onClicked: Qt.openUrlExternally(parent.url)
        }
    }

    // A labelled volume slider row (dimmed/disabled when its source is off).
    // A small uppercase group heading (Audio / Appearance).
    component SectionLabel: Text {
        topPadding: 8
        color: Theme.textDim
        font.pixelSize: 11; font.weight: Font.DemiBold
        font.capitalization: Font.AllUppercase; font.letterSpacing: 1.2
    }

    // A hairline divider between setting groups.
    component Divider: Item {
        width: parent ? parent.width : 200
        height: 17
        Rectangle {
            anchors.centerIn: parent
            width: parent.width; height: 1
            color: Qt.rgba(Theme.ink.r, Theme.ink.g, Theme.ink.b, 0.12)
        }
    }

    // A volume slider that belongs to a toggle above it: it only appears while
    // that toggle is on, and sits indented beneath it.
    component SliderRow: Item {
        property string label: ""
        property real value: 0.5
        property bool on: true
        property real inset: 0
        signal moved(real v)
        width: parent ? parent.width : 200
        height: 38
        visible: on                        // reveal only when the feature is on
        Text {
            anchors.left: parent.left; anchors.leftMargin: inset
            anchors.verticalCenter: parent.verticalCenter
            text: label; color: Theme.textDim; font.pixelSize: 14
        }
        Slider {
            id: sld
            anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
            width: 150; from: 0; to: 1
            value: parent.value
            onMoved: parent.moved(value)

            background: Rectangle {
                x: sld.leftPadding; y: sld.topPadding + sld.availableHeight / 2 - height / 2
                width: sld.availableWidth; height: 5; radius: 3
                color: Qt.rgba(Theme.ink.r, Theme.ink.g, Theme.ink.b, 0.20)
                Rectangle {
                    width: sld.visualPosition * parent.width; height: parent.height
                    radius: parent.radius; color: Theme.drop
                }
            }
            handle: Rectangle {
                x: sld.leftPadding + sld.visualPosition * (sld.availableWidth - width)
                y: sld.topPadding + sld.availableHeight / 2 - height / 2
                width: 18; height: 18; radius: 9
                color: Theme.surface
                border.width: 1; border.color: Qt.rgba(Theme.ink.r, Theme.ink.g, Theme.ink.b, 0.3)
            }
        }
    }

    // A labelled on/off toggle row. `locked` dims it, shows a PRO badge and
    // blocks toggling (for Pro-only settings).
    component ToggleRow: Item {
        property string label: ""
        property bool checked: false
        property bool locked: false
        property bool pro: false          // marks a Pro feature (gold crown)
        signal toggled
        signal lockedTap
        width: parent ? parent.width : 200
        height: 48
        opacity: locked ? 0.55 : 1
        Text { anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter
               text: label; color: Theme.text; font.pixelSize: 16 }
        Row {
            anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
            spacing: 8
            Icon {
                visible: pro
                anchors.verticalCenter: parent.verticalCenter
                name: "crown"; size: 15; color: Theme.gold
            }
            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: 48; height: 28; radius: 14
                color: checked ? Theme.good : Qt.rgba(Theme.ink.r, Theme.ink.g, Theme.ink.b, 0.22)
                Behavior on color { ColorAnimation { duration: 160 } }
                Rectangle {
                    width: 22; height: 22; radius: 11; color: "white"; y: 3
                    x: checked ? parent.width - width - 3 : 3
                    Behavior on x { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
                }
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                            onClicked: locked ? lockedTap() : toggled() }
            }
        }
    }
}
