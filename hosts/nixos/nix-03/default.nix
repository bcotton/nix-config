# Edit this configuration file to define what should be installed on
# your system. Help is available in the configuration.nix(5) man page, on
# https://search.nixos.org/options and in the NixOS manual (`nixos-help`).
{
  config,
  pkgs,
  lib,
  unstablePkgs,
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
    tailscale.enable = true;
    nut-client.enable = true;
  };

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
    disk = "/dev/disk/by-id/nvme-eui.00000000000000000026b738281a3535";
    useStandardRootFilesystems = true;
    reservedSize = "20GiB";
    volumes = {
      "local/incus" = {
        size = "300G";
      };
    };
  };

  networking = {
    hostId = "007f0200";
    useDHCP = false;
    hostName = "nix-03";
    defaultGateway = "192.168.5.1";
    nameservers = ["192.168.5.220"];
    interfaces.enp3s0.ipv4.addresses = [
      {
        address = "192.168.5.214";
        prefixLength = 24;
      }
    ];
    # interfaces.enp2s0.ipv4.addresses = [
    #   {
    #     address = "192.168.5.215";
    #     prefixLength = 24;
    #   }
    # ];
    bridges."br0".interfaces = ["enp2s0"];
    interfaces."br0".useDHCP = true;
  };

  virtualisation.libvirtd.enable = true;

  # Pick only one of the below networking options.
  # networking.wireless.enable = true;  # Enables wireless support via wpa_supplicant.
  # networking.networkmanager.enable = true;  # Easiest to use and most distros use this by default.

  # Set your time zone.
  time.timeZone = "America/Denver";

  # Enable touchpad support (enabled default in most desktopManager).
  # services.xserver.libinput.enable = true;

  programs.zsh.enable = true;

  users.users.root = {
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIA51nSUvq7WevwvTYzD1S2xSr9QU7DVuYu3k/BGZ7vJ0 bob.cotton@gmail.com"
    ];
  };

  # An attemp at a headless x server
  services.x2goserver.enable = true;

  # Enable the OpenSSH daemon.
  services.openssh = {
    enable = true;
    settings = {
      X11Forwarding = true;
    };
  };

  networking.firewall.enable = false;
  system.stateVersion = "23.11"; # Did you read the comment?
}
