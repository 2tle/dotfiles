{ ... }:

{
  # Keep SSD TRIM queued instead of periodically blocking on a full-device trim.
  services.fstrim.enable = true;

  # Prefer interactive latency on this desktop; leave swap and memory reclaim
  # enabled rather than applying aggressive desktop-tuning sysctls.
  boot.kernel.sysctl = {
    "vm.swappiness" = 10;
    "vm.vfs_cache_pressure" = 50;
  };
}
