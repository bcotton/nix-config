{
  lib,
  unstablePkgs,
  ...
}: {
  imports = [
    ./lidarr
    ./prowlarr
    ./radarr
    ./readarr
    ./sonarr
  ];
}
