{ config, lib, pkgs, ... }:

let
  orcaAppImagePath = "/opt/orca-ade/orca-linux.AppImage";
  orcaLatestUrl = "https://github.com/stablyai/orca/releases/latest/download/orca-linux.AppImage";

  # Orca rebuilds terminal PATH inside its FHS environment. Provide pi in
  # /usr/bin (which Orca keeps on PATH), delegating to the active NixOS system
  # so switching generations does not leave a stale store path behind.
  piShim = pkgs.writeShellScriptBin "pi" ''
    exec /run/current-system/sw/bin/pi "$@"
  '';

  orcaRunner = pkgs.appimage-run.override {
    # nixpkgs' FHS profile prefixes the terminal prompt with
    # "appimage-run-fhsenv:"; Orca terminals should show the real user/host.
    appimageTools = pkgs.appimageTools // {
      defaultFhsEnvArgs = pkgs.appimageTools.defaultFhsEnvArgs // {
        profile = ''export PS1='\u@\h:\w\$ ' '';
      };
    };
    extraPkgs = p: [ p.git p.gh p.procps p.xorg-server p.systemd piShim ];
  };

  orcaAde = pkgs.writeShellScriptBin "orca-ade" ''
    set -euo pipefail

    if [ ! -x ${orcaAppImagePath} ]; then
      echo "Orca ADE AppImage is not installed yet." >&2
      echo "Run: sudo systemctl start orca-ade-update.service" >&2
      exit 1
    fi

    # AppImage's AppRun replaces PATH; keep host tools visible to Orca and its
    # subprocesses (notably git, ps, Xvfb and systemd-run).
    export PATH="${pkgs.lib.makeBinPath [ pkgs.git pkgs.gh pkgs.procps pkgs.xorg-server pkgs.systemd ]}:$PATH"
    exec ${orcaRunner}/bin/appimage-run ${orcaAppImagePath} "$@"
  '';

  orcaAlias = pkgs.writeShellScriptBin "orca" ''
    exec ${orcaAde}/bin/orca-ade "$@"
  '';

  orcaDesktop = pkgs.makeDesktopItem {
    name = "orca-ade";
    desktopName = "Orca ADE";
    genericName = "Agent Development Environment";
    comment = "Run multiple AI coding agents in parallel";
    exec = "${orcaAde}/bin/orca-ade %U";
    terminal = false;
    categories = [ "Development" ];
  };

  updateScript = pkgs.writeShellScript "orca-ade-update" ''
    set -euo pipefail

    install -d -m 0755 /opt/orca-ade
    tmp="$(${pkgs.coreutils}/bin/mktemp -p /opt/orca-ade .orca-linux.AppImage.XXXXXX)"
    cleanup() {
      [ ! -e "$tmp" ] || rm -f "$tmp"
    }
    trap cleanup EXIT

    ${pkgs.curl}/bin/curl \
      --fail \
      --location \
      --retry 3 \
      --retry-delay 2 \
      --connect-timeout 20 \
      --output "$tmp" \
      ${orcaLatestUrl}

    chmod 0755 "$tmp"

    if [ ! -e ${orcaAppImagePath} ] || ! ${pkgs.diffutils}/bin/cmp -s "$tmp" ${orcaAppImagePath}; then
      mv -f "$tmp" ${orcaAppImagePath}
      trap - EXIT
      echo "Orca ADE updated from ${orcaLatestUrl}"
    else
      echo "Orca ADE is already up to date"
    fi
  '';
in
{
  options.programs.orca-ade.desktopEntry = lib.mkEnableOption "Orca ADE graphical client launcher";

  config = {
    environment.systemPackages = [
      orcaAde
      orcaAlias
    ] ++ lib.optional config.programs.orca-ade.desktopEntry orcaDesktop;

    systemd.services.orca-ade-update = {
      description = "Install/update Orca ADE latest AppImage";
      wants = [ "network-online.target" ];
      after = [ "network-online.target" ];
      # Upgrades are manual: replacing the binary under a running server can
      # invalidate restored sessions or change the remote protocol unexpectedly.
      serviceConfig = {
        Type = "oneshot";
        ExecStart = updateScript;
      };
    };
  };
}
