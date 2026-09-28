# Small monochrome SVGs for Waybar's GTK CSS backgrounds.
{ config, lib, pkgs, ... }:
{
  environment.etc = (lib.mapAttrs' (name: shapes: {
    name = "xdg/waybar/icons/${name}.svg";
    value.text = ''
      <svg xmlns="http://www.w3.org/2000/svg" width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="#202b3a" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round">
        ${shapes}
      </svg>
    '';
  }) {
    appmenu = ''<rect x="3.5" y="3.5" width="6" height="6" rx="1.5"/><rect x="14.5" y="3.5" width="6" height="6" rx="1.5"/><rect x="3.5" y="14.5" width="6" height="6" rx="1.5"/><rect x="14.5" y="14.5" width="6" height="6" rx="1.5"/>'';
    settings = ''<path d="M10 3h4l.5 2 1.7.7 1.8-1 2.3 2.3-1 1.8.7 1.7 2 .5v3.2l-2 .5-.7 1.7 1 1.8-2.3 2.3-1.8-1-1.7.7-.5 2h-4l-.5-2-1.7-.7-1.8 1-2.3-2.3 1-1.8-.7-1.7-2-.5V11l2-.5.7-1.7-1-1.8 2.3-2.3 1.8 1 1.7-.7z"/><circle cx="12" cy="12.6" r="2.5"/>'';
    cpu = ''<rect x="6" y="6" width="12" height="12" rx="2"/><path d="M9 2v4m6-4v4M9 18v4m6-4v4M2 9h4m-4 6h4m12-6h4m-4 6h4"/><rect x="10" y="10" width="4" height="4" rx="0.6" fill="#202b3a" stroke="none"/>'';
    memory = ''<rect x="3" y="7" width="18" height="10" rx="2"/><path d="M7 7V5m4 2V5m4 2V5m4 2V5M7 17v2m4-2v2m4-2v2m4-2v2M7 12h2m3 0h2m3 0h1"/>'';
    wifi = ''<path d="M2.5 9a15 15 0 0 1 19 0M5.7 12.7a10 10 0 0 1 12.6 0M8.9 16.3a5 5 0 0 1 6.2 0"/><circle cx="12" cy="19.5" r="1" fill="#202b3a" stroke="none"/>'';
    ethernet = ''<rect x="3" y="4" width="18" height="16" rx="3"/><path d="M8 4v5h8V4M12 9v5m-5 0h10m-10 0v3m10-3v3"/>'';
    offline = ''<path d="M3 9a15 15 0 0 1 17.5-1M6.4 12.5a10 10 0 0 1 6-1.6m2.2 1.1a10 10 0 0 1 3 1.5M9.5 16.3a5 5 0 0 1 4.5-.7M3 3l18 18"/>'';
    volume = ''<path d="M4 9.5h3.5L12 6v12l-4.5-3.5H4zM15.5 9a5 5 0 0 1 0 6M18.5 6a9 9 0 0 1 0 12"/>'';
    muted = ''<path d="M4 9.5h3.5L12 6v12l-4.5-3.5H4zM16 9l5 6m0-6-5 6"/>'';
  }) // {
    # Replace Fcitx's inconsistent tray icon with a small, live EN/KO label.
    "xdg/waybar/ime-status".source = pkgs.writeShellScript "waybar-ime-status" ''
      remote=${config.i18n.inputMethod.package}/bin/fcitx5-remote
      if ! "$remote" --check >/dev/null 2>&1; then
        printf '{"text":"–","tooltip":"입력기 연결 안 됨","class":"offline"}\n'
      elif [ "$("$remote" -n 2>/dev/null)" = hangul ]; then
        printf '{"text":"K","tooltip":"한글 입력 · 클릭하여 영어로 전환","class":"korean"}\n'
      else
        printf '{"text":"A","tooltip":"영문 입력 · 클릭하여 한글로 전환","class":"english"}\n'
      fi
    '';
  };
}
