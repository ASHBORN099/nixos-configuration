#!/usr/bin/env bash

# Paths
QS_DIR="$HOME/.config/hypr/scripts/quickshell"
BT_PID_FILE="$HOME/.cache/bt_scan_pid"
BT_SCAN_LOG="$HOME/.cache/bt_scan.log"
SRC_DIR="$HOME/Images/Wallpapers"
THUMB_DIR="$HOME/.cache/wallpaper_picker/thumbs"

ACTION="$1"
TARGET="$2"

# -----------------------------------------------------------------------------
# FUNCTION: Map friendly names to QML paths and window focus titles
# -----------------------------------------------------------------------------
get_qml_info() {
    case "$1" in
        battery)   QML_FILE="battery/BatteryPopup.qml";      FOCUS="title:battery-popup" ;;
        calendar)  QML_FILE="calendar/CalendarPopup.qml";    FOCUS="title:calendar_win" ;;
        music)     QML_FILE="music/MusicPopup.qml";          FOCUS="title:music_win" ;;
        network)   QML_FILE="network/NetworkPopup.qml";      FOCUS="title:network-popup" ;;
        stewart)     QML_FILE="stewart/stewart.qml";           FOCUS="title:stewart" ;;
        wallpaper) QML_FILE="wallpaper/WallpaperPicker.qml"; FOCUS="title:wallpaper-picker" ;;
        *) 
            echo "Error: Unknown window '$1'."
            echo "Available: battery, calendar, music, network, stewart, wallpaper"
            exit 1 
            ;;
    esac
}

# -----------------------------------------------------------------------------
# FUNCTION: Clean up all Quickshell popups and background tasks
# -----------------------------------------------------------------------------
cleanup_all() {
    # Kill all known quickshell popups managed by this script
    pkill -f "quickshell.*(BatteryPopup|CalendarPopup|MusicPopup|NetworkPopup|stewart|WallpaperPicker)\.qml"

    # Cleanup Bluetooth scanning safely
    if [ -f "$BT_PID_FILE" ]; then
        kill $(cat "$BT_PID_FILE") 2>/dev/null
        rm -f "$BT_PID_FILE"
    fi
    bluetoothctl scan off > /dev/null 2>&1
}

