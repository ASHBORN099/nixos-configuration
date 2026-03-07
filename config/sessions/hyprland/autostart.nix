{config, ... }:

{
   wayland.windowManager.hyprland.settings = {
      "exec-once" = [
	 "swww-daemon"
	 "hypridle"
	 "playerctld"
	 #"~/.config/eww/bar/launch_bar.sh --force-open"
	 "wl-paste --type text --watch cliphist store" 
	 "wl-paste --type image --watch cliphist store"
	 "systemctl --user enable --now easyeffects"
	 "${./scripts/volume_listener.sh}"
	 # "bash ${./scripts/bluetooth_mgr.sh} --daemon"
         # "bash ${./scripts/usb.sh}"
	 "gsettings set org.gnome.desktop.interface cursor-theme 'ArcMidnight-Cursors'"
    	 "gsettings set org.gnome.desktop.interface cursor-size 24"
	 "quickshell -p ~/.config/hypr/scripts/quickshell/Main.qml"
	 "quickshell -p ~/.config/hypr/scripts/quickshell/TopBar.qml"
      ];
   };
}
