{
  lib,
  unstablePkgs,
  ...
}: {
  imports = [
    ./lidarr
    ./prowlarr
    ./radarr
    ./readarr-multi
    ./readarr
    ./sonarr
  ];
}
