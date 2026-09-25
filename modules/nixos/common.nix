{ config, pkgs, ... }:

let
  wallpaperNames = builtins.filter (name: builtins.match ".*\\.png" name != null) (
    builtins.attrNames (builtins.readDir ../../background)
  );
  wallpaperPaths = builtins.map (name: "${../../background}/${name}") wallpaperNames;
  catppuccinLogin = (pkgs.catppuccin-sddm.override {
    loginBackground = true;
    clockEnabled = false;
  }).overrideAttrs (old: {
    postInstall = (old.postInstall or "") + ''
      # Pick one of the Nix-store wallpapers each time the SDDM greeter starts.
      substituteInPlace "$out/share/sddm/themes/catppuccin-mocha-mauve/Main.qml" \
        --replace-fail 'color: "#1E1E2E"' 'color: "#FFFFFF"' \
        --replace-fail 'fillMode: Image.PreserveAspectCrop' 'fillMode: Image.PreserveAspectFit' \
        --replace-fail 'source: config.Background' \
          'source: ${builtins.toJSON wallpaperPaths}[Math.floor(Math.random() * ${toString (builtins.length wallpaperPaths)})]'
    '';
  });
in
{
  imports = [
    ./performance.nix
    ./pi.nix
    ./orca-ade.nix
  ];

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

  # Display manager: rotate the existing wallpapers on each login screen.
  services.displayManager.sddm = {
    enable = true;
    wayland.enable = true;
    theme = "catppuccin-mocha-mauve";
    extraPackages = [ catppuccinLogin ];
  };

  # Hyprland
  programs.hyprland = {
    enable = true;
    withUWSM = true;
  };

  # System-wide Hyprland keybindings
  environment.etc."xdg/hypr/hyprland.conf".text = ''
    misc:focus_on_activate = true
    bind = SUPER, Return, exec, kitty
    bind = SUPER, E, exec, kitty -e mc
    bind = SUPER, Q, killactive,
  '';

  # System-wide Kitty default; user config can override it.
  environment.etc."xdg/kitty/kitty.conf".text = ''
    background_opacity 0.75
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
    catppuccinLogin

    # Development tools
    vim
    wget
    git
    gh
    github-desktop
    vscode
    nodejs
    pnpm

    # Browser and chat (Discord provides a .desktop entry for Wofi's app menu)
    google-chrome
    discord

    # Fcitx5 configuration GUI
    kdePackages.fcitx5-configtool

    # Basic Hyprland desktop utilities
    kitty
    waybar
    wofi
    dunst
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
