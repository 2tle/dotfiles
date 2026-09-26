{ config, lib, pkgs, ... }:

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

  # Keep the cat above the Waybar panel; match the built-in keyboard by name
  # rather than relying on an unstable /dev/input/event number.
  programs.wayland-bongocat = {
    enable = true;
    autostart = true;
    layer = "overlay";
    catXOffset = 0;
    catHeight = 80;
    inputDevices = [ ];
    inputDeviceNames = [ "AT Translated Set 2 keyboard" ];
  };
  users.users.stringju.extraGroups = [ "input" ];

  # Bootloader
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
}
