import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Effects
import Quickshell
import Quickshell.Io

FloatingWindow {
    id: root

    // Setting title so Hyprland can match title:^(music_win)$
    title: "music_win"

    // Geometry
    implicitWidth: 700
    implicitHeight: 620

    // Make the base window transparent so our rounded corners show properly
    color: "transparent"

    // Theme Colors
    readonly property color base: "#1e1e2e"
    readonly property color surface0: "#313244"
    readonly property color surface1: "#45475a"
    readonly property color surface2: "#585b70"
    readonly property color overlay0: "#6c7086"
    readonly property color overlay1: "#7f849c"
    readonly property color overlay2: "#9399b2"
    readonly property color text: "#cdd6f4"
    readonly property color subtext0: "#a6adc8"
    readonly property color subtext1: "#bac2de"
    readonly property color blue: "#89b4fa"
    readonly property color sapphire: "#74c7ec"
    readonly property color lavender: "#b4befe"
    readonly property color mauve: "#cba6f7"
    readonly property color pink: "#f5c2e7"
    readonly property color red: "#f38ba8"
    readonly property color yellow: "#f9e2af"

    // Data State Properties
    property var musicData: {
        "title": "Loading...", "artist": "", "status": "Stopped", "percent": 0,
        "lengthStr": "00:00", "positionStr": "00:00", "timeStr": "--:-- / --:--",
        "source": "Offline", "playerName": "", "blur": "", "grad": "",
        "textColor": "#cdd6f4", "deviceIcon": "󰓃", "deviceName": "Speaker",
        "artUrl": ""
    }

    property var eqData: {
        "b1": 0, "b2": 0, "b3": 0, "b4": 0, "b5": 0,
        "b6": 0, "b7": 0, "b8": 0, "b9": 0, "b10": 0,
        "preset": "Flat", "pending": false
    }

    // Accumulators for Process standard output
    property string accumulatedMusicOut: ""
    property string accumulatedEqOut: ""

    // UI State for debouncing the slider and play button
    property bool userIsSeeking: false
    property bool userToggledPlay: false

    // Decoupled Global Animation States
    property real catppuccinFlowOffset: 0
    NumberAnimation on catppuccinFlowOffset {
        from: 0; to: 1.0
        duration: 3000
        loops: Animation.Infinite
        running: true
    }

    property real globalOrbitAngle: 0
    NumberAnimation on globalOrbitAngle {
        from: 0; to: Math.PI * 2
        duration: 90000
        loops: Animation.Infinite
        running: true
    }

    // Parse the CSS gradient from the bash script into QML hex colors
    property var borderColors: {
        var defaultColors = [root.mauve, root.blue, root.red, root.mauve];
        if (!root.musicData || !root.musicData.grad) return defaultColors;
        
        var hexRegex = /#[0-9a-fA-F]{6}/g;
        var matches = root.musicData.grad.match(hexRegex);
        
        if (matches && matches.length >= 3) {
            return [matches[0], matches[1], matches[2], matches[0]]; // Wrap around for looping
        }
        return defaultColors;
    }

    // --- UTILITIES & OPTIMISTIC UPDATES ---
    function execCmd(cmdStr) {
        var safeCmd = cmdStr.replace(/`/g, "\\`");
        var p = Qt.createQmlObject(`
            import Quickshell.Io
            Process {
                command: ["bash", "-c", \`${safeCmd}\`]
                running: true
                onExited: (exitCode) => destroy()
            }
        `, root);
    }

    function applyPresetOptimistically(presetName) {
        var presets = {
            "Flat": [0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
            "Bass": [5, 7, 5, 2, 1, 0, 0, 0, 1, 2],
            "Treble": [-2, -1, 0, 1, 2, 3, 4, 5, 6, 6],
            "Vocal": [-2, -1, 1, 3, 5, 5, 4, 2, 1, 0],
            "Pop": [2, 4, 2, 0, 1, 2, 4, 2, 1, 2],
            "Rock": [5, 4, 2, -1, -2, -1, 2, 4, 5, 6],
            "Jazz": [3, 3, 1, 1, 1, 1, 2, 1, 2, 3],
            "Classic": [0, 1, 2, 2, 2, 2, 1, 2, 3, 4]
        };
        if (presets[presetName]) {
            var temp = Object.assign({}, root.eqData);
            for (var i = 0; i < 10; i++) {
                temp["b" + (i + 1)] = presets[presetName][i];
            }
            temp.preset = presetName;
            temp.pending = false; 
            root.eqData = temp; 
            execCmd(`$HOME/.config/hypr/scripts/quickshell/music/equalizer.sh preset ${presetName}`);
        }
    }

    // --- DATA POLLING ---
    Timer {
        id: seekDebounceTimer
        interval: 2500 
        onTriggered: root.userIsSeeking = false
    }

    Timer {
        id: playDebounceTimer
        interval: 1500 // Gives the backend 1.5 seconds to catch up before accepting polled status
        onTriggered: root.userToggledPlay = false
    }

    Timer {
        interval: 500
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            if (!musicProc.running) musicProc.running = true;
            if (!eqProc.running) eqProc.running = true;
        }
    }

    Process {
        id: musicProc
        running: true
        command: ["bash", "-c", "$HOME/.config/hypr/scripts/quickshell/music/music_info.sh"]
        stdout: StdioCollector {
            onStreamFinished: {
                if (this.text) {
                    var outStr = this.text.trim();
                    if (outStr.length > 0) {
                        try { 
                            var newData = JSON.parse(outStr); 
                            // Ignore polled status if we just toggled it
                            if (root.userToggledPlay) {
                                newData.status = root.musicData.status; 
                            }
                            root.musicData = newData; 
                        } catch(e) {}
                    }
                }
            }
        }
    }

    Process {
        id: eqProc
        running: true
        command: ["bash", "-c", "$HOME/.config/hypr/scripts/quickshell/music/equalizer.sh get"]
        stdout: StdioCollector {
            onStreamFinished: {
                if (this.text) {
                    var outStr = this.text.trim();
                    if (outStr.length > 0) {
                        try { root.eqData = JSON.parse(outStr); } catch(e) {}
                    }
                }
            }
        }
    }

    // --- UI LAYOUT ---
    Item {
        anchors.fill: parent

        // OUTER ANIMATED BORDER WITH PROPER CLIPPING
        Item {
            anchors.fill: parent

            Rectangle {
                id: maskRectOuter
                anchors.fill: parent
                radius: 15 // Matches inner 12px + 3px margins
                visible: false
                layer.enabled: true
            }

            MultiEffect {
                source: gradContainer
                anchors.fill: parent
                maskEnabled: true
                maskSource: maskRectOuter
            }

            Item {
                id: gradContainer
                anchors.fill: parent
                visible: false // Let MultiEffect render it

                Rectangle {
                    width: parent.width * 2
                    height: parent.height * 2
                    anchors.centerIn: parent
                    rotation: gradAnim.angle
                    gradient: Gradient {
                        GradientStop { 
                            position: 0.0; color: root.borderColors[0] 
                            Behavior on color { ColorAnimation { duration: 800; easing.type: Easing.InOutQuad } }
                        }
                        GradientStop { 
                            position: 0.33; color: root.borderColors[1] 
                            Behavior on color { ColorAnimation { duration: 800; easing.type: Easing.InOutQuad } }
                        }
                        GradientStop { 
                            position: 0.66; color: root.borderColors[2] 
                            Behavior on color { ColorAnimation { duration: 800; easing.type: Easing.InOutQuad } }
                        }
                        GradientStop { 
                            position: 1.0; color: root.borderColors[3] 
                            Behavior on color { ColorAnimation { duration: 800; easing.type: Easing.InOutQuad } }
                        }
                    }
                    NumberAnimation on rotation {
                        id: gradAnim
                        from: 0; to: 360; duration: 5000
                        loops: Animation.Infinite
                        running: true
                    }
                }
            }
        }

        // INNER WINDOW BOX
        Rectangle {
            anchors.fill: parent
            anchors.margins: 3
            color: root.base
            radius: 12
            clip: true

            // LAYER 1: Background Blur (Smooth fade-in)
            Image {
                anchors.fill: parent
                source: root.musicData.blur ? "file://" + root.musicData.blur : ""
                fillMode: Image.PreserveAspectCrop
                opacity: status === Image.Ready ? 0.6 : 0.0
                Behavior on opacity { NumberAnimation { duration: 800; easing.type: Easing.InOutQuad } }
            }

            // LAYER 1.5: Flowing Orbits
            Rectangle {
                width: parent.width * 0.8; height: width; radius: width / 2
                x: (parent.width / 2 - width / 2) + Math.cos(root.globalOrbitAngle * 2) * 150
                y: (parent.height / 2 - height / 2) + Math.sin(root.globalOrbitAngle * 2) * 100
                opacity: root.musicData.status === "Playing" ? 0.12 : 0.04
                color: root.musicData.status === "Playing" ? root.mauve : root.surface2
                Behavior on color { ColorAnimation { duration: 1000 } }
                Behavior on opacity { NumberAnimation { duration: 1000 } }
            }
            
            Rectangle {
                width: parent.width * 0.9; height: width; radius: width / 2
                x: (parent.width / 2 - width / 2) + Math.sin(root.globalOrbitAngle * 1.5) * -150
                y: (parent.height / 2 - height / 2) + Math.cos(root.globalOrbitAngle * 1.5) * -100
                opacity: root.musicData.status === "Playing" ? 0.08 : 0.02
                color: root.musicData.status === "Playing" ? root.blue : root.surface1
                Behavior on color { ColorAnimation { duration: 1000 } }
                Behavior on opacity { NumberAnimation { duration: 1000 } }
            }

            // LAYER 2: UI Content
            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 20
                spacing: 0

                // ==========================================
                // TOP INFO SECTION
                // ==========================================
                RowLayout {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 220
                    spacing: 25

                    // Cover Art
                    Rectangle {
                        Layout.preferredWidth: 220
                        Layout.preferredHeight: 220
                        Layout.alignment: Qt.AlignVCenter
                        radius: 110
                        color: root.surface1
                        border.width: 4
                        border.color: root.musicData.status === "Playing" ? root.mauve : root.overlay0
                        
                        Behavior on border.color { ColorAnimation { duration: 500 } }

                        // Glow Effect surrounding the thumbnail
                        Rectangle {
                            z: -1
                            anchors.centerIn: parent
                            width: parent.width + 20
                            height: parent.height + 20
                            radius: width / 2
                            color: root.mauve
                            opacity: root.musicData.status === "Playing" ? 0.5 : 0.0
                            Behavior on opacity { NumberAnimation { duration: 500 } }
                            layer.enabled: true
                            layer.effect: MultiEffect {
                                blurEnabled: true
                                blurMax: 32
                                blur: 1.0
                            }
                        }

                        Item {
                            anchors.fill: parent
                            anchors.margins: 4
                            Image {
                                id: artImg
                                anchors.fill: parent
                                source: root.musicData.artUrl ? "file://" + root.musicData.artUrl : ""
                                fillMode: Image.PreserveAspectCrop
                                visible: false 
                            }
                            Rectangle {
                                id: maskRect
                                anchors.fill: parent
                                radius: width / 2
                                visible: false
                                layer.enabled: true 
                            }
                            MultiEffect {
                                anchors.fill: parent
                                source: artImg
                                maskEnabled: true
                                maskSource: maskRect
                                opacity: artImg.status === Image.Ready ? 1.0 : 0.0
                                Behavior on opacity { NumberAnimation { duration: 800 } }
                            }
                            Rectangle {
                                width: 40; height: 40
                                radius: 20; color: "#000000"
                                opacity: 0.8; anchors.centerIn: parent
                            }
                        }
                        
                        NumberAnimation on rotation {
                            from: 0; to: 360; duration: 4000
                            loops: Animation.Infinite
                            running: true
                            paused: root.musicData.status !== "Playing"
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.alignment: Qt.AlignVCenter
                        spacing: 15

                        ColumnLayout {
                            spacing: 6
                            Text {
                                text: root.musicData.title
                                color: root.musicData.textColor || root.text
                                font.family: "JetBrains Mono"
                                font.pixelSize: 20
                                font.bold: true
                                elide: Text.ElideRight
                                maximumLineCount: 2
                                wrapMode: Text.Wrap
                                Layout.fillWidth: true
                                Behavior on color { ColorAnimation { duration: 600 } }
                            }
                            Text {
                                text: root.musicData.artist ? "BY " + root.musicData.artist : ""
                                color: root.pink
                                font.family: "JetBrains Mono"
                                font.pixelSize: 14
                                font.bold: true
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                            }
                            RowLayout {
                                spacing: 10
                                Rectangle {
                                    color: "#1AFFFFFF"
                                    radius: 4
                                    Layout.preferredHeight: 24
                                    Layout.preferredWidth: pillContent.width + 20
                                    RowLayout {
                                        id: pillContent
                                        anchors.centerIn: parent
                                        spacing: 6
                                        Text { text: root.musicData.deviceIcon || "󰓃"; color: root.mauve; font.family: "Iosevka Nerd Font"; font.pixelSize: 14 }
                                        Text { text: root.musicData.deviceName || "Speaker"; color: root.overlay2; font.family: "JetBrains Mono"; font.pixelSize: 12; font.bold: true }
                                    }
                                }
                                Text {
                                    text: "VIA " + (root.musicData.source || "Offline")
                                    color: root.yellow
                                    font.family: "JetBrains Mono"
                                    font.pixelSize: 12
                                    font.bold: true
                                    font.italic: true
                                }
                            }
                        }

                        // Progress Area
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 5

                            Slider {
                                id: progBar
                                Layout.fillWidth: true
                                Layout.preferredHeight: 20 
                                from: 0; to: 100

                                Connections {
                                    target: root
                                    function onMusicDataChanged() {
                                        if (!progBar.pressed && !root.userIsSeeking) {
                                            if (root.musicData && root.musicData.percent !== undefined) {
                                                var p = Number(root.musicData.percent);
                                                if (!isNaN(p)) progBar.value = p;
                                            }
                                        }
                                    }
                                }

                                Behavior on value {
                                    enabled: !progBar.pressed && !root.userIsSeeking
                                    NumberAnimation { duration: 400; easing.type: Easing.OutSine }
                                }

                                onPressedChanged: {
                                    if (pressed) {
                                        root.userIsSeeking = true;
                                        seekDebounceTimer.stop();
                                    } else {
                                        var temp = Object.assign({}, root.musicData);
                                        temp.percent = value;
                                        root.musicData = temp;

                                        var safePlayer = root.musicData.playerName ? root.musicData.playerName : "";
                                        root.execCmd(`$HOME/.config/hypr/scripts/quickshell/music/player_control.sh seek ${value.toFixed(2)} ${root.musicData.length} "${safePlayer}"`);
                                        
                                        seekDebounceTimer.restart();
                                    }
                                }

                                background: Rectangle {
                                    x: progBar.leftPadding
                                    y: progBar.topPadding + (progBar.availableHeight - height) / 2
                                    implicitWidth: 200 
                                    implicitHeight: 12
                                    width: progBar.availableWidth
                                    height: 12
                                    radius: 6
                                    color: "#9911111B"

                                    // FIX 1: The clipping container tightly binds to the handle's exact visual center
                                    Item {
                                        width: progBar.handle.x - progBar.background.x + (progBar.handle.width / 2)
                                        height: parent.height
                                        clip: true // Sharp cut hidden safely underneath the solid handle

                                        // FIX 2: The fill itself remains full-width so its left-side rounded corners never deform
                                        Item {
                                            width: progBar.availableWidth
                                            height: parent.height
                                            
                                            layer.enabled: true
                                            layer.effect: MultiEffect {
                                                maskEnabled: true
                                                maskSource: sliderFillMask
                                            }

                                            Rectangle {
                                                id: sliderFillMask
                                                width: parent.width
                                                height: parent.height
                                                radius: 6
                                                visible: false
                                                layer.enabled: true 
                                            }

                                            Rectangle {
                                                width: 2000
                                                height: parent.height
                                                x: -(root.catppuccinFlowOffset * 1000) 
                                                gradient: Gradient {
                                                    orientation: Gradient.Horizontal
                                                    GradientStop { position: 0.0; color: root.mauve }
                                                    GradientStop { position: 0.166; color: root.blue }
                                                    GradientStop { position: 0.333; color: root.pink }
                                                    GradientStop { position: 0.5; color: root.mauve }
                                                    GradientStop { position: 0.666; color: root.blue }
                                                    GradientStop { position: 0.833; color: root.pink }
                                                    GradientStop { position: 1.0; color: root.mauve }
                                                }
                                            }
                                        }
                                    }
                                }

                                handle: Rectangle {
                                    // FIX 3: Using visualPosition ensures the handle doesn't ghost or separate during animations
                                    x: progBar.leftPadding + progBar.visualPosition * (progBar.availableWidth - width)
                                    y: progBar.topPadding + (progBar.availableHeight - height) / 2
                                    implicitWidth: 14 
                                    implicitHeight: 14
                                    width: 16; height: 16
                                    radius: 7; color: root.text
                                    scale: progBar.pressed ? 1.4 : 1.0
                                    Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutBack } }
                                }
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                Text { text: root.musicData.positionStr || "00:00"; color: root.overlay2; font.family: "JetBrains Mono"; font.bold: true; font.pixelSize: 13 }
                                Item { Layout.fillWidth: true }
                                Text { text: root.musicData.lengthStr || "00:00"; color: root.overlay2; font.family: "JetBrains Mono"; font.bold: true; font.pixelSize: 13 }
                            }
                        }

                        // Media Controls
                        RowLayout {
                            Layout.alignment: Qt.AlignHCenter
                            spacing: 30
                            MouseArea {
                                width: 30; height: 30
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.execCmd("playerctl previous")
                                Text { anchors.centerIn: parent; text: ""; color: parent.pressed ? root.text : root.overlay2; font.family: "Iosevka Nerd Font"; font.pixelSize: 24 }
                            }
                            MouseArea {
                                width: 50; height: 50
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    // Trigger debounce lock
                                    root.userToggledPlay = true;
                                    playDebounceTimer.restart();

                                    // Optimistic state update for instant visual feedback
                                    var temp = Object.assign({}, root.musicData);
                                    temp.status = (temp.status === "Playing" ? "Paused" : "Playing");
                                    root.musicData = temp;
                                    root.execCmd("playerctl play-pause");
                                }
                                Text { anchors.centerIn: parent; text: root.musicData.status === "Playing" ? "" : ""; color: parent.pressed ? root.pink : root.mauve; font.family: "Iosevka Nerd Font"; font.pixelSize: 42 }
                            }
                            MouseArea {
                                width: 30; height: 30
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.execCmd("playerctl next")
                                Text { anchors.centerIn: parent; text: ""; color: parent.pressed ? root.text : root.overlay2; font.family: "Iosevka Nerd Font"; font.pixelSize: 24 }
                            }
                        }
                    }
                }

                // ==========================================
                // SEPARATOR
                // ==========================================
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 2
                    Layout.topMargin: 20
                    Layout.bottomMargin: 20
                    color: "#1AFFFFFF"
                    radius: 1
                }

                // ==========================================
                // EQUALIZER
                // ==========================================
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 15

                    // Header Row
                    RowLayout {
                        Layout.fillWidth: true
                        Text { text: "Equalizer"; color: root.mauve; font.family: "JetBrains Mono"; font.pixelSize: 16; font.bold: true; Layout.fillWidth: true }
                        
                        // Apply Button
                        Rectangle {
                            Layout.preferredHeight: 22
                            Layout.preferredWidth: applyTxt.width + 20
                            radius: 6
                            color: root.eqData.pending ? "#1AF38BA8" : "transparent"
                            border.color: root.eqData.pending ? root.red : "transparent"
                            Text {
                                id: applyTxt
                                anchors.centerIn: parent
                                text: root.eqData.pending ? "Apply" : "Saved"
                                color: root.eqData.pending ? root.red : root.overlay1
                                font.family: "JetBrains Mono"
                                font.pixelSize: 11
                                font.bold: true
                            }
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    var temp = Object.assign({}, root.eqData);
                                    temp.pending = false;
                                    root.eqData = temp;
                                    root.execCmd("$HOME/.config/hypr/scripts/quickshell/music/equalizer.sh apply");
                                }
                            }
                        }
                        Text { text: root.eqData.preset || "Flat"; color: root.subtext0; font.family: "JetBrains Mono"; font.pixelSize: 14; font.bold: true; Layout.leftMargin: 15 }
                    }

                    // Eq Sliders (10 bands)
                    Row {
                        id: eqSliderRow
                        Layout.fillWidth: true
                        Layout.preferredHeight: 180

                        Repeater {
                            model: [
                                {"idx": 1, "lbl": "31"}, {"idx": 2, "lbl": "63"}, {"idx": 3, "lbl": "125"},
                                {"idx": 4, "lbl": "250"}, {"idx": 5, "lbl": "500"}, {"idx": 6, "lbl": "1k"},
                                {"idx": 7, "lbl": "2k"}, {"idx": 8, "lbl": "4k"}, {"idx": 9, "lbl": "8k"},
                                {"idx": 10, "lbl": "16k"}
                            ]
                            delegate: Item {
                                width: eqSliderRow.width / 10 
                                height: eqSliderRow.height
                                ColumnLayout {
                                    anchors.fill: parent
                                    spacing: 5
                                    Slider {
                                        id: eqSlider
                                        Layout.fillHeight: true
                                        Layout.alignment: Qt.AlignHCenter
                                        orientation: Qt.Vertical
                                        from: -12; to: 12
                                        stepSize: 1

                                        Connections {
                                            target: root
                                            function onEqDataChanged() {
                                                if (!eqSlider.pressed) {
                                                    if (root.eqData && root.eqData["b" + modelData.idx] !== undefined) {
                                                        var p = Number(root.eqData["b" + modelData.idx]);
                                                        if (!isNaN(p)) eqSlider.value = p;
                                                    }
                                                }
                                            }
                                        }

                                        Behavior on value {
                                            enabled: !eqSlider.pressed
                                            NumberAnimation {
                                                duration: 350
                                                easing.type: Easing.OutQuart
                                            }
                                        }

                                        onPressedChanged: {
                                            if (!pressed) {
                                                var temp = Object.assign({}, root.eqData);
                                                temp["b" + modelData.idx] = Math.round(value);
                                                temp.preset = "Custom";
                                                temp.pending = true;
                                                root.eqData = temp;
                                                root.execCmd(`$HOME/.config/hypr/scripts/quickshell/music/equalizer.sh set_band ${modelData.idx} ${Math.round(value)}`);
                                            }
                                        }

                                        background: Rectangle {
                                            x: eqSlider.leftPadding + (eqSlider.availableWidth - width) / 2
                                            y: eqSlider.topPadding
                                            implicitWidth: 10 
                                            implicitHeight: 150
                                            width: 10; height: eqSlider.availableHeight
                                            radius: 5; 
                                            color: "#CC000000"

                                            layer.enabled: true
                                            layer.effect: MultiEffect {
                                                shadowEnabled: true
                                                shadowColor: "#000000"
                                                shadowOpacity: 0.9
                                                shadowBlur: 0.5
                                                shadowVerticalOffset: 1
                                            }

                                            Rectangle {
                                                width: parent.width
                                                height: (1 - eqSlider.visualPosition) * parent.height
                                                y: eqSlider.visualPosition * parent.height
                                                radius: 5; color: root.blue
                                            }
                                        }

                                        handle: Rectangle {
                                            x: eqSlider.leftPadding + (eqSlider.availableWidth - width) / 2
                                            y: eqSlider.topPadding + eqSlider.visualPosition * (eqSlider.availableHeight - height)
                                            implicitWidth: 20
                                            implicitHeight: 20
                                            width: 20; height: 20
                                            radius: 10; color: root.text
                                        }
                                    }
                                    Text {
                                        text: modelData.lbl
                                        color: root.overlay1
                                        font.family: "JetBrains Mono"
                                        font.pixelSize: 10
                                        font.bold: true
                                        Layout.alignment: Qt.AlignHCenter
                                    }
                                }
                            }
                        }
                    }

                    // Presets Grid
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 8
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 10
                            Repeater {
                                model: ["Flat", "Bass", "Treble", "Vocal"]
                                delegate: PresetButton { name: modelData }
                            }
                        }
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 10
                            Repeater {
                                model: ["Pop", "Rock", "Jazz", "Classic"]
                                delegate: PresetButton { name: modelData }
                            }
                        }
                    }
                }
            }
        }
    }

    // --- HELPER COMPONENT FOR PRESETS ---
    component PresetButton : Rectangle {
        property string name: ""
        Layout.fillWidth: true
        Layout.preferredHeight: 32
        radius: 8
        color: root.eqData && root.eqData.preset === name ? root.mauve : "#BF1E1E2E"

        Text {
            anchors.centerIn: parent
            text: parent.name
            color: root.eqData && root.eqData.preset === parent.name ? root.base : root.subtext0
            font.family: "JetBrains Mono"
            font.pixelSize: 12
            font.bold: true
        }
        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: root.applyPresetOptimistically(parent.name)
        }
    }
}
