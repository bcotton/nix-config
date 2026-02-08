{
  config,
  lib,
  ...
}:
with lib; let
  cfg = config.services.clubcotton.garage;
in {
  config = mkIf (cfg.enable && cfg.zfsDataset != null) {
    disko.zfs.settings.datasets.${cfg.zfsDataset.name} = {
      inherit (cfg.zfsDataset) properties;
    };
  };
}
