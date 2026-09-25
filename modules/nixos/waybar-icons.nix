# Small monochrome SVGs for Waybar's GTK CSS backgrounds.
{ lib, ... }:
{
  environment.etc = lib.mapAttrs' (name: shapes: {
    name = "xdg/waybar/icons/${name}.svg";
    value.text = ''
      <svg xmlns="http://www.w3.org/2000/svg" width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="#161616" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
        ${shapes}
      </svg>
    '';
  }) {
    appmenu = ''<rect x="3" y="3" width="7" height="7" rx="1"/><rect x="14" y="3" width="7" height="7" rx="1"/><rect x="3" y="14" width="7" height="7" rx="1"/><rect x="14" y="14" width="7" height="7" rx="1"/>'';
    wifi = ''<path d="M2 8a16 16 0 0 1 20 0M5 12a11 11 0 0 1 14 0M8.5 16a6 6 0 0 1 7 0"/><circle cx="12" cy="20" r="1" fill="#161616" stroke="none"/>'';
    ethernet = ''<rect x="3" y="3" width="18" height="18" rx="2"/><path d="M8 3v6h8V3M7 21v-6h10v6M10 9v6m4-6v6"/>'';
    offline = ''<path d="M2 8a16 16 0 0 1 20 0M5 12a11 11 0 0 1 14 0M8.5 16a6 6 0 0 1 7 0M3 3l18 18"/>'';
    volume = ''<path d="M4 9v6h4l5 4V5L8 9H4zm13-1a6 6 0 0 1 0 8m2-11a10 10 0 0 1 0 14"/>'';
    muted = ''<path d="M4 9v6h4l5 4V5L8 9H4zm13 0 5 6m0-6-5 6"/>'';
  };
}
