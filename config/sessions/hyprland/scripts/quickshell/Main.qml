import QtQuick
import QtQuick.Window
import QtQuick.Controls
import Quickshell
import Quickshell.Io

FloatingWindow {
    id: masterWindow
    title: "qs-master"
    color: "transparent"
    
    // Always mapped to prevent Wayland from destroying the surface and Hyprland from auto-centering!
    visible: true 

    property int screenW: 1920
    property int screenH: 1080

    property string currentActive: "hidden" 
    property bool isVisible: false
    property string activeArg: ""

    property real animW: 10
    property real animH: 10

    property var layouts: {
        "battery":   { w: 480, h: 760, x: screenW - 500, y: 70, comp: "battery/BatteryPopup.qml" },
        "calendar":  { w: 1450, h: 750, x: 235, y: 70, comp: "calendar/CalendarPopup.qml" },
        "music":     { w: 700, h: 620, x: 12, y: 70, comp: "music/MusicPopup.qml" },
        "network":   { w: 900, h: 700, x: screenW - 920, y: 70, comp: "network/NetworkPopup.qml" },
        "stewart":   { w: 800, h: 600, x: (screenW/2)-(800/2), y: (screenH/2)-(600/2), comp: "stewart/stewart.qml" },
        "wallpaper": { w: 1920, h: 500, x: 0, y: (screenH/2)-(500/2), comp: "wallpaper/WallpaperPicker.qml" }
    }

    // Wayland physical window bounds
    width: currentActive === "hidden" ? 10 : layouts[currentActive].w
    height: currentActive === "hidden" ? 10 : layouts[currentActive].h
    implicitWidth: width
    implicitHeight: height

    onIsVisibleChanged: {
        if (isVisible) masterWindow.requestActivate();
    }

    // Smooth layout morphing wrapper
    Item {
        anchors.centerIn: parent
        width: masterWindow.animW
        height: masterWindow.animH
        clip: true // Enforces physical borders during the morph

        // Matches Hyprland's default Bezier curve perfectly
        Behavior on width { NumberAnimation { duration: 500; easing.type: Easing.InOutCubic } }
        Behavior on height { NumberAnimation { duration: 500; easing.type: Easing.InOutCubic } }

        opacity: masterWindow.isVisible ? 1.0 : 0.0
        Behavior on opacity { NumberAnimation { duration: 300; easing.type: Easing.InOutSine } }

        StackView {
            id: widgetStack
            anchors.fill: parent
            focus: true
            
            // Brutally enforce keyboard focus to the active widget
            onCurrentItemChanged: {
                if (currentItem) currentItem.forceActiveFocus();
            }

            // Physical UI morphing transitions
            replaceEnter: Transition {
                ParallelAnimation {
                    NumberAnimation { property: "opacity"; from: 0.0; to: 1.0; duration: 350; easing.type: Easing.OutCubic }
                    NumberAnimation { property: "scale"; from: 0.95; to: 1.0; duration: 350; easing.type: Easing.OutBack }
                }
            }
            replaceExit: Transition {
                ParallelAnimation {
                    NumberAnimation { property: "opacity"; from: 1.0; to: 0.0; duration: 250; easing.type: Easing.InCubic }
                    NumberAnimation { property: "scale"; from: 1.0; to: 1.05; duration: 250; easing.type: Easing.InCubic }
                }
            }
        }
    }

    Shortcut {
        sequence: "Escape"
        onActivated: Quickshell.execDetached(["bash", Quickshell.env("HOME") + "/.config/hypr/scripts/quickshell/qs_manager.sh", "close"])
    }

    // THE ENGINE: Orchestrates the pre-positioning and morphing
    function switchWidget(newWidget, arg) {
        if (newWidget === "hidden") {
            if (currentActive !== "hidden" && layouts[currentActive]) {
                // Shrink to the center of the current widget
                let cw = layouts[currentActive].w;
                let ch = layouts[currentActive].h;
                let cx = layouts[currentActive].x + (cw/2);
                let cy = layouts[currentActive].y + (ch/2);
                
                masterWindow.animW = 10;
                masterWindow.animH = 10;
                masterWindow.isVisible = false;
                
                Quickshell.execDetached(["bash", "-c", `hyprctl dispatch resizewindowpixel "exact 10 10,title:^(qs-master)$" && hyprctl dispatch movewindowpixel "exact ${cx} ${cy},title:^(qs-master)$"`]);
            }
            delayedClear.start();

        } else {
            if (currentActive === "hidden") {
                // Opening from scratch: Pre-position invisibly at the target center to prevent flying across the screen
                let target = layouts[newWidget];
                let cx = target.x + (target.w / 2);
                let cy = target.y + (target.h / 2);
                Quickshell.execDetached(["bash", "-c", `hyprctl dispatch movewindowpixel "exact ${cx} ${cy},title:^(qs-master)$"`]);
                
                prepTimer.newWidget = newWidget;
                prepTimer.newArg = arg;
                prepTimer.start(); // Wait 50ms for Hyprland to warp it, then bloom
            } else {
                // Morphing between two visible widgets: Do it instantly!
                executeSwitch(newWidget, arg);
            }
        }
    }

    Timer {
        id: prepTimer
        interval: 50
        property string newWidget: ""
        property string newArg: ""
        onTriggered: executeSwitch(newWidget, newArg)
    }

    function executeSwitch(newWidget, arg) {
        masterWindow.currentActive = newWidget;
        masterWindow.activeArg = arg;
        
        let target = layouts[newWidget];
        masterWindow.animW = target.w;
        masterWindow.animH = target.h;
        
        // Snap Wayland surface instantly, tell Hyprland to animate
        masterWindow.width = target.w;
        masterWindow.height = target.h;
        Quickshell.execDetached(["bash", "-c", `hyprctl dispatch resizewindowpixel "exact ${target.w} ${target.h},title:^(qs-master)$" && hyprctl dispatch movewindowpixel "exact ${target.x} ${target.y},title:^(qs-master)$"`]);
        
        masterWindow.isVisible = true;
        
        let props = {};
        if (newWidget === "wallpaper") props = { "widgetArg": masterWindow.activeArg };
        widgetStack.replace(target.comp, props);
    }

    Timer {
        interval: 50; running: true; repeat: true
        onTriggered: { if (!ipcPoller.running) ipcPoller.running = true; }
    }

    Process {
        id: ipcPoller
        command: ["bash", "-c", "if [ -f /tmp/qs_widget_state ]; then cat /tmp/qs_widget_state; rm /tmp/qs_widget_state; fi"]
        stdout: StdioCollector {
            onStreamFinished: {
                let rawCmd = this.text.trim();
                if (rawCmd === "") return;

                let parts = rawCmd.split(":");
                let cmd = parts[0];
                let arg = parts.length > 1 ? parts[1] : "";

                if (cmd === "close") {
                    switchWidget("hidden", "");
                } else if (layouts[cmd]) {
                    delayedClear.stop();
                    if (masterWindow.isVisible && masterWindow.currentActive === cmd) {
                        switchWidget("hidden", "");
                    } else {
                        switchWidget(cmd, arg);
                    }
                }
            }
        }
    }

    Timer {
        id: delayedClear
        interval: 400
        onTriggered: {
            masterWindow.currentActive = "hidden";
            widgetStack.clear();
        }
    }
}
