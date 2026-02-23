{
  modulesPath,
  lib,
  ...
}: {
  imports = [
    "${modulesPath}/virtualisation/lxc-container.nix"
  ];

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
}
