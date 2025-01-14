{
  lib,
  unstablePkgs,
  ...
}: {
  imports = [
    ./arr
    ./calibre
    ./jellyfin
    ./open-webui
    ./roon-server
    ./sabnzbd
  ];
}
