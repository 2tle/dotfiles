{ config, lib, pkgs, ... }:

let
  bongocatFollowFocus = import ../../modules/nixos/bongocat-follow-focus.nix {
    inherit pkgs;
    bongocatPackage = config.programs.wayland-bongocat.package;
    keyboardName = builtins.head config.programs.wayland-bongocat.inputDeviceNames;
  };
in
{
  imports = [
    ./hardware-configuration.nix
    ../../modules/nixos/common.nix
    ../../modules/nixos/desktop-appearance.nix
  ];

  networking.hostName = "thinkpad-t14-gen2";

  # Use 100% scale on the built-in display.
  # External displays keep their automatic settings.
  environment.etc."xdg/hypr/hyprland.conf".text = lib.mkAfter ''
    monitor = eDP-1, preferred, auto, 1
    device {
      name = synps/2-synaptics-touchpad
      sensitivity = 0.6
    }
  '';

  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  # Client only: no forwarding, NAT, trusted WARP ingress or server ports.
  services.cloudflare-warp = {
    enable = true;
    openFirewall = false;
  };

  # Install the graphical Orca client; do not start orca-serve.
  programs.orca-ade.desktopEntry = true;

  # Follow the focused window across laptop and external displays instead of
  # pinning the cat to the display selected at startup.
  programs.wayland-bongocat = {
    enable = true;
    autostart = false;
    inputDevices = [ ];
    inputDeviceNames = [ "AT Translated Set 2 keyboard" ];
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

  # Bootloader
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
}
