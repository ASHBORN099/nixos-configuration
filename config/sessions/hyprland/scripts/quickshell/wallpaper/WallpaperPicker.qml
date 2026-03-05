import QtQuick
import QtQuick.Layouts
import Qt.labs.folderlistmodel
import Quickshell
import Quickshell.Io

Item {
    id: window

    // -------------------------------------------------------------------------
    // PROPERTIES & IPC RECEIVER
    // -------------------------------------------------------------------------
    property string widgetArg: ""
    property int targetWallIndex: 0
    property bool initialFocusSet: false

    onWidgetArgChanged: {
        let idx = parseInt(widgetArg);
        if (!isNaN(idx)) {
            targetWallIndex = idx;
            tryFocus();
        }
    }

    function tryFocus() {
        if (!initialFocusSet && view.count > targetWallIndex) {
            view.currentIndex = targetWallIndex;
            view.positionViewAtIndex(targetWallIndex, ListView.Center);
            initialFocusSet = true;
        }
    }

    readonly property string homeDir: "file://" + Quickshell.env("HOME")
    readonly property string thumbDir: homeDir + "/.cache/wallpaper_picker/thumbs"
    readonly property string srcDir: Quickshell.env("HOME") + "/Images/Wallpapers"

    readonly property string swwwCommand: "swww img '%1' --transition-type %2 --transition-pos 0.5,0.5 --transition-fps 144 --transition-duration 1"
    readonly property string mpvCommand: "pkill mpvpaper; mpvpaper -o 'loop --hwdec=auto --no-audio' '*' '%1' & sleep 0.5; " + Quickshell.env("HOME") + "/.config/eww/bar/launch_bar.sh --force-open"
    
    readonly property var transitions: ["grow", "outer", "any", "wipe", "wave", "pixel", "center"]

    readonly property int itemWidth: 300
    readonly property int itemHeight: 420
    readonly property int borderWidth: 3
    readonly property int spacing: 0 
    readonly property real skewFactor: -0.35

    // Bulletproof explicit keyboard navigation
    Shortcut { sequence: "Left"; onActivated: view.decrementCurrentIndex() }
    Shortcut { sequence: "Right"; onActivated: view.incrementCurrentIndex() }
    Shortcut { sequence: "Return"; onActivated: { if (view.currentItem) view.currentItem.pickWallpaper() } }

    // -------------------------------------------------------------------------
    // CONTENT
    // -------------------------------------------------------------------------
    ListView {
        id: view
        anchors.fill: parent
        anchors.margins: 0 
        
        spacing: window.spacing
        orientation: ListView.Horizontal
        clip: false 

        highlightRangeMode: ListView.StrictlyEnforceRange
        preferredHighlightBegin: (width / 2) - (window.itemWidth / 2)
        preferredHighlightEnd: (width / 2) + (window.itemWidth / 2)
        highlightMoveDuration: 300

        focus: true
        onCountChanged: window.tryFocus()

        model: FolderListModel {
            id: folderModel
            folder: window.thumbDir
            nameFilters: ["*.jpg", "*.jpeg", "*.png", "*.webp", "*.gif", "*.mp4", "*.mkv", "*.mov", "*.webm"]
            showDirs: false
            sortField: FolderListModel.Name 
        }

        delegate: Item {
            id: delegateRoot
            width: window.itemWidth
            height: window.itemHeight
            anchors.verticalCenter: parent.verticalCenter

            readonly property bool isCurrent: ListView.isCurrentItem
            readonly property bool isVideo: fileName.startsWith("000_")

            z: isCurrent ? 10 : 1

            function pickWallpaper() {
                let cleanName = fileName
                if (cleanName.startsWith("000_")) {
                    cleanName = cleanName.substring(4)
                }

                const originalFile = window.srcDir + "/" + cleanName
                
                if (isVideo) {
                     const finalCmd = window.mpvCommand.arg(originalFile)
                     Quickshell.execDetached(["bash", "-c", finalCmd])
                } else {
                     const randomTransition = window.transitions[Math.floor(Math.random() * window.transitions.length)]
                     const finalCmd = window.swwwCommand.arg(originalFile).arg(randomTransition)
                     Quickshell.execDetached(["bash", "-c", "pkill mpvpaper; " + finalCmd])
                }
                
                Quickshell.execDetached(["bash", "-c", "echo 'close' > /tmp/qs_widget_state"])
            }

            MouseArea {
                anchors.fill: parent
                onClicked: {
                    view.currentIndex = index
                    delegateRoot.pickWallpaper()
                }
            }

            Item {
                anchors.centerIn: parent
                width: parent.width
                height: parent.height

                scale: delegateRoot.isCurrent ? 1.15 : 0.95
                opacity: delegateRoot.isCurrent ? 1.0 : 0.6

                Behavior on scale { NumberAnimation { duration: 500; easing.type: Easing.OutBack } }
                Behavior on opacity { NumberAnimation { duration: 500 } }

                transform: Matrix4x4 {
                    property real s: window.skewFactor
                    matrix: Qt.matrix4x4(1, s, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1)
                }

                Image {
                    anchors.fill: parent
                    source: fileUrl
                    sourceSize: Qt.size(1, 1)
                    fillMode: Image.Stretch
                    visible: true 
                }

                Item {
                    anchors.fill: parent
                    anchors.margins: window.borderWidth 
                    
                    Rectangle { anchors.fill: parent; color: "black" }
                    clip: true

                    Image {
                        anchors.centerIn: parent
                        anchors.horizontalCenterOffset: -35 
                        
                        width: parent.width + (parent.height * Math.abs(window.skewFactor)) + 50
                        height: parent.height
                        
                        fillMode: Image.PreserveAspectCrop
                        source: fileUrl

                        transform: Matrix4x4 {
                            property real s: -window.skewFactor
                            matrix: Qt.matrix4x4(1, s, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1)
                        }
                    }
                    
                    Rectangle {
                        visible: delegateRoot.isVideo
                        anchors.top: parent.top
                        anchors.right: parent.right
                        anchors.margins: 10
                        
                        width: 32
                        height: 32
                        radius: 6
                        color: "#60000000" 
                        
                        transform: Matrix4x4 {
                            property real s: -window.skewFactor
                            matrix: Qt.matrix4x4(1, s, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1)
                        }
                        
                        Canvas {
                            anchors.fill: parent
                            anchors.margins: 8 
                            onPaint: {
                                var ctx = getContext("2d");
                                ctx.fillStyle = "#EEFFFFFF"; 
                                ctx.beginPath();
                                ctx.moveTo(4, 0);
                                ctx.lineTo(14, 8);
                                ctx.lineTo(4, 16);
                                ctx.closePath();
                                ctx.fill();
                            }
                        }
                    }
                }
            }
        }
    }

    Component.onCompleted: {
        view.forceActiveFocus();
    }
}
