{ pkgs, ... }:

let
  username = "stringju";
  dotfilesDir = "/home/${username}/nix/dotfiles";
  piPackageConfig = pkgs.runCommand "pi-package-config" { } ''
    mkdir -p "$out/agent"
    cat > "$out/agent/settings.json" <<'EOF'
    {
      "packages": [
        "npm:@juicesharp/rpiv-ask-user-question",
        "npm:pi-web-access",
        "npm:pi-subagents",
        "npm:@narumitw/pi-usage",
        "npm:@narumitw/pi-accounts",
        "npm:@narumitw/pi-btw",
        "npm:@2tle/pi-provider-manager",
        "npm:@amaster.ai/pi-image-gen",
        "npm:@henryqw/pi-subagent",
        "npm:rpiv-todo",
        "npm:pi-powerline-footer",
        "npm:pi-docparser",
        "npm:@plannotator/pi-extension@0.20.3",
        "npm:omp-designer",
        "npm:@xynogen/pix-optimizer"
      ]
    }
    EOF
  '';

  # Real `pi` binary on the system PATH so non-interactive consumers can spawn
  # pi. TUI mode comes from pi settings, so subcommands like `pi update` keep
  # their argv intact.
  pi = pkgs.writeShellApplication {
    name = "pi";
    runtimeInputs = [ pkgs.nodejs pkgs.pnpm ];
    text = ''
      exec pnpx --allow-build=@google/genai --allow-build=protobufjs --allow-build=esbuild @earendil-works/pi-coding-agent@latest "$@"
    '';
  };
in
{
  # Keep the mount unit's lowerdir stable across rebuilds. A Nix store path
  # here changes whenever piPackageConfig is rebuilt, causing systemd to try
  # to reload the live overlay mount (which overlayfs does not support).
  environment.etc."pi-package-config".source = piPackageConfig;

  fileSystems."/home/${username}/.pi" = {
    overlay = {
      lowerdir = [ "/etc/pi-package-config" "${dotfilesDir}/.pi" ];
      upperdir = "/home/${username}/.local/state/overlays/pi/upper";
      workdir = "/home/${username}/.local/state/overlays/pi/work";
    };
  };

  systemd.tmpfiles.rules = [
    "d ${dotfilesDir}/.pi 0755 ${username} users -"
    "d /home/${username}/.pi 0755 ${username} users -"
    # The mount hides the directory created before it. Its root can inherit
    # root ownership from a lower layer, making Pi's mkdir ~/.pi/agent fail.
    # Fix the mounted root itself (without recursively changing private files).
    "z /home/${username}/.pi 0755 ${username} users -"
    "d /home/${username}/.pi/agent 0755 ${username} users -"
    "d /home/${username}/.local/state/overlays/pi 0755 ${username} users -"
    "d /home/${username}/.local/state/overlays/pi/upper 0755 ${username} users -"
    "d /home/${username}/.local/state/overlays/pi/work 0755 ${username} users -"
  ];

  # Pi downloads npm packages itself. Run its CLI as the user from the
  # activation script on every switch (never as root).
  systemd.services.pi-package-install = {
    description = "Install configured Pi packages";
    wants = [ "network-online.target" ];
    after = [ "network-online.target" ];
    environment.HOME = "/home/${username}";
    # @plannotator/webtui pulls in node-pty, which runs node-gyp on Linux.
    # The service does not inherit the interactive shell's PATH.
    path = [ pkgs.nodejs pkgs.pnpm pkgs.python3 pkgs.gcc pkgs.gnumake ];
    serviceConfig = {
      Type = "oneshot";
      User = username;
      ExecStart = pkgs.writeShellScript "install-pi-packages" ''
        set -eu
        ${pi}/bin/pi install npm:@juicesharp/rpiv-ask-user-question
        ${pi}/bin/pi install npm:pi-web-access
        ${pi}/bin/pi install npm:pi-subagents
        ${pi}/bin/pi install npm:@narumitw/pi-usage
        ${pi}/bin/pi install npm:@narumitw/pi-accounts
        ${pi}/bin/pi install npm:@narumitw/pi-btw
        ${pi}/bin/pi install npm:@2tle/pi-provider-manager
        ${pi}/bin/pi install npm:@amaster.ai/pi-image-gen
        ${pi}/bin/pi install npm:@henryqw/pi-subagent
        ${pi}/bin/pi install npm:rpiv-todo
        ${pi}/bin/pi install npm:pi-powerline-footer
        ${pi}/bin/pi install npm:pi-docparser
        # Newer releases pull in node-pty via @plannotator/webtui; its native
        # addon build fails on the ThinkPad (missing napi.h).
        ${pi}/bin/pi install npm:@plannotator/pi-extension@0.20.3
        ${pi}/bin/pi install npm:omp-designer
        ${pi}/bin/pi install npm:@xynogen/pix-optimizer
      '';
    };
  };

  system.activationScripts.installPiPackages.text = ''
    ${pkgs.systemd}/bin/systemctl start --no-block pi-package-install.service || true
  '';

  # Also expose node-gyp's toolchain to interactive `npm install` / `pi install`.
  # The Pi extension invokes `rtk rewrite`; expose the same binary to Pi and
  # interactive shells on every host.
  environment.systemPackages = [ pi pkgs.rtk pkgs.python3 pkgs.gcc pkgs.gnumake ];
}
