{ config, pkgs, lib, ... }:

{
  imports = [
    ./binds.nix
    ./autostart.nix
    ./animations.nix
    ./monitors.nix
    ./window-rules.nix

    ./hypridle.nix
  ];

  wayland.windowManager.hyprland.enable = true;

  home.packages = with pkgs; [
    rofi
    pavucontrol
    fortune
    alsa-utils
    awww
    networkmanager_dmenu
    wl-clipboard
    fd
    qt6.qtmultimedia
    qt6.qt5compat
    ripgrep
    gtk3
    cava
    cliphist
    hyprlock
    tree
    jq
    socat 
    pamixer 
    brightnessctl
    acpi
    iw

    bluez
    libnotify
    networkmanager
    lm_sensors

    socat
    bc
    pulseaudio
    ladspaPlugins
    ladspa-sdk
    imagemagick
  ];
  wayland.windowManager.hyprland.settings = {
    general = {
      border_size = 0;
      gaps_in = 4;
      gaps_out = 4;
      float_gaps = 6;
      resize_on_border = true;
      extend_border_grab_area = 30;

    };
    decoration = {
      rounding = 4;
      active_opacity = 1.0;
      inactive_opacity = 1.0;
      blur = {
        enabled = false;
      };
      shadow = {
        enabled = false;
      };
    };
    input = {
      kb_layout = "us, ru";
      kb_variant = "";
      kb_model = "";
      kb_rules = "";
      touchpad = {
        natural_scroll = true;
      };
      accel_profile = "flat";
    };
    misc = {
      font_family = "JetBrains Mono";
      disable_hyprland_logo = true;
      disable_splash_rendering = true;
      focus_on_activate = true;
    };
  };

  home.sessionVariables.NIXOS_OZONE_WL = "1";
  home.file.".config/hypr/scripts".source =
  config.lib.file.mkOutOfStoreSymlink
    "/etc/nixos/config/sessions/hyprland/scripts";
}
