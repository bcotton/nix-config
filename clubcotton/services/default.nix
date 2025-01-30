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
    ./kavita
    ./navidrome
    ./open-webui
    ./paperless
    ./roon-server
    ./sabnzbd
    ./webdav
  ];
}
