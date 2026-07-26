{ config, pkgs, ... }:

{
  # Networking
  networking.networkmanager.enable = true;

  # Time zone
  time.timeZone = "Asia/Seoul";

  # Locale
  i18n.defaultLocale = "en_US.UTF-8";

  i18n.extraLocaleSettings = {
    LC_ADDRESS = "ko_KR.UTF-8";
    LC_IDENTIFICATION = "ko_KR.UTF-8";
    LC_MEASUREMENT = "ko_KR.UTF-8";
    LC_MONETARY = "ko_KR.UTF-8";
    LC_NAME = "ko_KR.UTF-8";
    LC_NUMERIC = "ko_KR.UTF-8";
    LC_PAPER = "ko_KR.UTF-8";
    LC_TELEPHONE = "ko_KR.UTF-8";
    LC_TIME = "ko_KR.UTF-8";
  };

  # Korean input with Fcitx5
  i18n.inputMethod = {
    enable = true;
    type = "fcitx5";

    fcitx5 = {
      waylandFrontend = true;
      addons = with pkgs; [
        fcitx5-hangul
        fcitx5-gtk
      ];
    };
  };

  # Display manager
  services.displayManager.sddm = {
    enable = true;
    wayland.enable = true;
  };

  # Hyprland
  programs.hyprland = {
    enable = true;
    withUWSM = true;
  };

  # System-wide Hyprland keybindings
  environment.etc."xdg/hypr/hyprland.conf".text = ''
    bind = SUPER, E, exec, kitty -e mc
  '';

  # Prefer native Wayland for Chromium/Electron applications
  environment.sessionVariables = {
    NIXOS_OZONE_WL = "1";
  };

  # Printing
  services.printing.enable = true;

  # File manager support: trash, mounts, thumbnails, etc.
  services.gvfs.enable = true;
  services.tumbler.enable = true;

  # Audio with PipeWire
  services.pulseaudio.enable = false;
  security.rtkit.enable = true;

  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
  };

  # User account
  users.users.stringju = {
    isNormalUser = true;
    description = "stringju";
    extraGroups = [
      "networkmanager"
      "wheel"
    ];
  };

  # Firefox can remain installed alongside Chrome
  programs.firefox.enable = true;

  # Required for Google Chrome and other unfree packages
  nixpkgs.config.allowUnfree = true;

  # Korean and emoji fonts
  fonts.packages = with pkgs; [
    noto-fonts
    noto-fonts-cjk-sans
    noto-fonts-color-emoji
  ];

  # System packages shared by machines
  environment.systemPackages = with pkgs; [
    # Development tools
    vim
    wget
    git
    gh
    github-desktop
    nodejs
    pi-coding-agent

    # Browser
    google-chrome

    # Fcitx5 configuration GUI
    kdePackages.fcitx5-configtool

    # Basic Hyprland desktop utilities
    kitty
    waybar
    wofi
    dunst
    hyprpaper
    wl-clipboard
    grim
    slurp
    pavucontrol
    brightnessctl
    playerctl
    networkmanagerapplet

    # Terminal file manager
    mc
  ];

  # Keep this at the release used for the first installation.
  system.stateVersion = "26.05";
}
