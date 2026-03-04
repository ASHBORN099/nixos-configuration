{ config, lib, ... }:

{
  wayland.windowManager.hyprland.settings = {

    # ─────────────────────────────
    # Layer rules (OSD / overlays)
    # ─────────────────────────────
    layerrule = [
      "noanim, ^(volume_osd)$"
      "noanim, ^(brightness_osd)$"
      "noanim, ^(music_win)$"
      "noanim, ^(usb_popup)$"
      "noanim, ^(calendar_win)$"
      "noanim, ^(network_win)$"
      "noanim, hyprpicker"
    ];

    # ─────────────────────────────
    # Window rules
    # ─────────────────────────────
    windowrulev2 = [

      # ───────── music_vis ─────────
      "float, class:^(music_vis)$"
      "pin, class:^(music_vis)$"
      "noinitialfocus, class:^(music_vis)$"

      "size 700 350, class:^(music_vis)$"
      "move 12 720, class:^(music_vis)$"

      "noborder, class:^(music_vis)$"
      "noshadow, class:^(music_vis)$"


      # ───────── CS2 ─────────
      "immediate, class:^(cs2)$"
      "keepaspectratio, class:^(cs2)$"


      # ───────── Wallpaper Picker ─────────
      "float, title:^(wallpaper-picker)$"
      "center, title:^(wallpaper-picker)$"
      "size 1920 500, title:^(wallpaper-picker)$"
      # "move 0 0, title:^(wallpaper-picker)$"


      # ───────── Battery Popup ─────────
      "float, title:^(battery-popup)$"
      "pin, title:^(battery-popup)$"

      "size 480 680, title:^(battery-popup)$"
      "move 100%-500 70, title:^(battery-popup)$"


      # ───────── App Launcher ─────────
      "float, title:^(app-launcher)$"
      "center, title:^(app-launcher)$"

      "size 1200 600, title:^(app-launcher)$"

      "animation slide, title:^(app-launcher)$"


      # ───────── Network Popup ─────────
      "float, title:^(network-popup)$"
      "pin, title:^(network-popup)$"

      "size 900 700, title:^(network-popup)$"
      "move 100%-920 70, title:^(network-popup)$"


      # ───────── Music Window ─────────
      "float, title:^(music_win)$"
      "pin, title:^(music_win)$"

      "size 700 620, title:^(music_win)$"
      "move 12 70, title:^(music_win)$"

      # ───────── Calendar Window ─────────
      "float, title:^(calendar_win)$"
      "pin, title:^(calendar_win)$"
      
      "size 1300 750, title:^(calendar_win)$"
      "move 310 70, title:^(calendar_win)$"

      "float, title:^(stewart)$"
      "pin, title:^(stewart)$"
      "size 800 600, title:^(stewart)$"
      "center, title:^(stewart)$"
	];
  };
}
