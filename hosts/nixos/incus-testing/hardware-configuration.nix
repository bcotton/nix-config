{
  modulesPath,
  lib,
  ...
}: {
  imports = [
    "${modulesPath}/virtualisation/incus-virtual-machine.nix"
  ];

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
}
