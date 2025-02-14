# Edit this configuration file to define what should be installed on
# your system. Help is available in the configuration.nix(5) man page, on
# https://search.nixos.org/options and in the NixOS manual (`nixos-help`).
{
  config,
  pkgs,
  lib,
  unstablePkgs,
  inputs,
  ...
}: {
  imports = [
    # Include the results of the hardware scan.
    ./hardware-configuration.nix
    ../../../modules/node-exporter
    ../../../modules/nfs
    # ../../../modules/k3s-agent
    # ../../../modules/docker/minecraft
    # ../../../modules/docker/audiobookshelf
  ];

  services.xserver.enable = true;
  services.displayManager.sddm.enable = true;
  services.desktopManager.plasma6.enable = true;

  virtualisation.containers.enable = true;
  virtualisation.podman = {
    enable = true;
    dockerCompat = true;
    dockerSocket.enable = true;
    # Required for containers under podman-compose to be able to talk to each other.
    defaultNetwork.settings.dns_enabled = true;
  };

  clubcotton.zfs_single_root = {
    enable = true;
    poolname = "rpool";
    swapSize = "4G";
    disk = "/dev/disk/by-id/wwn-0x5002538655584d30";
    useStandardRootFilesystems = true;
    reservedSize = "20GiB";
  };

  # Use the systemd-boot EFI boot loader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  networking = {
    useDHCP = true;
    hostName = "imac-01";
    hostId = "238f8e1e";
    defaultGateway = "192.168.5.1";
    nameservers = ["192.168.5.220"];
    interfaces.enp4s0f0.ipv4.addresses = [
      {
        address = "192.168.5.125";
        prefixLength = 24;
      }
    ];
    wireless.enable = true;
    wireless.userControlled.enable = true;
    wireless.secretsFile = config.age.secrets.wireless-config.path;
    wireless.networks = {
      "clubcotton2_5G" = {
        pskRaw = "ext:PSK";
      };
    };
  };

  services.tailscale.enable = true;

  # Set your time zone.
  time.timeZone = "America/Denver";

  programs.zsh.enable = true;

  users.users.root = {
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIA51nSUvq7WevwvTYzD1S2xSr9QU7DVuYu3k/BGZ7vJ0 bob.cotton@gmail.com"
    ];
  };

  # Enable the OpenSSH daemon.
  services.openssh.enable = true;

  networking.firewall.enable = false;

  virtualisation.libvirtd.enable = true;

  environment.systemPackages = with pkgs; [
    firefox
    code-cursor
  ];

  system.stateVersion = "24.11"; # Did you read the comment?
}
