{
  lib,
  unstablePkgs,
  ...
}: {
  imports = [
    ./arr
    ./calibre
    ./calibre-web
    ./jellyfin
    ./open-webui
    ./roon-server
    ./sabnzbd
    ./webdav
  ];
}
