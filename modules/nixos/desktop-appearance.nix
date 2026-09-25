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
      "height": 34,
      "spacing": 6,
      "modules-left": ["custom/appmenu", "hyprland/workspaces"],
      "modules-center": [],
      "modules-right": ["network", "pulseaudio", "tray", "clock"],
      "custom/appmenu": {
        "format": "<span font_family='Material Symbols Outlined' size='large'>apps</span>  앱 메뉴",
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
        "format-wifi": "<span font_family='Material Symbols Outlined' size='large'>wifi</span>  {essid}",
        "format-ethernet": "<span font_family='Material Symbols Outlined' size='large'>lan</span>  유선",
        "format-disconnected": "<span font_family='Material Symbols Outlined' size='large'>wifi_off</span>  오프라인",
        "tooltip": false
      },
      "pulseaudio": {
        "format": "{icon}  {volume}%",
        "format-muted": "<span font_family='Material Symbols Outlined' size='large'>volume_off</span>  음소거",
        "format-icons": {"default": [
          "<span font_family='Material Symbols Outlined' size='large'>volume_mute</span>",
          "<span font_family='Material Symbols Outlined' size='large'>volume_down</span>",
          "<span font_family='Material Symbols Outlined' size='large'>volume_up</span>"
        ]},
        "on-click": "pavucontrol",
        "tooltip": false
      },
      "clock": {
        "format": "{:%m월 %d일  %a  %H:%M}",
        "tooltip": false
      },
      "tray": {"spacing": 8}
    }
  '';
  environment.etc."xdg/waybar/style.css".text = ''
    * {
      font-family: "Pretendard JP", "Noto Sans CJK KR", sans-serif;
      font-size: 13px;
      min-height: 0;
      border: none;
    }
    window#waybar {
      background: transparent;
      color: #161616;
    }
    .modules-left, .modules-right {
      background: rgba(255, 255, 255, 0.12);
      border-radius: 20px;
    }
    .modules-left { padding-left: 10px; }
    .modules-right { padding-right: 12px; }
    #custom-appmenu {
      color: #161616;
      font-weight: 700;
      padding: 0 13px;
    }
    #custom-appmenu:hover, #workspaces button:hover,
    #network:hover, #pulseaudio:hover, #clock:hover {
      background: rgba(0, 0, 0, 0.08);
    }
    #workspaces button {
      color: #333333;
      padding: 0 9px;
      border-radius: 5px;
    }
    #workspaces button.active {
      color: #000000;
      background: rgba(0, 0, 0, 0.10);
      font-weight: 700;
    }
    #network, #pulseaudio, #clock { padding: 0 9px; }
    #tray { padding: 0 6px; }
    #clock { color: #161616; font-weight: 600; }
    tooltip {
      background: #20232a;
      color: #f4f5f7;
      border: 1px solid rgba(255, 255, 255, 0.18);
      border-radius: 6px;
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
