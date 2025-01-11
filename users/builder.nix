{
  config,
  pkgs,
  unstablePkgs,
  ...
}: {
  users.users.builder = {
    shell = pkgs.zsh;
    isNormalUser = true;
    home = "/home/builder";
    createHome = true;
    homeMode = "0700";
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIDU4dTkOKlaAeaNFiBgkZYxHhzZC3dskopYm7P2B/Zpx root@admin"
    ];
  };
}
