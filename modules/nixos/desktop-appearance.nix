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
      "spacing": 6,
      "modules-left": ["custom/appmenu", "hyprland/workspaces"],
      "modules-center": [],
      "modules-right": ["network", "pulseaudio", "tray", "custom/settings", "clock"],
      "custom/settings": {
        "format": "설정",
        "tooltip": "환경설정 열기 (Super+I)",
        "on-click": "desktop-settings"
      },
      "custom/appmenu": {
        "format": "앱 메뉴",
        "tooltip": "앱 목록 열기",
        "on-click": "${pkgs.wofi}/bin/wofi --show drun --style /etc/xdg/wofi/style.css"
      },
      "hyprland/workspaces": {
        "disable-scroll": true,
        "all-outputs": true,
        "format": "{name}",
        "persistent-workspaces": {"*": 5}
      },
      "network": {
        "format-wifi": "{essid}",
        "format-ethernet": "유선",
        "format-disconnected": "오프라인",
        "tooltip": "네트워크 설정 열기",
        "on-click": "${pkgs.networkmanagerapplet}/bin/nm-connection-editor"
      },
      "pulseaudio": {
        "format": "{volume}%",
        "format-muted": "음소거",
        "on-click": "desktop-volume",
        "on-click-right": "${pkgs.pavucontrol}/bin/pavucontrol",
        "tooltip": "클릭: 소리 조절 · 우클릭: 출력 장치 설정 · 스크롤: 음량"
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
      background: rgba(247, 248, 250, 0.94);
      color: #202b3a;
      border-bottom: 1px solid #dce2e9;
    }
    .modules-left, .modules-right {
      background: transparent;
      border-radius: 10px;
    }
    .modules-left { padding-left: 10px; }
    .modules-right { padding-right: 12px; }
    #custom-appmenu {
      color: #202b3a;
      font-weight: 700;
      padding: 0 13px 0 32px;
      background-image: url("/etc/xdg/waybar/icons/appmenu.svg");
      background-size: 17px 17px;
      background-position: 10px center;
      background-repeat: no-repeat;
    }
    #custom-appmenu:hover, #workspaces button:hover,
    #network:hover, #pulseaudio:hover, #custom-settings:hover, #clock:hover {
      background-color: #e8eef6;
    }
    #workspaces button {
      color: #526175;
      padding: 0 11px;
      border-radius: 8px;
    }
    #workspaces button.active {
      color: #173d69;
      background: #dce9fa;
      font-weight: 700;
    }
    #network, #pulseaudio {
      padding: 0 9px 0 29px;
      background-size: 17px 17px;
      background-position: 8px center;
      background-repeat: no-repeat;
    }
    #network { background-image: url("/etc/xdg/waybar/icons/wifi.svg"); }
    #network.ethernet { background-image: url("/etc/xdg/waybar/icons/ethernet.svg"); }
    #network.disconnected { background-image: url("/etc/xdg/waybar/icons/offline.svg"); }
    #pulseaudio { background-image: url("/etc/xdg/waybar/icons/volume.svg"); }
    #pulseaudio.muted { background-image: url("/etc/xdg/waybar/icons/muted.svg"); }
    #custom-settings { padding: 0 11px; color: #334b68; font-weight: 600; }
    #clock { padding: 0 12px; }
    #tray { padding: 0 6px; }
    #clock { color: #202b3a; font-weight: 600; }
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
