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
    ../../../modules/docker/immich
    ../../../modules/incus
    ../../../modules/build-machine
    # ../../../modules/terminal-server
  ];

  services.k3s.role = lib.mkForce "agent";

  # services.clubcotton.vnc.enable = true;

  # Use the systemd-boot EFI boot loader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  nix.settings.trusted-users = ["root" "builder"];

  networking = {
    useDHCP = false;
    hostName = "nix-02";
    hostId = "038f8559";
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
  services.tailscale.enable = true;

  virtualisation.libvirtd.enable = true;

  time.timeZone = "America/Denver";

  programs.zsh.enable = true;

  users.users.root = {
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIA51nSUvq7WevwvTYzD1S2xSr9QU7DVuYu3k/BGZ7vJ0 bob.cotton@gmail.com"
    ];
  };

  services.openssh.enable = true;
  # TODO
  networking.firewall.enable = false;
  system.stateVersion = "23.11"; # Did you read the comment?
}
