{ config, pkgs, ... }:

let
  # hyprpaper's contain mode uses a black canvas by default.
  hyprpaperWhite = pkgs.hyprpaper.overrideAttrs (old: {
    postPatch = (old.postPatch or "") + ''
      substituteInPlace src/ui/UI.cpp \
        --replace-fail 'CHyprColor{0xFF000000}' 'CHyprColor{0xFFFFFFFF}'
    '';
  });
in
{
  # Hyprland does not start XDG autostart entries on its own.
  i18n.inputMethod.fcitx5.settings.inputMethod = {
    GroupOrder."0" = "Default";
    "Groups/0" = {
      Name = "Default";
      "Default Layout" = "us";
      DefaultIM = "hangul";
    };
    "Groups/0/Items/0".Name = "keyboard-us";
    "Groups/0/Items/1" = {
      Name = "hangul";
      Layout = "us";
    };
  };
  systemd.user.services.fcitx5 = {
    description = "Fcitx5 input method";
    wantedBy = [ "graphical-session.target" ];
    partOf = [ "graphical-session.target" ];
    after = [ "graphical-session.target" ];
    serviceConfig.ExecStart = "${config.i18n.inputMethod.package}/bin/fcitx5";
  };

  environment.etc."xdg/waybar/config".text = ''
    {
      "layer": "top",
      "position": "top",
      "height": 38,
      "margin-top": 8,
      "margin-left": 14,
      "margin-right": 14,
      "spacing": 8,
      "modules-left": ["custom/appmenu", "hyprland/workspaces"],
      "modules-center": [],
      "modules-right": ["network", "pulseaudio", "tray", "clock"],
      "custom/appmenu": {
        "format": "앱 메뉴",
        "tooltip": "앱 목록 열기",
        "on-click": "${pkgs.wofi}/bin/wofi --show drun"
      },
      "hyprland/workspaces": {
        "disable-scroll": true,
        "all-outputs": true,
        "format": "{name}",
        "persistent-workspaces": {"*": 5}
      },
      "network": {
        "format-wifi": "◉  {essid}",
        "format-ethernet": "◆  Wired",
        "format-disconnected": "○  Offline",
        "tooltip": false
      },
      "pulseaudio": {
        "format": "{icon}  {volume}%",
        "format-muted": "Muted",
        "format-icons": {"default": ["♪", "♫"]},
        "on-click": "pavucontrol",
        "tooltip": false
      },
      "clock": {
        "format": "{:%a %b %d  ·  %H:%M}",
        "tooltip": false
      },
      "tray": {"spacing": 8}
    }
  '';
  environment.etc."xdg/waybar/style.css".text = ''
    * {
      font-family: "Noto Sans", "Noto Sans CJK KR", sans-serif;
      font-size: 13px;
      min-height: 0;
      border: none;
    }
    window#waybar {
      background: transparent;
      color: #f3f4f6;
    }
    .modules-left, .modules-center, .modules-right {
      background: rgba(25, 27, 32, 0.88);
      border: 1px solid rgba(255, 255, 255, 0.10);
      border-radius: 18px;
      padding: 0 10px;
    }
    #custom-appmenu {
      color: #ffffff;
      font-weight: 600;
      padding: 0 10px;
      border-radius: 12px;
    }
    #custom-appmenu:hover { background: rgba(255, 255, 255, 0.10); }
    #workspaces button {
      color: #aeb4c0;
      padding: 0 8px;
      border-radius: 12px;
      transition: all 120ms ease;
    }
    #workspaces button.active {
      color: #ffffff;
      background: rgba(255, 255, 255, 0.16);
    }
    #workspaces button:hover { background: rgba(255, 255, 255, 0.10); }
    #network, #pulseaudio, #tray, #clock { padding: 0 7px; }
    #clock { color: #ffffff; font-weight: 600; }
    tooltip {
      background: #20232a;
      border: 1px solid rgba(255,255,255,0.14);
      border-radius: 10px;
    }
  '';
  systemd.user.services.waybar = {
    description = "Waybar top panel";
    wantedBy = [ "graphical-session.target" ];
    partOf = [ "graphical-session.target" ];
    after = [ "graphical-session.target" ];
    serviceConfig = {
      Type = "exec";
      ExecStart = "${pkgs.waybar}/bin/waybar";
      Restart = "on-failure";
      RestartSec = 2;
    };
  };

  environment.etc."xdg/hypr/hyprpaper.conf".text = ''
    splash = false

    wallpaper {
      monitor =
      path = ${../../background}
      fit_mode = contain
      timeout = 60
      order = default
    }
  '';
  systemd.user.services.stringju-wallpaper = {
    description = "Rotate wallpapers with hyprpaper";
    wantedBy = [ "graphical-session.target" ];
    partOf = [ "graphical-session.target" ];
    after = [ "graphical-session.target" ];
    serviceConfig = {
      ExecStart = "${hyprpaperWhite}/bin/hyprpaper --config /etc/xdg/hypr/hyprpaper.conf";
      Restart = "on-failure";
      RestartSec = 3;
    };
  };
}
