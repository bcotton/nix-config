{
  config,
  lib,
  options,
  ...
}:
with lib; let
  cfg = config.services.clubcotton.garage;
in {
  config = mkIf (cfg.enable && cfg.zfsDataset != null) (
    lib.optionalAttrs (options ? disko) {
      disko.zfs.settings.datasets.${cfg.zfsDataset.name} = {
        inherit (cfg.zfsDataset) properties;
      };
    }
  );
}
