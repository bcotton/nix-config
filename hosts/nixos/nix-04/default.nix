# Edit this configuration file to define what should be installed on
# your system. Help is available in the configuration.nix(5) man page, on
# https://search.nixos.org/options and in the NixOS manual (`nixos-help`).
#
# Nuke and pave this machine
# nix run github:nix-community/nixos-anywhere -- --flake '.#nix-04' root@<host ip>
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
    ../../../modules/incus
  ];

  services.clubcotton = {
    freshrss.enable = false;
    paperless.enable = false;
    filebrowser.enable = false;
    tailscale.enable = true;
  };
  # services.clubcotton.services.tailscale.enable = variables.tailscaleEnable;

  clubcotton.zfs_single_root.enable = true;

  virtualisation.podman.enable = true;
  virtualisation.libvirtd.enable = true;

  programs.zsh.enable = variables.zshEnable;
  services.openssh.enable = variables.opensshEnable; # Enable the OpenSSH daemon.

  services.clubcotton.freshrss = {
    port = 8104;
    passwordFile = config.age.secrets."freshrss".path;
    authType = "form";
    extensions = with pkgs.freshrss-extensions; [youtube];
    tailnetHostname = "freshrss";
  };

  services.clubcotton.paperless = {
    mediaDir = "/var/lib/paperless/media";
    configDir = "/var/lib/paperless";
    consumptionDir = "/var/lib/paperless/consume";
    passwordFile = config.age.secrets."paperless".path;
    database.createLocally = true;
    tailnetHostname = "paperless";
  };

  users.users.root = {
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIKW08oClThlF1YJ+ey3y8XKm9yX/45EtaM/W7hx5Yvzb tomcotton@Toms-MacBook-Pro.local"
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIA51nSUvq7WevwvTYzD1S2xSr9QU7DVuYu3k/BGZ7vJ0 bob.cotton@gmail.com"
    ];
  };

  virtualisation.podman = {
    dockerSocket.enable = true;
    dockerCompat = true;
    autoPrune.enable = true;
    # Required for containers under podman-compose to be able to talk to each other.
    defaultNetwork.settings.dns_enabled = true;
  };

  clubcotton.zfs_single_root = {
    poolname = "rpool";
    swapSize = "4G"; # 1/4 of 16G
    disk = "/dev/disk/by-id/ata-X12_SSD_256GB_KT2023000020001117";
    useStandardRootFilesystems = true;
    reservedSize = "50GiB"; #0.20 of 256G
  };

  networking = {
    hostId = "3fa4e0cb";
    hostName = "nix-04";
    defaultGateway = "192.168.12.1";
    nameservers = ["192.168.12.1"];
    useDHCP = false;
    bridges."br0".interfaces = ["eno1"];
    interfaces."br0".useDHCP = true;
    #interfaces."br0".ipv4.addresses = [
    #  {
    #    address = "192.168.12.54";
    #    prefixLength = 24;
    #  }
    #];
  };

  # Pick only one of the below networking options.
  # networking.wireless.enable = true;  # Enables wireless support via wpa_supplicant.
  # networking.networkmanager.enable = true;  # Easiest to use and most distros use this by default.

  # Set your time zone.
  time.timeZone = variables.timeZone;

  # Enable touchpad support (enabled default in most desktopManager).
  # services.xserver.libinput.enable = true;

  # Open ports in the firewall.
  # networking.firewall.allowedTCPPorts = [ ... ];
  # networking.firewall.allowedUDPPorts = [ ... ];
  # Or disable the firewall altogether.
  networking.firewall.enable = variables.firewallEnable;

  # Copy the NixOS configuration file and link it from the resulting system
  # (/run/current-system/configuration.nix). This is useful in case you
  # accidentally delete configuration.nix.
  # system.copySystemConfiguration = true;

  # This option defines the first version of NixOS you have installed on this particular machine,
  # and is used to maintain compatibility with application data (e.g. databases) created on older NixOS versions.
  #
  # Most users should NEVER change this value after the initial install, for any reason,
  # even if you've upgraded your system to a new NixOS release.
  #
  # This value does NOT affect the Nixpkgs version your packages and OS are pulled from,
  # so changing it will NOT upgrade your system.
  #
  # This value being lower than the current NixOS release does NOT mean your system is
  # out of date, out of support, or vulnerable.
  #
  # Do NOT change this value unless you have manually inspected all the changes it would make to your configuration,
  # and migrated your data accordingly.
  #
  # For more information, see `man configuration.nix` or https://nixos.org/manual/nixos/stable/options#opt-system.stateVersion .
  system.stateVersion = "24.11"; # Did you read the comment?
}
