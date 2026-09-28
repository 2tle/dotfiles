{ config, lib, pkgs, ... }:

let
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
    ../../modules/nixos/desktop-appearance.nix
  ];

  networking.hostName = "thinkpad-t14-gen2";

  # Only the laptop shows battery percentage in Waybar.
  stringju.waybar.battery.enable = true;
  environment.etc."xdg/waybar/icons/battery.svg".text = ''
    <svg xmlns="http://www.w3.org/2000/svg" width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="#202b3a" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round">
      <rect x="2" y="6" width="18" height="12" rx="2.5"/><path d="M22 10v4M5.5 9.5h9v5h-9z" fill="#202b3a" stroke="none"/>
    </svg>
  '';
  environment.etc."xdg/waybar/icons/battery-charging.svg".text = ''
    <svg xmlns="http://www.w3.org/2000/svg" width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="#202b3a" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round">
      <rect x="2" y="6" width="18" height="12" rx="2.5"/><path d="M22 10v4M12.5 8l-4 5h3l-1 3 4-5h-3z" fill="#202b3a" stroke="none"/>
    </svg>
  '';

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
    # The built-in keyboard and the attached USB keyboard both generate keys.
    inputDeviceNames = [ "AT Translated Set 2 keyboard" "USB Wired Keyboard" ];
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
