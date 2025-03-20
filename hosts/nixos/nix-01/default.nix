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
    ../../../modules/k3s-agent
  ];

  services.clubcotton = {
    code-server.enable = true;
    nut-client.enable = true;
    bonob.enable = true;
  };

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
    swapSize = "64G";
    disk = "/dev/disk/by-id/nvme-eui.00000000000000000026b738281a1aa5";
    useStandardRootFilesystems = true;
    reservedSize = "20GiB";
    volumes = {
      "local/incus" = {
        size = "300G";
      };
    };
  };

  services.k3s.role = lib.mkForce "agent";

  # Use the systemd-boot EFI boot loader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  networking = {
    useDHCP = false;
    hostName = "nix-01";
    hostId = "85c6dbc0";
    defaultGateway = "192.168.5.1";
    nameservers = ["192.168.5.220"];
    interfaces.enp3s0.ipv4.addresses = [
      {
        address = "192.168.5.210";
        prefixLength = 24;
      }
    ];
    # interfaces.enp2s0.ipv4.addresses = [
    #   {
    #     address = "192.168.5.211";
    #     prefixLength = 24;
    #   }
    # ];
    bridges."br0".interfaces = ["enp2s0"];
    interfaces."br0".useDHCP = true;
  };
  services.tailscale.enable = true;

  services.clubcotton.code-server = {
    tailnetHostname = "nix-01-vscode";
    user = "bcotton";
  };

  services.clubcotton.bonob = {
    sonosSeedHost = "192.168.5.96";
    url = "http://192.168.5.210:3000/";
    subsonicUrl = "http://nas-01.lan:${toString config.services.navidrome.settings.Port}/";
  };

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

  system.stateVersion = "23.11"; # Did you read the comment?
}
