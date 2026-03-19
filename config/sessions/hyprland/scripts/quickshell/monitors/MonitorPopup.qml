import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import Quickshell
import Quickshell.Io

Item {
    id: window
    
    // -------------------------------------------------------------------------
    // COLORS (Catppuccin Mocha)
    // -------------------------------------------------------------------------
    readonly property color base: "#1e1e2e"
    readonly property color mantle: "#181825"
    readonly property color crust: "#11111b"
    readonly property color text: "#cdd6f4"
    readonly property color subtext0: "#a6adc8"
    readonly property color overlay0: "#6c7086"
    readonly property color surface0: "#313244"
    readonly property color surface1: "#45475a"
    readonly property color surface2: "#585b70"
    
    readonly property color mauve: "#cba6f7"
    readonly property color blue: "#89b4fa"

    // -------------------------------------------------------------------------
    // STATE & MATH
    // -------------------------------------------------------------------------
    property string activeMonitorName: "Unknown"
    property string currentRes: "1920x1080"
    property string currentRate: "60Hz"

    property string selectedRes: currentRes
    property string selectedRate: currentRate
    
    // Dynamic Accent Colors assigned by selection
    property color selectedResAccent: "#cba6f7"
    property color selectedRateAccent: "#b4befe"

    // Dynamic extraction for physical scaling
    property real simW: parseInt(window.selectedRes.split("x")[0]) || 1920
    property real simH: parseInt(window.selectedRes.split("x")[1]) || 1080

    property real globalOrbitAngle: 0
    NumberAnimation on globalOrbitAngle {
        from: 0; to: Math.PI * 2; duration: 90000; loops: Animation.Infinite; running: true
    }

    property real introState: 0.0
    Component.onCompleted: introState = 1.0
    Behavior on introState { NumberAnimation { duration: 800; easing.type: Easing.OutQuint } }

    // HOISTED BUTTON STATES
    property bool applyHovered: false
    property bool applyPressed: false

    // -------------------------------------------------------------------------
    // NATIVE SYSTEM PROCESSES 
    // -------------------------------------------------------------------------
    Process {
        id: displayPoller
        command: ["hyprctl", "monitors", "-j"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    let data = JSON.parse(this.text.trim());
                    for (let i = 0; i < data.length; i++) {
                        if (data[i].focused) {
                            window.activeMonitorName = data[i].name;
                            window.currentRes = data[i].width + "x" + data[i].height;
                            window.currentRate = Math.round(data[i].refreshRate) + "Hz";
                            
                            window.selectedRes = window.currentRes;
                            window.selectedRate = window.currentRate;
                            break;
                        }
                    }
                } catch(e) {}
            }
        }
    }

    // -------------------------------------------------------------------------
    // UI LAYOUT
    // -------------------------------------------------------------------------
    Item {
        anchors.fill: parent
        scale: 0.95 + (0.05 * introState)
        opacity: introState

        // Outer Border
        Rectangle {
            anchors.fill: parent
            radius: 30
            color: window.base
            border.color: window.surface0
            border.width: 1
            clip: true

            // Ambient background blobs matching network/battery
            Rectangle {
                width: parent.width * 0.8; height: width; radius: width / 2
                x: (parent.width / 2 - width / 2) + Math.cos(window.globalOrbitAngle * 2) * 150
                y: (parent.height / 2 - height / 2) + Math.sin(window.globalOrbitAngle * 2) * 100
                opacity: 0.04
                color: window.selectedResAccent
                Behavior on color { ColorAnimation { duration: 1000 } }
            }
            Rectangle {
                width: parent.width * 0.9; height: width; radius: width / 2
                x: (parent.width / 2 - width / 2) + Math.sin(window.globalOrbitAngle * 1.5) * -150
                y: (parent.height / 2 - height / 2) + Math.cos(window.globalOrbitAngle * 1.5) * -100
                opacity: 0.04
                color: window.selectedRateAccent
                Behavior on color { ColorAnimation { duration: 1000 } }
            }

            // ==========================================
            // MAIN DISPLAY GRAPHIC (MORPHING)
            // ==========================================
            Item {
                id: monitorVisual
                width: 340
                height: 300
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                anchors.verticalCenterOffset: -20
                anchors.leftMargin: 30

                // Stand Base
                Rectangle {
                    id: standBase
                    width: 130; height: 8; radius: 4
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: 20
                    anchors.horizontalCenter: parent.horizontalCenter
                    color: window.surface1
                }
                
                // Stand Neck
                Rectangle {
                    id: standNeck
                    width: 34; height: 70
                    anchors.bottom: standBase.top
                    anchors.horizontalCenter: parent.horizontalCenter
                    color: window.surface0
                    
                    Rectangle {
                        width: 10; height: 30; radius: 5
                        anchors.centerIn: parent
                        color: window.base
                    }
                }

                // The Screen Bezel (Dynamically Morphs based on Resolution!)
                Rectangle {
                    id: screenBezel
                    width: 140 + (180 * (window.simW / 1920))
                    height: 90 + (90 * (window.simH / 1080))
                    
                    anchors.bottom: standNeck.top
                    anchors.bottomMargin: -10
                    anchors.horizontalCenter: parent.horizontalCenter
                    radius: 12
                    color: window.crust
                    border.color: window.surface2
                    border.width: 2
                    
                    // Fluid physics for the morphing
                    Behavior on width { NumberAnimation { duration: 600; easing.type: Easing.OutElastic; easing.overshoot: 1.2 } }
                    Behavior on height { NumberAnimation { duration: 600; easing.type: Easing.OutElastic; easing.overshoot: 1.2 } }

                    // The actual "Display" inside
                    Rectangle {
                        anchors.fill: parent
                        anchors.margins: 10
                        radius: 6
                        color: window.surface0
                        clip: true

                        gradient: Gradient {
                            orientation: Gradient.Vertical
                            GradientStop { position: 0.0; color: Qt.tint(window.surface0, Qt.rgba(window.selectedResAccent.r, window.selectedResAccent.g, window.selectedResAccent.b, 0.15)); Behavior on color { ColorAnimation { duration: 400 } } }
                            GradientStop { position: 1.0; color: Qt.tint(window.surface0, Qt.rgba(window.selectedRateAccent.r, window.selectedRateAccent.g, window.selectedRateAccent.b, 0.1)); Behavior on color { ColorAnimation { duration: 400 } } }
                        }

                        // Background grid to emphasize the size change
                        Grid {
                            anchors.centerIn: parent
                            rows: 10; columns: 15; spacing: 20
                            Repeater {
                                model: 150
                                Rectangle { width: 2; height: 2; radius: 1; color: "#1affffff" }
                            }
                        }

                        ColumnLayout {
                            anchors.centerIn: parent
                            spacing: 4
                            
                            Text {
                                Layout.alignment: Qt.AlignHCenter
                                font.family: "Iosevka Nerd Font"
                                font.pixelSize: 38
                                color: window.selectedResAccent
                                text: "󰍹"
                                Behavior on color { ColorAnimation { duration: 400 } }
                            }
                            Text {
                                Layout.alignment: Qt.AlignHCenter
                                font.family: "JetBrains Mono"
                                font.weight: Font.Bold
                                font.pixelSize: 16
                                color: window.text
                                text: window.activeMonitorName
                            }
                            Text {
                                Layout.alignment: Qt.AlignHCenter
                                font.family: "JetBrains Mono"
                                font.pixelSize: 12
                                color: window.subtext0
                                text: window.selectedRes + " @ " + window.selectedRate
                            }
                        }
                    }
                }
            }

            // ==========================================
            // INTERACTIVE SELECTION GRIDS
            // ==========================================
            ColumnLayout {
                anchors.left: monitorVisual.right
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter 
                anchors.leftMargin: 20
                anchors.rightMargin: 40
                height: 310
                spacing: 12

                // --- RESOLUTION CARDS SECTION ---
                GridLayout {
                    Layout.fillWidth: true
                    columns: 2
                    columnSpacing: 10
                    rowSpacing: 10

                    Repeater {
                        model: ListModel {
                            ListElement { res: "1920x1080"; label: "FHD"; accent: "#cba6f7" }
                            ListElement { res: "1600x900"; label: "HD+"; accent: "#f5c2e7" } 
                            ListElement { res: "1366x768"; label: "WXGA"; accent: "#eba0ac" } 
                            ListElement { res: "1280x720"; label: "HD"; accent: "#fab387" } 
                            ListElement { res: "1024x768"; label: "XGA"; accent: "#f9e2af" } 
                            ListElement { res: "800x600"; label: "SVGA"; accent: "#a6e3a1" }  
                        }

                        delegate: Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 48
                            radius: 12
                            
                            property bool isSel: window.selectedRes === res
                            property color accentColor: accent
                            
                            color: isSel ? Qt.rgba(accentColor.r, accentColor.g, accentColor.b, 0.1) : (resMa.containsMouse ? window.surface0 : window.mantle)
                            border.color: isSel ? accentColor : (resMa.containsMouse ? window.surface1 : "transparent")
                            border.width: isSel ? 2 : 1
                            Behavior on color { ColorAnimation { duration: 200 } }
                            Behavior on border.color { ColorAnimation { duration: 200 } }

                            RowLayout {
                                anchors.fill: parent
                                anchors.margins: 12
                                spacing: 8

                                Text {
                                    font.family: "JetBrains Mono"
                                    font.weight: isSel ? Font.Black : Font.Bold
                                    font.pixelSize: 14
                                    color: isSel ? accentColor : window.text
                                    text: label
                                    Behavior on color { ColorAnimation { duration: 200 } }
                                }
                                
                                Item { Layout.fillWidth: true } // Spacer

                                Text {
                                    font.family: "JetBrains Mono"
                                    font.pixelSize: 11
                                    color: isSel ? window.text : window.overlay0
                                    text: res
                                    Behavior on color { ColorAnimation { duration: 200 } }
                                }
                            }

                            scale: resMa.pressed ? 0.96 : 1.0
                            Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutSine } }

                            MouseArea {
                                id: resMa
                                anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    window.selectedRes = res;
                                    window.selectedResAccent = accentColor;
                                }
                            }
                        }
                    }
                }

                Item { Layout.preferredHeight: 15 } // Spacer between sections

                // --- REFRESH RATE SLIDER SECTION ---
                Item {
                    id: sliderContainer
                    Layout.fillWidth: true
                    Layout.preferredHeight: 50
                    Layout.leftMargin: 10
                    Layout.rightMargin: 10

                    property var rates: [30, 60, 75, 100, 120, 144]
                    property var rateColors: ["#f38ba8", "#b4befe", "#89b4fa", "#74c7ec", "#94e2d5", "#a6e3a1"]
                    
                    // Safely find the closest index based on the active rate
                    property int currentIndex: {
                        let currentVal = parseInt(window.selectedRate) || 60;
                        let closestIdx = 0;
                        let minDiff = 9999;
                        for (let i = 0; i < rates.length; i++) {
                            let diff = Math.abs(rates[i] - currentVal);
                            if (diff < minDiff) {
                                minDiff = diff;
                                closestIdx = i;
                            }
                        }
                        return closestIdx;
                    }

                    // Fluid property for the 1:1 drag feeling
                    property real visualPct: currentIndex / (rates.length - 1)

                    onCurrentIndexChanged: {
                        if (!sliderMa.pressed) {
                            visualPct = currentIndex / (rates.length - 1);
                        }
                    }

                    Rectangle {
                        id: track
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.verticalCenterOffset: -10
                        height: 8
                        radius: 4
                        color: window.mantle
                        border.color: window.crust
                        border.width: 1

                        // Active track fill
                        Rectangle {
                            width: knob.x + knob.width / 2
                            height: parent.height
                            radius: parent.radius
                            color: window.selectedRateAccent
                            // No width behavior here, it directly mirrors the knob's position for zero latency
                            Behavior on color { ColorAnimation { duration: 200 } }
                        }
                    }

                    // Ticks and Labels
                    Repeater {
                        model: sliderContainer.rates.length
                        Item {
                            x: (index / (sliderContainer.rates.length - 1)) * track.width
                            y: track.y + 18

                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: sliderContainer.rates[index] + "Hz"
                                font.family: "JetBrains Mono"
                                font.pixelSize: 11
                                font.weight: sliderContainer.currentIndex === index ? Font.Bold : Font.Normal
                                color: sliderContainer.currentIndex === index ? window.selectedRateAccent : window.overlay0
                                Behavior on color { ColorAnimation { duration: 200 } }
                            }
                        }
                    }

                    // Draggable Knob
                    Rectangle {
                        id: knob
                        width: 20
                        height: 20
                        radius: 10
                        color: sliderMa.containsPress ? window.selectedRateAccent : window.text
                        anchors.verticalCenter: track.verticalCenter
                        x: (sliderContainer.visualPct * track.width) - width / 2
                        
                        // Disable the X animation completely while actively dragging for a 1:1 fluid feel
                        Behavior on x {
                            enabled: !sliderMa.pressed
                            NumberAnimation { duration: 250; easing.type: Easing.OutCubic }
                        }
                        Behavior on color { ColorAnimation { duration: 150 } }

                        // Halo effect on hover
                        border.width: sliderMa.containsMouse ? 4 : 0
                        border.color: Qt.rgba(window.selectedRateAccent.r, window.selectedRateAccent.g, window.selectedRateAccent.b, 0.3)
                        Behavior on border.width { NumberAnimation { duration: 150 } }
                    }

                    // Gesture Handling Area
                    MouseArea {
                        id: sliderMa
                        anchors.fill: parent
                        anchors.margins: -15
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor

                        function updateSelection(mouseX, snapToGrid) {
                            let pct = (mouseX - track.x) / track.width;
                            pct = Math.max(0, Math.min(1, pct));
                            let idx = Math.round(pct * (sliderContainer.rates.length - 1));
                            
                            if (snapToGrid) {
                                sliderContainer.visualPct = idx / (sliderContainer.rates.length - 1);
                            } else {
                                sliderContainer.visualPct = pct;
                            }

                            window.selectedRate = sliderContainer.rates[idx] + "Hz";
                            window.selectedRateAccent = sliderContainer.rateColors[idx];
                        }

                        onPressed: (mouse) => updateSelection(mouse.x, false)
                        onPositionChanged: (mouse) => {
                            if (pressed) updateSelection(mouse.x, false)
                        }
                        onReleased: (mouse) => updateSelection(mouse.x, true)
                        onCanceled: () => sliderContainer.visualPct = sliderContainer.currentIndex / (sliderContainer.rates.length - 1)
                    }
                }
                
                Item { Layout.fillHeight: true } // Pushes everything neatly to the top
            }

            // ==========================================
            // FLOATING APPLY BUTTON (Bottom Right)
            // ==========================================
            Item {
                id: applyButtonContainer
                anchors.bottom: parent.bottom
                anchors.right: parent.right
                anchors.margins: 35
                width: 170
                height: 50

                MultiEffect {
                    source: applyBtn
                    anchors.fill: applyBtn
                    shadowEnabled: true
                    shadowColor: window.selectedRateAccent
                    shadowBlur: window.applyHovered ? 1.2 : 0.6
                    shadowOpacity: window.applyHovered ? 0.6 : 0.2
                    shadowVerticalOffset: 4
                    z: -1
                    Behavior on shadowBlur { NumberAnimation { duration: 300 } }
                    Behavior on shadowOpacity { NumberAnimation { duration: 300 } }
                    Behavior on shadowColor { ColorAnimation { duration: 400 } }
                }

                Rectangle {
                    id: applyBtn
                    anchors.fill: parent
                    radius: 25
                    
                    gradient: Gradient {
                        orientation: Gradient.Horizontal
                        GradientStop { position: 0.0; color: window.selectedResAccent; Behavior on color { ColorAnimation { duration: 400 } } }
                        GradientStop { position: 1.0; color: window.selectedRateAccent; Behavior on color { ColorAnimation { duration: 400 } } }
                    }
                    
                    scale: window.applyPressed ? 0.94 : (window.applyHovered ? 1.04 : 1.0)
                    Behavior on scale { NumberAnimation { duration: 300; easing.type: Easing.OutBack } }

                    Rectangle {
                        id: flashRect
                        anchors.fill: parent; radius: 25; color: "#ffffff"
                        opacity: 0.0
                        PropertyAnimation on opacity { id: applyFlashAnim; to: 0.0; duration: 400; easing.type: Easing.OutExpo }
                    }

                    RowLayout {
                        anchors.centerIn: parent
                        spacing: 8
                        Text { 
                            font.family: "Iosevka Nerd Font"
                            font.pixelSize: 20
                            color: window.crust
                            text: "󰸵" 
                        }
                        Text { 
                            font.family: "JetBrains Mono"
                            font.weight: Font.Black
                            font.pixelSize: 14
                            color: window.crust
                            text: "Apply" 
                        }
                    }
                }

                MouseArea {
                    id: applyMa
                    anchors.fill: parent
                    z: 10
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    
                    onEntered: window.applyHovered = true
                    onExited: window.applyHovered = false
                    onPressed: window.applyPressed = true
                    onReleased: window.applyPressed = false
                    onCanceled: window.applyPressed = false

                    onClicked: {
                        // 1. Visual trigger (Flash only)
                        flashRect.opacity = 0.8;
                        applyFlashAnim.start();

                        let cleanRate = window.selectedRate.replace("Hz", "");
                        let monitorStr = window.activeMonitorName + "," + window.selectedRes + "@" + cleanRate + ",auto,1";
                        
                        // 2. Natively trigger notify-send & hyprctl using execDetached
                        Quickshell.execDetached(["notify-send", "Display Update", "Applied: " + window.selectedRes + " @ " + window.selectedRate]);
                        Quickshell.execDetached(["hyprctl", "keyword", "monitor", monitorStr]);
                    }
                }
            }
        }
    }
}
