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
        "npm:@narumitw/pi-usage",
        "npm:@narumitw/pi-accounts",
        "npm:@narumitw/pi-btw"
      ]
    }
    EOF
  '';

  # Real `pi` binary on the system PATH so non-interactive consumers can spawn
  # pi. TUI mode comes from pi settings, so subcommands like `pi update` keep
  # their argv intact.
  pi = pkgs.writeShellApplication {
    name = "pi";
    runtimeInputs = [ pkgs.pnpm ];
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
    "d /home/${username}/.local/state/overlays/pi 0755 ${username} users -"
    "d /home/${username}/.local/state/overlays/pi/upper 0755 ${username} users -"
    "d /home/${username}/.local/state/overlays/pi/work 0755 ${username} users -"
  ];

  # Pi reads the package list from settings, but downloads npm packages itself.
  # Install them as the user at login so switch does not run npm as root.
  systemd.user.services.pi-package-install = {
    description = "Install configured Pi packages";
    wantedBy = [ "default.target" ];
    after = [ "network-online.target" ];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = pkgs.writeShellScript "install-pi-packages" ''
        set -eu
        ${pi}/bin/pi install npm:@juicesharp/rpiv-ask-user-question
        ${pi}/bin/pi install npm:pi-web-access
        ${pi}/bin/pi install npm:@narumitw/pi-usage
        ${pi}/bin/pi install npm:@narumitw/pi-accounts
        ${pi}/bin/pi install npm:@narumitw/pi-btw
      '';
    };
  };

  environment.systemPackages = [ pi ];
}
