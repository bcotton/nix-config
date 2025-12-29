# Edit this configuration file to define what should be installed on
# your system. Help is available in the configuration.nix(5) man page, on
# https://search.nixos.org/options and in the NixOS manual (`nixos-help`).
#
# Nuke and pave this machine
# nix run github:nix-community/nixos-anywhere -- --flake '.#condo-01' root@<host ip>
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
    tailscale.enable = true;
  };

  clubcotton.zfs_single_root.enable = true;
  virtualisation.podman.enable = true;
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

  programs.zsh.enable = variables.zshEnable;
  services.openssh.enable = variables.opensshEnable;

  services.clubcotton.tailscale = {
    useRoutingFeatures = "server";
    extraSetFlags = [
      "--advertise-routes=192.168.5.0/24"
      "--accept-routes"
    ];
  };

  users.users.root = {
    openssh.authorizedKeys.keys = [
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
    hostName = "condo-01";
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
  time.timeZone = variables.timeZone;

  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
    # If you want to use JACK applications, uncomment this
    #jack.enable = true;
  };

  services.xserver = {
    enable = true;
    desktopManager = {
      xterm.enable = false;
      xfce.enable = true;
    };
  };
  services.displayManager.defaultSession = "xfce";

  services.displayManager.autoLogin = {
    enable = true;
    user = "media";
  };

  users.users.media = {
    isNormalUser = true;
    packages = with pkgs; [
      jellyfin-media-player
    ];
  };

  services.caddy = {
    enable = true;
    virtualHosts.":8096".extraConfig = ''
      bind 0.0.0.0
      reverse_proxy http://100.88.184.98:8096
    '';
    virtualHosts.":8112".extraConfig = ''
      bind 0.0.0.0
      reverse_proxy http://100.88.184.98:8112
    '';
  };

  # Enable touchpad support (enabled default in most desktopManager).
  # services.xserver.libinput.enable = true;

  # Open ports in the firewall.
  # networking.firewall.allowedTCPPorts = [ ... ];
  # networking.firewall.allowedUDPPorts = [ ... ];
  # Or disable the firewall altogether.
  networking.firewall.enable = variables.firewallEnable;

  system.stateVersion = "24.11"; # Did you read the comment?
}
