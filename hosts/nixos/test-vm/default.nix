# Test VM configuration - uses bcotton user from the full flake
{
  pkgs,
  lib,
  modulesPath,
  ...
}: {
  imports = [
    (modulesPath + "/profiles/qemu-guest.nix")
    (modulesPath + "/virtualisation/qemu-vm.nix")
  ];

  # Boot configuration for VM
  boot.loader.grub.device = lib.mkDefault "/dev/vda";
  boot.initrd.availableKernelModules = ["virtio_pci" "virtio_blk" "9p" "9pnet_virtio"];
  boot.initrd.kernelModules = ["virtio_balloon" "virtio_console" "virtio_rng"];

  fileSystems."/" = {
    device = "/dev/vda";
    fsType = "ext4";
  };

  # Shared folder for accessing the flake from host
  fileSystems."/mnt/flake" = {
    device = "shared";
    fsType = "9p";
    options = ["trans=virtio" "version=9p2000.L" "msize=104857600" "nofail"];
  };

  networking.useDHCP = true;
  networking.firewall.enable = false;

  # Passwordless sudo for testing
  security.sudo.wheelNeedsPassword = false;

  # Auto-login as bcotton for convenience
  services.getty.autologinUser = "bcotton";

  services.openssh.enable = true;

  # VM-specific settings
  virtualisation = {
    memorySize = 4096;
    cores = 2;
    diskSize = 10240;
    graphics = false;
    forwardPorts = [{from = "host"; host.port = 2222; guest.port = 22;}];
  };

  system.stateVersion = "24.11";
}
