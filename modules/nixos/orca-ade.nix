{ pkgs, ... }:

let
  orcaAppImagePath = "/opt/orca-ade/orca-linux.AppImage";
  orcaLatestUrl = "https://github.com/stablyai/orca/releases/latest/download/orca-linux.AppImage";

  orcaAde = pkgs.writeShellScriptBin "orca-ade" ''
    set -euo pipefail

    if [ ! -x ${orcaAppImagePath} ]; then
      echo "Orca ADE AppImage is not installed yet." >&2
      echo "Run: sudo systemctl start orca-ade-update.service" >&2
      exit 1
    fi

    exec ${pkgs.appimage-run}/bin/appimage-run ${orcaAppImagePath} "$@"
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
  environment.systemPackages = [
    orcaAde
    orcaAlias
    orcaDesktop
  ];

  systemd.services.orca-ade-update = {
    description = "Install/update Orca ADE latest AppImage";
    wants = [ "network-online.target" ];
    after = [ "network-online.target" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = updateScript;
    };
  };

  systemd.timers.orca-ade-update = {
    description = "Periodically update Orca ADE to the latest release";
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnBootSec = "2min";
      OnCalendar = "hourly";
      RandomizedDelaySec = "15min";
      Persistent = true;
      Unit = "orca-ade-update.service";
    };
  };
}
