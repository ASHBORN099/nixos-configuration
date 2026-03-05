{ config, lib, ... }:

{
  wayland.windowManager.hyprland.settings = {

    # ─────────────────────────────
    # Layer rules (OSD / overlays)
    # ─────────────────────────────
    layerrule = [
      "noanim, ^(volume_osd)$"
      "noanim, ^(brightness_osd)$"
      "noanim, ^(usb_popup)$"
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

      # ───────── App Launcher ─────────
      "float, title:^(app-launcher)$"
      "center, title:^(app-launcher)$"
      "size 1200 600, title:^(app-launcher)$"
      "animation slide, title:^(app-launcher)$"

      # ───────── MASTER QUICKSHELL CONTAINER ─────────
      # All widgets now live inside this single, shape-shifting window.
      "float, title:^(qs-master)$"
      "pin, title:^(qs-master)$"
      "noshadow, title:^(qs-master)$"
      "noborder, title:^(qs-master)$"
    ];
  };
}
