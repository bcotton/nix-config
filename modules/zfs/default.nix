{
  config,
  lib,
  pkgs,
  ...
}: {
  imports = [
    ./zfs-single-root.nix
    ./zfs-mirrored-root.nix
    ./zfs-raidz1.nix
    ./monitoring.nix
  ];

  services.sanoid = {
    enable = true;
    templates.backup = {
      hourly = 36;
      daily = 30;
      monthly = 3;
      autoprune = true;
      autosnap = true;
    };
    templates.media = {
      hourly = 0;
      daily = 30;
      monthly = 6;
      autoprune = true;
      autosnap = true;
    };
  };

  services.prometheus.exporters =
    lib.mkIf (
      config.clubcotton.zfs_single_root.enable
      or false
      || config.clubcotton.zfs_mirrored_root.enable or false
      || config.clubcotton.zfs_raidz1.enable or false
    ) {
      zfs = {
        enable = true;
      };
      smartctl = {
        enable = true;
        # Devices will be auto-discovered, but can be explicitly configured per host
        maxInterval = "60s";
      };
    };
}
