{ config, pkgs, ... }:

let
  # hyprpaper's contain mode uses an opaque black canvas by default. Patch only
  # that canvas to white so square images retain their ratio with white bars.
  hyprpaperWhite = pkgs.hyprpaper.overrideAttrs (old: {
    postPatch = (old.postPatch or "") + ''
      substituteInPlace src/ui/UI.cpp \
        --replace-fail 'CHyprColor{0xFF000000}' 'CHyprColor{0xFFFFFFFF}'
    '';
  });

  bongocatFollowFocus = import ../../modules/nixos/bongocat-follow-focus.nix {
    inherit pkgs;
    bongocatPackage = config.programs.wayland-bongocat.package;
    keyboardNames = config.programs.wayland-bongocat.inputDeviceNames;
  };
in
{
  imports = [
    ./hardware-configuration.nix
    ../../modules/nixos/common.nix
  ];

  networking.hostName = "stringju-work";

  # Decrypt sops-nix secrets with this machine's existing SSH host key.
  sops.age.sshKeyPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];
  environment.systemPackages = with pkgs; [ sops age ssh-to-age ];

  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  boot.kernel.sysctl = {
    "net.ipv4.ip_forward" = 1;
  };

  networking.nftables = {
    enable = true;
    ruleset = ''
      # Conntrack runs before priority -10. Never drop replies to connections
      # initiated by this machine through its public address.
      table ip public-ingress {
        chain input {
          type filter hook input priority -10; policy accept;
          iifname != "lo" ip daddr 115.145.150.233 ct state != { established, related } drop
        }
      }

      # Only forwarded WARP client traffic needs NAT; locally initiated traffic
      # already leaves via the wired interface with its public source address.
      table ip warp-forward {
        chain postrouting {
          type nat hook postrouting priority srcnat; policy accept;
          iifname "CloudflareWARP" oifname "enp2s0" masquerade
        }
      }
    '';
  };

  # WARP is the only trusted ingress interface. The public-ingress chain above
  # drops unsolicited IPv4 input (including ping) to the public address, even
  # if another service later opens a port in the standard NixOS firewall.
  networking.firewall = {
    enable = true;
    trustedInterfaces = [ "CloudflareWARP" ];
    allowPing = false;
    allowedTCPPorts = [ ];
    allowedUDPPorts = [ ];
  };

  # SSH is reachable only through the trusted Cloudflare WARP interface above.
  services.openssh = {
    enable = true;
    openFirewall = false;
    settings = {
      PasswordAuthentication = true;
      KbdInteractiveAuthentication = true;
      PermitRootLogin = "no";
    };
  };

  # Keep the Orca daemon and its terminal scopes in this user's session even
  # when nobody is logged into the graphical desktop.
  users.users.stringju.linger = true;

  systemd.services.orca-serve = {
    description = "Orca remote server over Cloudflare WARP";
    wantedBy = [ "multi-user.target" ];
    wants = [ "network-online.target" "cloudflare-warp.service" ];
    after = [ "network-online.target" "cloudflare-warp.service" ];
    startLimitIntervalSec = 300;
    startLimitBurst = 10;
    serviceConfig = {
      Type = "simple";
      User = "stringju";
      WorkingDirectory = "/home/stringju";
      Environment = "LIBGL_ALWAYS_SOFTWARE=1";
      KillMode = "mixed";
      Restart = "on-failure";
      RestartPreventExitStatus = 3; # Existing desktop instance owns the profile.
      RestartSec = 10;
      ExecStart = pkgs.writeShellScript "orca-serve" ''
        set -eu
        # WARP can connect after network-online; advertise its current address,
        # not a public IP or localhost. Never expose Orca on the public NIC.
        for attempt in $(${pkgs.coreutils}/bin/seq 1 60); do
          address="$(${pkgs.iproute2}/bin/ip -4 -o addr show dev CloudflareWARP 2>/dev/null | ${pkgs.gawk}/bin/awk '{ split($4, parts, "/"); print parts[1]; exit }')"
          if [ -n "$address" ]; then
            exec ${config.system.path}/bin/orca-ade serve --port 6768 --pairing-address "$address"
          fi
          ${pkgs.coreutils}/bin/sleep 5
        done
        echo "Orca: Cloudflare WARP address unavailable" >&2
        exit 1
      '';
    };
  };

  # The shared module installs Fcitx5 and fcitx5-hangul; make both English and
  # Korean available in the default group on this host.
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

  # Hyprland does not start XDG autostart entries on its own.
  systemd.user.services.fcitx5 = {
    description = "Fcitx5 input method";
    wantedBy = [ "graphical-session.target" ];
    partOf = [ "graphical-session.target" ];
    after = [ "graphical-session.target" ];
    serviceConfig.ExecStart = "${config.i18n.inputMethod.package}/bin/fcitx5";
  };

  # Edge-to-edge menu bar inspired by macOS; intentionally no dock.
  environment.etc."xdg/waybar/config".text = ''
    {
      "layer": "top",
      "position": "top",
      "height": 38,
      "spacing": 6,
      "modules-left": ["custom/appmenu", "hyprland/workspaces"],
      "modules-center": [],
      "modules-right": ["network", "pulseaudio", "custom/ime", "custom/settings", "clock"],
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
        "format-wifi": " ",
        "format-ethernet": " ",
        "format-disconnected": " ",
        "tooltip-format-wifi": "{essid} · 신호 {signalStrength}% · 클릭: 네트워크 설정",
        "tooltip-format-ethernet": "유선 연결 · 클릭: 네트워크 설정",
        "tooltip-format-disconnected": "오프라인 · 클릭: 네트워크 설정",
        "on-click": "${pkgs.networkmanagerapplet}/bin/nm-connection-editor"
      },
      "pulseaudio": {
        "format": " ",
        "format-muted": " ",
        "tooltip-format": "음량 {volume}% · 클릭: 소리 조절 · 우클릭: 출력 장치 · 스크롤: 음량",
        "tooltip-format-muted": "음소거 · 클릭: 소리 조절 · 우클릭: 출력 장치",
        "on-click": "desktop-volume",
        "on-click-right": "${pkgs.pavucontrol}/bin/pavucontrol"
      },
      "custom/ime": {
        "exec": "/etc/xdg/waybar/ime-status",
        "return-type": "json",
        "format": "{text}",
        "interval": 1,
        "on-click": "${config.i18n.inputMethod.package}/bin/fcitx5-remote -t",
        "on-click-right": "${pkgs.kdePackages.fcitx5-configtool}/bin/fcitx5-configtool"
      },
      "clock": {
        "format": "{:%m월 %d일  %a  %H:%M}",
        "tooltip": false
      }
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
    #network:hover, #pulseaudio:hover, #custom-ime:hover, #custom-settings:hover, #clock:hover {
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
      min-width: 26px;
      padding: 0 3px;
      background-size: 17px 17px;
      background-position: center;
      background-repeat: no-repeat;
    }
    #network { background-image: url("/etc/xdg/waybar/icons/wifi.svg"); }
    #network.ethernet { background-image: url("/etc/xdg/waybar/icons/ethernet.svg"); }
    #network.disconnected { background-image: url("/etc/xdg/waybar/icons/offline.svg"); }
    #pulseaudio { background-image: url("/etc/xdg/waybar/icons/volume.svg"); }
    #pulseaudio.muted { background-image: url("/etc/xdg/waybar/icons/muted.svg"); }
    #custom-ime {
      min-width: 21px;
      padding: 0 4px;
      color: #202b3a;
      font-size: 12px;
      font-weight: 700;
    }
    #custom-ime.offline { color: #8793a3; }
    #custom-settings { padding: 0 11px; color: #334b68; font-weight: 600; }
    #clock { padding: 0 12px; }
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

  # This profile matches any wired NIC. If the PC has more than one, set
  # connection."interface-name" to the intended interface before applying.
  networking.networkmanager.ensureProfiles.profiles.stringju-work-wired = {
    connection = {
      id = "stringju-work-wired";
      type = "ethernet";
      autoconnect = "true";
      autoconnect-priority = "100";
    };
    ipv4 = {
      method = "manual";
      address1 = "115.145.150.233/24";
      gateway = "115.145.150.1";
      # /32 does not include the gateway: mark the route as on-link.
      dns = "8.8.8.8;";
      ignore-auto-dns = "true";
      dns-priority = "-10000";
    };
    ipv6 = {
      method = "auto";
      ignore-auto-dns = "true";
    };
  };

  # Keep bootloader and disk-specific settings in hardware-configuration.nix
  # (or add them here after checking the actual machine).
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  # hyprpaper handles directory scanning and its 60-second timer internally;
  # no runtime shell or sleep loop is involved.
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
    description = "Rotate stringju-work wallpapers with hyprpaper";
    wantedBy = [ "graphical-session.target" ];
    partOf = [ "graphical-session.target" ];
    after = [ "graphical-session.target" ];
    serviceConfig = {
      ExecStart = "${hyprpaperWhite}/bin/hyprpaper --config /etc/xdg/hypr/hyprpaper.conf";
      Restart = "on-failure";
      RestartSec = 3;
    };
  };

  programs.wayland-bongocat = {
    enable = true;
    # A custom service below keeps the cat centered over the focused Hyprland
    # window, so disable the module's static autostart service.
    autostart = false;
    inputDeviceNames = [ "USB Wired Keyboard" ];
  };
  systemd.user.services.wayland-bongocat-follow-focus = {
    description = "Wayland Bongo Cat Overlay following the focused Hyprland window";
    wantedBy = [ "graphical-session.target" ];
    partOf = [ "graphical-session.target" ];
    after = [ "graphical-session.target" ];
    serviceConfig = {
      Type = "exec";
      ExecStart = bongocatFollowFocus;
      Restart = "on-failure";
      RestartSec = 2;
    };
  };
  users.users.stringju.extraGroups = [ "input" ];

  # Installs warp-cli and keeps the WARP daemon available at boot. Device
  # registration is intentionally local state under /var/lib/cloudflare-warp.
  services.cloudflare-warp = {
    enable = true;
    openFirewall = false;
  };

}
