{ config, pkgs, ... }:

let
  wallpaperNames = builtins.filter (name: builtins.match ".*\\.png" name != null) (
    builtins.attrNames (builtins.readDir ../../background)
  );
  wallpaperPaths = builtins.map (name: "${../../background}/${name}") wallpaperNames;
  cozyPawsCursors = pkgs.runCommand "cozypaws-cursors" { nativeBuildInputs = [ pkgs.unzip ]; } ''
    unzip -q ${../../resources/CozyPaws-Hyprland-Full-PureSVG.zip} -d unpacked
    mkdir -p $out/share/icons
    cp -r unpacked/CozyPaws-Cursors/CozyPaws \
      unpacked/CozyPaws-Cursors/CozyPaws-XCursor $out/share/icons/
  '';
  desktopSettings = pkgs.writeShellScriptBin "desktop-settings" ''
    set -euo pipefail
    choice="$(${pkgs.coreutils}/bin/printf '%s\n' \
      '네트워크' '소리 및 출력 장치' '디스플레이' '외관' '키보드 · 한글 입력' \
      | ${pkgs.wofi}/bin/wofi --show dmenu --prompt '환경설정' --width 400 --height 330 --style /etc/xdg/wofi/style.css)" || exit 0
    case "$choice" in
      '네트워크') exec ${pkgs.networkmanagerapplet}/bin/nm-connection-editor ;;
      '소리 및 출력 장치') exec ${pkgs.pavucontrol}/bin/pavucontrol ;;
      '디스플레이') exec ${pkgs.wdisplays}/bin/wdisplays ;;
      '외관') exec ${pkgs.nwg-look}/bin/nwg-look ;;
      '키보드 · 한글 입력') exec ${pkgs.kdePackages.fcitx5-configtool}/bin/fcitx5-configtool ;;
    esac
  '';
  desktopVolume = pkgs.writeShellScriptBin "desktop-volume" ''
    set -euo pipefail
    volume="$(${pkgs.wireplumber}/bin/wpctl get-volume @DEFAULT_AUDIO_SINK@)"
    choice="$(${pkgs.coreutils}/bin/printf '%s\n' \
      "현재: $volume" '음소거 전환' \
      '0%' '10%' '20%' '30%' '40%' '50%' '60%' '70%' '80%' '90%' '100%' \
      '소리 및 출력 장치 설정' \
      | ${pkgs.wofi}/bin/wofi --show dmenu --prompt '소리 조절' --width 320 --height 420 --style /etc/xdg/wofi/style.css)" || exit 0
    case "$choice" in
      '음소거 전환') ${pkgs.wireplumber}/bin/wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle ;;
      '소리 및 출력 장치 설정') exec ${pkgs.pavucontrol}/bin/pavucontrol ;;
      [0-9]*%) ${pkgs.wireplumber}/bin/wpctl set-volume --limit 1.0 @DEFAULT_AUDIO_SINK@ "$choice" ;;
    esac
  '';
  settingsLauncher = pkgs.makeDesktopItem {
    name = "desktop-settings";
    desktopName = "환경설정";
    comment = "네트워크, 소리, 디스플레이, 외관 및 입력기";
    exec = "${desktopSettings}/bin/desktop-settings";
    icon = "preferences-system";
    categories = [ "Settings" ];
  };
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
    ./waybar-icons.nix
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
    bind = SUPER, D, exec, wofi --show drun --style /etc/xdg/wofi/style.css
    bind = SUPER, I, exec, desktop-settings
    exec-once = hyprctl setcursor CozyPaws 32
  '';

  # System-wide Kitty default; user config can override it.
  environment.etc."xdg/kitty/kitty.conf".text = ''
    background_opacity 0.75
  '';

  # Prefer native Wayland for Chromium/Electron applications
  environment.sessionVariables = {
    NIXOS_OZONE_WL = "1";
    HYPRCURSOR_THEME = "CozyPaws";
    HYPRCURSOR_SIZE = "32";
    XCURSOR_THEME = "CozyPaws-XCursor";
    XCURSOR_SIZE = "32";
  };

  # Use the matching XCursor theme for X11 and GTK apps.
  environment.etc."icons/default/index.theme".text = ''
    [Icon Theme]
    Inherits=CozyPaws-XCursor
  '';
  environment.etc."gtk-3.0/settings.ini".text = ''
    [Settings]
    gtk-cursor-theme-name=CozyPaws-XCursor
    gtk-cursor-theme-size=32
    gtk-font-name=Pretendard JP 11
  '';
  environment.etc."gtk-4.0/settings.ini".text = ''
    [Settings]
    gtk-cursor-theme-name=CozyPaws-XCursor
    gtk-cursor-theme-size=32
    gtk-font-name=Pretendard JP 11
  '';

  # A consistent launcher style for the app search, settings and volume menus.
  environment.etc."xdg/wofi/style.css".text = ''
    * { font-family: "Pretendard JP", "Noto Sans CJK KR", sans-serif; font-size: 14px; }
    window {
      background-color: #f7f8fa;
      color: #202b3a;
      border: 1px solid #dce2e9;
      border-radius: 16px;
    }
    #outer-box { margin: 14px; }
    #input {
      margin-bottom: 12px;
      padding: 10px 14px;
      background-color: #ffffff;
      color: #202b3a;
      border: 1px solid #dce2e9;
      border-radius: 10px;
    }
    #scroll { margin-top: 2px; }
    #entry {
      padding: 9px 12px;
      border-radius: 9px;
    }
    #entry:selected { background-color: #dce9fa; color: #173d69; }
    #text { color: #202b3a; }
    #text:selected { color: #173d69; }
  '';

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

  # Korean, emoji, and consistent outlined icons for Waybar.
  fonts.fontconfig.defaultFonts.sansSerif = [ "Pretendard JP" "Noto Sans CJK KR" ];
  fonts.packages = with pkgs; [
    pretendard-jp
    noto-fonts
    noto-fonts-cjk-sans
    noto-fonts-color-emoji
    material-symbols
  ];

  # System packages shared by machines
  environment.systemPackages = with pkgs; [
    catppuccinLogin
    cozyPawsCursors

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
    desktopSettings
    desktopVolume
    settingsLauncher
    wdisplays
    nwg-look
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
