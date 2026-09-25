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
  '';

  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  # Client only: no forwarding, NAT, trusted WARP ingress or server ports.
  services.cloudflare-warp = {
    enable = true;
    openFirewall = false;
  };

  # Install the graphical Orca client; do not start orca-serve.
  programs.orca-ade.desktopEntry = true;

  # Keyboard device name varies by ThinkPad revision. Install Bongo Cat but
  # don't auto-start it until bongocat-find-devices identifies the keyboard.
  programs.wayland-bongocat.enable = true;

  # Bootloader
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
}