# -----------------------------------------------------------------------------
# FUNCTION: Prep Wallpaper Picker (Thumbnails & Active Index)
# -----------------------------------------------------------------------------
handle_wallpaper_prep() {
    mkdir -p "$THUMB_DIR"
    (
        # CLEANUP: Remove thumbnails that no longer have a source wallpaper
        for thumb in "$THUMB_DIR"/*; do
            [ -e "$thumb" ] || continue
            filename=$(basename "$thumb")
            clean_name="${filename#000_}"
            if [ ! -f "$SRC_DIR/$clean_name" ]; then
                rm -f "$thumb"
            fi
        done

        # GENERATE: Create thumbnails for new or renamed wallpapers
        for img in "$SRC_DIR"/*.{jpg,jpeg,png,webp,gif,mp4,mkv,mov,webm}; do
            [ -e "$img" ] || continue
            filename=$(basename "$img")
            extension="${filename##*.}"

            if [[ "${extension,,}" =~ ^(mp4|mkv|mov|webm)$ ]]; then
                thumb="$THUMB_DIR/000_$filename"
                [ -f "$THUMB_DIR/$filename" ] && rm -f "$THUMB_DIR/$filename"
                if [ ! -f "$thumb" ]; then
                     ffmpeg -y -ss 00:00:05 -i "$img" -vframes 1 -f image2 -q:v 2 "$thumb" > /dev/null 2>&1
                fi
            else
                thumb="$THUMB_DIR/$filename"
                if [ ! -f "$thumb" ]; then
                    magick "$img" -resize x420 -quality 70 "$thumb"
                fi
            fi
        done
    ) &

    # Detect Active Wallpaper & Calculate Index
    TARGET_INDEX=0
    CURRENT_SRC=""

    if pgrep -a "mpvpaper" > /dev/null; then
        CURRENT_SRC=$(pgrep -a mpvpaper | grep -o "$SRC_DIR/[^' ]*" | head -n1)
        CURRENT_SRC=$(basename "$CURRENT_SRC")
    fi

    if [ -z "$CURRENT_SRC" ] && command -v swww >/dev/null; then
        CURRENT_SRC=$(swww query 2>/dev/null | grep -o "$SRC_DIR/[^ ]*" | head -n1)
        CURRENT_SRC=$(basename "$CURRENT_SRC")
    fi

    if [ -n "$CURRENT_SRC" ]; then
        EXT="${CURRENT_SRC##*.}"
        if [[ "${EXT,,}" =~ ^(mp4|mkv|mov|webm)$ ]]; then
            TARGET_THUMB="000_$CURRENT_SRC"
        else
            TARGET_THUMB="$CURRENT_SRC"
        fi

        MATCH_LINE=$(ls -1 "$THUMB_DIR" | grep -nF "$TARGET_THUMB" | cut -d: -f1)
        if [ -n "$MATCH_LINE" ]; then
            TARGET_INDEX=$((MATCH_LINE - 1))
        fi
    fi

    export WALLPAPER_INDEX="$TARGET_INDEX"
}

# -----------------------------------------------------------------------------
# FUNCTION: Prep Network (Bluetooth & WiFi scan)
# -----------------------------------------------------------------------------
handle_network_prep() {
    echo "" > "$BT_SCAN_LOG"
    { echo "scan on"; sleep infinity; } | stdbuf -oL bluetoothctl > "$BT_SCAN_LOG" 2>&1 &
    echo $! > "$BT_PID_FILE"
    (nmcli device wifi rescan) &
}

# =============================================================================
# MAIN LOGIC
# =============================================================================

# 1. Handle Workspace Switching & Moving directly
if [[ "$ACTION" =~ ^[0-9]+$ ]]; then
    WORKSPACE_NUM="$ACTION"
    MOVE_OPT="$2"
    
    cleanup_all
    
    if [[ "$MOVE_OPT" == "move" ]]; then
        hyprctl dispatch movetoworkspace "$WORKSPACE_NUM"
    else
        hyprctl dispatch workspace "$WORKSPACE_NUM"
    fi
    exit 0
fi

# 2. Handle Closing
if [[ "$ACTION" == "close" ]]; then
    if [[ -z "$TARGET" || "$TARGET" == "all" ]]; then
        # Close everything if no target is specified
        cleanup_all
    else
        # Close only the specific target
        get_qml_info "$TARGET"
        QML_BASE=$(basename "$QML_FILE")
        pkill -f "quickshell.*$QML_BASE"

        # If it was the network window, handle the specific bluetooth cleanup
        if [[ "$TARGET" == "network" ]]; then
            if [ -f "$BT_PID_FILE" ]; then
                kill $(cat "$BT_PID_FILE") 2>/dev/null
                rm -f "$BT_PID_FILE"
            fi
            bluetoothctl scan off > /dev/null 2>&1
        fi
    fi
    exit 0
fi

# 3. Handle Opening / Toggling specific windows
if [[ "$ACTION" == "open" || "$ACTION" == "toggle" ]]; then
    
    get_qml_info "$TARGET"
    QML_BASE=$(basename "$QML_FILE")

    # If action is 'toggle', check if it's already running
    if [[ "$ACTION" == "toggle" ]]; then
        if pgrep -f "quickshell.*$QML_BASE" > /dev/null; then
            # It's running, so close it and exit
            cleanup_all
            exit 0
        fi
    fi

    # GLOBAL RESET: Ensure exclusive behavior (only one open at a time)
    cleanup_all

    # Run the specific setup and open it
    if [[ "$TARGET" == "network" ]]; then
        handle_network_prep
    elif [[ "$TARGET" == "wallpaper" ]]; then
        handle_wallpaper_prep
    fi

    quickshell -p "$QS_DIR/$QML_FILE" &

    # Focus logic to ensure escape key works
    sleep 0.2
    hyprctl dispatch focuswindow "$FOCUS"

    exit 0
fi

