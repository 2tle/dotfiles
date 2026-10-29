{ ... }:

{
  # Keep every WARP executable on the same upstream stable release, independently
  # of the nixpkgs channel. Shared by both hosts through common.nix.
  nixpkgs.overlays = [
    (final: prev:
      let
        # Verified 2026-10-23 against Cloudflare's Linux stable release page and
        # https://pkg.cloudflareclient.com/dists/noble/main/binary-{amd64,arm64}/Packages
        version = "2026.8.2115.0";
        sources = {
          x86_64-linux = final.fetchurl {
            url = "https://pkg.cloudflareclient.com/pool/noble/main/c/cloudflare-warp/cloudflare-warp_${version}_amd64.deb";
            hash = "sha256-AgkQeGDDxoUamrj9A2kBIaPeoxmbCE+Bl2IAcsZxzWg=";
          };
          aarch64-linux = final.fetchurl {
            url = "https://pkg.cloudflareclient.com/pool/noble/main/c/cloudflare-warp/cloudflare-warp_${version}_arm64.deb";
            hash = "sha256-5UiONZYdZpieag9ZGnTUgTbCP0UNyn020tVCa2Op7uI=";
          };
        };
      in
      {
        cloudflare-warp = prev.cloudflare-warp.overrideAttrs (old: {
          inherit version;
          src = sources.${final.stdenv.hostPlatform.system};

          # New upstream releases use TPM libraries and a WebKit taskbar UI.
          buildInputs = old.buildInputs ++ [
            final.tpm2-tss
            final.libayatana-appindicator
            final.webkitgtk_4_1
          ];
          # libjvm is an optional integration, not a required runtime dependency.
          autoPatchelfIgnoreMissingDeps = old.autoPatchelfIgnoreMissingDeps ++ [ "libjvm.so" ];

          # The pinned recipe points warp-dex at libpcap's development output.
          # Use its runtime output so diagnostics can actually load libpcap.
          installPhase = final.lib.replaceStrings
            [ "${final.libpcap}/lib/libpcap.so" ]
            [ "${final.lib.getLib final.libpcap}/lib/libpcap.so" ]
            old.installPhase;

          # Upstream now supplies the enrollment desktop entry itself.
          desktopItems = [ ];
          postInstall = old.postInstall + ''
            substituteInPlace $out/share/applications/com.cloudflare.WarpTaskbar.desktop \
                              $out/share/applications/com.cloudflare.warp.desktop \
              --replace-fail "Exec=" "Exec=$out"
            wrapProgram $out/bin/warp-taskbar --prefix LD_LIBRARY_PATH : $out/lib/warp/lib
          '';

          passthru = old.passthru // { inherit sources; };
          meta = old.meta // {
            platforms = builtins.attrNames sources;
            changelog = "https://github.com/cloudflare/cloudflare-docs/blob/production/src/content/warp-releases/linux/ga/${version}.yaml";
          };
        });
      })
  ];
}
