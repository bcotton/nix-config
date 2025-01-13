{
  lib,
  unstablePkgs,
  ...
}: {
  imports = [
    ./arr
    ./jellyfin
    ./open-webui
    ./roon-server
    ./sabnzbd
  ];
}
