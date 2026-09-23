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

  bongocatFollowFocus = pkgs.writeScript "bongocat-follow-focus" ''
    #!${pkgs.python3}/bin/python3
    import json
    import os
    import signal
    import socket
    import subprocess
    import sys
    import time

    BONGOCAT = "${config.programs.wayland-bongocat.package}/bin/bongocat"
    CONFIG = os.path.join(os.environ.get("XDG_RUNTIME_DIR", "/tmp"), "bongocat-follow-focus.conf")
    last_config = None
    last_monitor = None
    child = None

    def hypr_socket(name):
        runtime = os.environ.get("XDG_RUNTIME_DIR")
        sig = os.environ.get("HYPRLAND_INSTANCE_SIGNATURE")
        if not runtime or not sig:
            raise RuntimeError("Hyprland runtime variables are missing")
        return os.path.join(runtime, "hypr", sig, name)

    def hypr_json(command):
        with socket.socket(socket.AF_UNIX, socket.SOCK_STREAM) as sock:
            sock.connect(hypr_socket(".socket.sock"))
            sock.sendall(("j/" + command).encode())
            chunks = []
            while True:
                chunk = sock.recv(65536)
                if not chunk:
                    break
                chunks.append(chunk)
        return json.loads(b"".join(chunks).decode() or "null")

    def pick_target():
        window = hypr_json("activewindow") or {}
        monitors = hypr_json("monitors") or []
        if not monitors:
            return "", 0

        center_x = None
        center_y = None
        if window.get("mapped", True) and window.get("at") and window.get("size"):
            center_x = window["at"][0] + window["size"][0] / 2
            center_y = window["at"][1] + window["size"][1] / 2

        monitor = None
        if center_x is not None:
            for mon in monitors:
                if (mon["x"] <= center_x < mon["x"] + mon["width"] and
                        mon["y"] <= center_y < mon["y"] + mon["height"]):
                    monitor = mon
                    break
        if monitor is None:
            monitor = next((mon for mon in monitors if mon.get("focused")), monitors[0])
            center_x = monitor["x"] + monitor["width"] / 2

        x_offset = round(center_x - (monitor["x"] + monitor["width"] / 2))
        return monitor.get("name", ""), x_offset

    def render_config():
        monitor, x_offset = pick_target()
        text = f"""# Auto-generated. Follow the focused Hyprland window.
    cat_x_offset={x_offset}
    cat_y_offset=0
    cat_height=80
    cat_align=center
    mirror_x=0
    mirror_y=0
    enable_antialiasing=1
    overlay_position=top
    overlay_height=60
    overlay_opacity=0
    layer=top
    idle_frame=0
    keypress_duration=150
    test_animation_duration=200
    test_animation_interval=0
    fps=60
    enable_hand_mapping=1
    idle_sleep_timeout=0
    enable_scheduled_sleep=0
    sleep_begin=22:00
    sleep_end=06:00
    enable_debug=0
    monitor={monitor}
    keyboard_name=USB Wired Keyboard
    hotplug_scan_interval=30
    """
        return monitor, text

    def write_config_and_maybe_restart():
        global last_config, last_monitor, child
        try:
            monitor, text = render_config()
        except Exception as exc:
            print(f"bongocat-follow-focus: {exc}", file=sys.stderr)
            return
        if text != last_config:
            tmp = CONFIG + ".tmp"
            with open(tmp, "w") as f:
                f.write(text)
            os.replace(tmp, CONFIG)
            last_config = text
        if child is None or child.poll() is not None or monitor != last_monitor:
            if child is not None and child.poll() is None:
                child.terminate()
                try:
                    child.wait(timeout=2)
                except subprocess.TimeoutExpired:
                    child.kill()
            child = subprocess.Popen([BONGOCAT, "--watch-config", "--config", CONFIG])
            last_monitor = monitor

    def shutdown(signum, frame):
        if child is not None and child.poll() is None:
            child.terminate()
        raise SystemExit(0)

    signal.signal(signal.SIGTERM, shutdown)
    signal.signal(signal.SIGINT, shutdown)
    write_config_and_maybe_restart()

    while True:
        try:
            with socket.socket(socket.AF_UNIX, socket.SOCK_STREAM) as events:
                events.connect(hypr_socket(".socket2.sock"))
                buf = b""
                while True:
                    chunk = events.recv(4096)
                    if not chunk:
                        break
                    buf += chunk
                    while b"\n" in buf:
                        line, buf = buf.split(b"\n", 1)
                        if line.startswith((b"activewindow>>", b"movewindow>>", b"resizewindow>>", b"monitorfocused>>", b"workspace>>")):
                            write_config_and_maybe_restart()
        except Exception as exc:
            print(f"bongocat-follow-focus: reconnecting after {exc}", file=sys.stderr)
            time.sleep(1)
            write_config_and_maybe_restart()
  '';
in
{
  imports = [
    ./hardware-configuration.nix
    ../../modules/nixos/common.nix
  ];

  networking.hostName = "stringju-work";

  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  boot.kernel.sysctl = {
    "net.ipv4.ip_forward" = 1;
  };

  # NAT all forwarded traffic arriving over WARP and leaving via the wired
  # uplink, so replies return through this host. Routing policy controls which
  # destinations the WARP clients send here.
  networking.nftables = {
    enable = true;
    ruleset = ''
      table inet deny-public-ingress {
        chain input {
          type filter hook input priority -10; policy accept;
          iifname "enp2s0" drop
        }
      }

      table ip warp-forward {
        chain postrouting {
          type nat hook postrouting priority srcnat; policy accept;
          iifname "CloudflareWARP" oifname "enp2s0" masquerade
        }
      }
    '';
  };

  # WARP is the only trusted ingress interface. Explicitly drop every packet
  # addressed to this host arriving on the public wired NIC (enp2s0), including
  # SSH; this is enforced before the standard NixOS firewall chains.
  networking.firewall = {
    enable = true;
    trustedInterfaces = [ "CloudflareWARP" ];
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

  # A restrained macOS-inspired top bar; intentionally no dock.
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
