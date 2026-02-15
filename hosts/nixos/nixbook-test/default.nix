# Edit this configurat ion file to define what should be installed on
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
    # ../../common/toms-guinix/toms-hyprland.nix
    ../../common/toms-guinix/toms-desktop.nix
    ../../common/toms-guinix/toms-guipkgs.nix
    ../../common/toms-guinix/toms-proaudio.nix
  ];

  services.clubcotton = {
    alloy-logs.enable = true;
    tailscale.enable = true;
  };

  # === Audio Friendly Kernel Mods ===
  musnix.enable = true;
  users.users.tomcotton.extraGroups = ["audio"];
  boot.kernelPackages = pkgs.linuxPackages-rt_latest;

  # services.kmonad = {
  #   enable = true;
  #   keyboards = {
  #     nixbook-test = {
  #       device = "/dev/input/by-path/platform-i8042-serio-0-event-kbd";
  #       config = builtins.readFile ./toms-laptop-01.kbd;
  #     };
  #   };
  # };

  hardware.bluetooth.enable = true;
  hardware.bluetooth.powerOnBoot = true;

  virtualisation.containers.enable = true;
  virtualisation.podman = {
    enable = true;
    dockerCompat = true;
    dockerSocket.enable = true;
    # Required for containers under podman-compose to be able to talk to each other.
    defaultNetwork.settings.dns_enabled = true;
  };
  virtualisation.libvirtd.enable = true;

  clubcotton.zfs_single_root = {
    enable = true;
    poolname = "rpool";
    swapSize = "4G";
    disk = "/dev/disk/by-id/ata-PNY_120GB_SATA_SSD_PNF14222322460100851";
    useStandardRootFilesystems = true;
    reservedSize = "20GiB";
  };

  # Use the systemd-boot EFI boot loader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  nixpkgs.config.permittedInsecurePackages = [
    "broadcom-sta-6.30.223.271-57-6.12.40"
    "broadcom-sta-6.30.223.271-57-6.6.30-rt30"
    "broadcom-sta-6.30.223.271-57-5.15.183-rt85"
    "broadcom-sta-6.30.223.271-57-6.6.87-rt54"
    "broadcom-sta-6.30.223.271-59-6.6.112-rt63"
  ];

  networking = {
    hostName = "nixbook-test";
    hostId = "a8c01006";
    networkmanager.enable = true;

    # useDHCP = false;
    # defaultGateway = "192.168.5.1";
    # nameservers = ["192.168.5.220"];
    # interfaces.wlp0s20f0u1.ipv4.addresses = [
    #   {
    #     address = "192.168.5.16";
    #     prefixLength = 24;
    #   }
    # ];
  };

  # Set your time zone.
  time.timeZone = "America/Denver";

  programs.zsh.enable = true;

  users.users.root = {
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIKW08oClThlF1YJ+ey3y8XKm9yX/45EtaM/W7hx5Yvzb tomcotton@Toms-MacBook-Pro.local"
    ];
  };

  # Enable the OpenSSH daemon.
  services.openssh.enable = true;

  networking.firewall.enable = false;

  system.stateVersion = "25.05"; # Did you read the comment?
}
