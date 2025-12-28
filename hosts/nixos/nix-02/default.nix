# Edit this configuration file to define what should be installed on
# your system. Help is available in the configuration.nix(5) man page, on
# https://search.nixos.org/options and in the NixOS manual (`nixos-help`).
{
  config,
  pkgs,
  lib,
  unstablePkgs,
  hostName,
  ...
}: let
  # Get merged variables (defaults + host overrides)
  commonLib = import ../../common/lib.nix;
  variables = commonLib.getHostVariables hostName;
in {
  imports = [
    # Include the results of the hardware scan.
    ./hardware-configuration.nix
    ../../../modules/node-exporter
    ../../../modules/nfs
    ../../../modules/nix-builder
    ../../../modules/k3s-agent
    ../../../modules/incus
  ];

  services.clubcotton = {
    # vnc.enable = true;
    tailscale.enable = true;
    nut-client.enable = true;
    hyprland.enable = true;
  };

  # Create builder user for remote builds
  users.users.nix-builder = {
    isNormalUser = true;
    description = "Nix remote builder";
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIDqGI8tMC4OzuZB8mmYnPSQgIgZaDUglqdIqS9U4H5fT nix-builder@nas-0101"
    ];
  };

  nix.settings.trusted-users = ["nix-builder"];

  virtualisation.containers.enable = true;

  virtualisation.podman = {
    enable = true;
    dockerCompat = true;
    dockerSocket.enable = true;
    # Required for containers under podman-compose to be able to talk to each other.
    defaultNetwork.settings.dns_enabled = true;
  };

  services.k3s.role = lib.mkForce "agent";

  clubcotton.zfs_single_root = {
    enable = true;
    poolname = "rpool";
    swapSize = "64G";
    disk = "/dev/disk/by-id/nvme-eui.00000000000000000026b738281a43c5";
    useStandardRootFilesystems = true;
    reservedSize = "20GiB";
    volumes = {
      "local/incus" = {
        size = "300G";
      };
    };
  };

  # Use the systemd-boot EFI boot loader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  networking = {
    hostId = "038f8559";
    useDHCP = variables.useDHCP;
    hostName = hostName;
    defaultGateway = "192.168.5.1";
    nameservers = ["192.168.5.220"];
    interfaces.enp3s0.ipv4.addresses = [
      {
        address = "192.168.5.212";
        prefixLength = 24;
      }
    ];
    # interfaces.enp2s0.ipv4.addresses = [
    #   {
    #     address = "192.168.5.213";
    #     prefixLength = 24;
    #   }
    # ];
    bridges."br0".interfaces = ["enp2s0"];
    interfaces."br0".useDHCP = true;
  };
  services.tailscale.enable = variables.tailscaleEnable;

  virtualisation.libvirtd.enable = true;

  time.timeZone = variables.timeZone;

  programs.zsh.enable = variables.zshEnable;

  users.users.root = {
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIA51nSUvq7WevwvTYzD1S2xSr9QU7DVuYu3k/BGZ7vJ0 bob.cotton@gmail.com"
    ];
  };

  services.openssh.enable = variables.opensshEnable;
  # TODO
  networking.firewall.enable = variables.firewallEnable;
  system.stateVersion = "23.11"; # Did you read the comment?
}
