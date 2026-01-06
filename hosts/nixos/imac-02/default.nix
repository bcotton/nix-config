# Edit this configuration file to define what should be installed on
# your system. Help is available in the configuration.nix(5) man page, on
# https://search.nixos.org/options and in the NixOS manual (`nixos-help`).
{
  config,
  pkgs,
  lib,
  unstablePkgs,
  inputs,
  hostName,
  ...
}: let
  # Get merged variables (defaults + host overrides)
  commonLib = import ../../common/lib.nix;
  variables = commonLib.getHostVariables hostName;
  keys = import ../../common/keys.nix;
in {
  imports = [
    # Include the results of the hardware scan.
    ./hardware-configuration.nix
    ../../../modules/node-exporter
    ../../../modules/nfs
  ];

  services.clubcotton = {
    scanner.enable = true;
    tailscale.enable = true;
  };

  services.xserver.enable = true;
  services.displayManager.sddm.enable = true;
  services.desktopManager.plasma6.enable = true;
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
  virtualisation.libvirtd = {
    enable = true;
    qemu = {
      package = pkgs.qemu_kvm;
      ovmf = {
        enable = true;
        packages = [pkgs.OVMFFull.fd];
      };
    };
  };

  clubcotton.zfs_single_root = {
    enable = true;
    poolname = "rpool";
    swapSize = "4G";
    disk = "/dev/disk/by-id/nvme-Samsung_SSD_970_EVO_Plus_2TB_S59CNM0R836896T";
    useStandardRootFilesystems = true;
    reservedSize = "20GiB";
  };

  # Use the systemd-boot EFI boot loader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  networking = {
    hostName = "imac-02";
    hostId = "95c41ddc";

    useDHCP = false;
    defaultGateway = "192.168.5.1";
    nameservers = ["192.168.5.220"];
    interfaces.enp4s0f0.ipv4.addresses = [
      {
        address = "192.168.5.153";
        prefixLength = 24;
      }
    ];
  };

  # Set your time zone.
  time.timeZone = variables.timeZone;

  programs.zsh.enable = variables.zshEnable;

  users.users.root = {
    openssh.authorizedKeys.keys = keys.rootAuthorizedKeys;
  };

  # Enable the OpenSSH daemon.
  services.openssh.enable = variables.opensshEnable;

  networking.firewall.enable = variables.firewallEnable;

  environment.systemPackages = with pkgs; [
    firefox
    code-cursor
  ];

  system.stateVersion = "24.11"; # Did you read the comment?
}
