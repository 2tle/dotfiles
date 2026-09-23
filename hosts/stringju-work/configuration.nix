{ pkgs, ... }:

let
  # hyprpaper's contain mode uses an opaque black canvas by default. Patch only
  # that canvas to white so square images retain their ratio with white bars.
  hyprpaperWhite = pkgs.hyprpaper.overrideAttrs (old: {
    postPatch = (old.postPatch or "") + ''
      substituteInPlace src/ui/UI.cpp \
        --replace-fail 'CHyprColor{0xFF000000}' 'CHyprColor{0xFFFFFFFF}'
    '';
  });
in
{
  imports = [
    ./hardware-configuration.nix
    ../../modules/nixos/common.nix
  ];

  networking.hostName = "stringju-work";

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
      address1 = "115.145.150.233/32";
      # /32 does not include the gateway: mark the route as on-link.
      route1 = "0.0.0.0/0,115.145.150.1";
      route1_options = "onlink=true";
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
    autostart = true;
    # Run bongocat-find-devices on this PC and set inputDeviceNames if
    # automatic detection does not pick the correct keyboard.
  };
  users.users.stringju.extraGroups = [ "input" ];

  programs.omp.enable = true;

  # Installs warp-cli and keeps the WARP daemon available at boot. Device
  # registration is intentionally local state under /var/lib/cloudflare-warp.
  services.cloudflare-warp = {
    enable = true;
    openFirewall = true;
  };
}
