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
        "npm:@2tle/pi-provider-manager"
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
  fileSystems."/home/${username}/.pi" = {
    overlay = {
      lowerdir = [ "${piPackageConfig}" "${dotfilesDir}/.pi" ];
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
    path = [ pkgs.nodejs pkgs.pnpm ];
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
      '';
    };
  };

  system.activationScripts.installPiPackages.text = ''
    ${pkgs.systemd}/bin/systemctl start --no-block pi-package-install.service || true
  '';

  environment.systemPackages = [ pi ];
}
