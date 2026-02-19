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
  keys = import ../../common/keys.nix;
in {
  imports = [
    # Include the results of the hardware scan.
    ./hardware-configuration.nix
    ../../../modules/node-exporter
    ../../../modules/nfs
    # nix-builder client is enabled via flake-modules/hosts.nix
    ../../../modules/incus
    ../../../modules/systemd-network
  ];

  services.clubcotton = {
    alloy-logs.enable = true;
    tailscale.enable = true;
    nut-client.enable = true;

    auto-upgrade = {
      enable = true;
      flake = "git+https://forgejo.bobtail-clownfish.ts.net/bcotton/nix-config?ref=main";
      dates = "03:00";
      healthChecks = {
        pingTargets = ["192.168.5.1" "192.168.5.220"];
        services = ["sshd" "tailscaled"];
        tcpPorts = [
          {port = 22;}
        ];
        extraScript = ''
          incus cluster list --format csv | awk -F, '{if ($3 != "ONLINE") exit 1}'
        '';
      };
    };
    forgejo-runner = {
      enable = true;
      instances = {
        nix03_1 = {
          name = "nix-03-runner-1";
          url = "http://nas-01.lan:3000";
          tokenFile = config.age.secrets."forgejo-runner-token".path;
          labels = [
            "nixos:docker://nixos/nix:latest"
            "ubuntu-latest:docker://node:20-bookworm"
            "debian-latest:docker://node:20-bookworm"
          ];
          capacity = 2;
        };
        nix03_2 = {
          name = "nix-03-runner-2";
          url = "http://nas-01.lan:3000";
          tokenFile = config.age.secrets."forgejo-runner-token".path;
          labels = [
            "nixos:docker://nixos/nix:latest"
            "ubuntu-latest:docker://node:20-bookworm"
            "debian-latest:docker://node:20-bookworm"
          ];
          capacity = 2;
        };
      };
    };
  };

  # Create builder user for remote builds
  users.users.nix-builder = {
    isNormalUser = true;
    description = "Nix remote builder";
    openssh.authorizedKeys.keys = keys.builderAuthorizedKeys;
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

  clubcotton.zfs_single_root = {
    enable = true;
    poolname = "rpool";
    swapSize = "64G";
    disk = "/dev/disk/by-id/nvme-eui.00000000000000000026b738281a3535";
    useStandardRootFilesystems = true;
    reservedSize = "20GiB";
    volumes = {};
  };

  boot.zfs.extraPools = ["incus"];

  networking = {
    hostId = variables.hostId;
    hostName = "nix-03";
  };

  # Enable cgroups v2 unified hierarchy for containers
  boot.kernelParams = ["systemd.unified_cgroup_hierarchy=1"];

  # Delegate cgroup controllers for container management
  systemd.services."user@".serviceConfig.Delegate = "cpu cpuset io memory pids";

  # Configure systemd-networkd with bonding and VLANs
  clubcotton.systemd-network = {
    enable = true;
    mode = "bonded";
    interfaces = ["enp2s0" "enp3s0"];
    bondName = "bond0";
    bridgeName = "br0";
    enableIncusBridge = true;
    enableVlans = true;
    nativeVlan = {
      id = 5;
      address = "192.168.5.214/24";
      gateway = "192.168.5.1";
      dns = ["192.168.5.220"];
    };
  };

  virtualisation.libvirtd = {
    enable = true;
    qemu = {
      package = pkgs.qemu_kvm;
    };
  };

  # Pick only one of the below networking options.
  # networking.wireless.enable = true;  # Enables wireless support via wpa_supplicant.
  # networking.networkmanager.enable = true;  # Easiest to use and most distros use this by default.

  # Set your time zone.
  time.timeZone = variables.timeZone;

  # Enable touchpad support (enabled default in most desktopManager).
  # services.xserver.libinput.enable = true;

  programs.zsh.enable = variables.zshEnable;

  users.users.root = {
    openssh.authorizedKeys.keys = keys.rootAuthorizedKeys;
  };

  # An attemp at a headless x server
  # services.x2goserver.enable = true;

  # Enable the OpenSSH daemon.
  services.openssh = {
    enable = true;
    settings = {
      X11Forwarding = true;
    };
  };

  networking.firewall.enable = variables.firewallEnable;
  system.stateVersion = variables.stateVersion;
}
