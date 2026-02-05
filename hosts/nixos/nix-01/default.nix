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
    inputs.nix-builder-config.nixosModules.coordinator
    ../../../modules/incus
    ../../../modules/systemd-network
  ];

  services.clubcotton = {
    code-server.enable = true;
    nut-client.enable = true;
    bonob.enable = true;
    forgejo-runner = {
      enable = true;
      instances = {
        nix01_1 = {
          name = "nix-01-runner-1";
          url = "http://nas-01.lan:3000";
          tokenFile = config.age.secrets."forgejo-runner-token".path;
          labels = [
            "nixos:docker://nixos/nix:latest"
            "ubuntu-latest:docker://node:20-bookworm"
            "debian-latest:docker://node:20-bookworm"
          ];
          capacity = 2;
        };
        nix01_2 = {
          name = "nix-01-runner-2";
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

    obsidian = {
      enable = true;
      instances.bcotton = {
        httpPort = 13000;
        httpsPort = 13001;
        user = "bcotton";
        group = "users";
        vaultDir = "/home/bcotton/obsidian-vaults";
        # To enable HTTP Basic Auth:
        # 1. Create the secret: agenix -e secrets/obsidian-bcotton.age
        # 2. Add content: PASSWORD=your-secret-password
        # 3. Uncomment the basicAuth block below
        basicAuth = {
          enable = true;
          username = "bcotton";
          environmentFile = config.age.secrets.obsidian-bcotton.path;
        };
      };
    };
  };

  # Configure distributed build fleet
  services.nix-builder.coordinator = {
    enable = true;
    sshKeyPath = config.age.secrets."nix-builder-ssh-key".path;
    enableLocalBuilds = true; # nix-01 can build locally as fallback
    localCache = null; # Don't sign builds on nix-01 - nas-01 handles cache signing
    # Use .lan suffix for local DNS resolution (Tailscale names won't resolve from builder environment)
    builders = [
      {
        hostname = "nas-01.lan";
        systems = ["x86_64-linux"];
        maxJobs = 16;
        speedFactor = 2; # nas-01 is faster
        supportedFeatures = ["nixos-test" "benchmark" "big-parallel" "kvm"];
      }
      {
        hostname = "nix-02.lan";
        systems = ["x86_64-linux"];
        maxJobs = 16;
        speedFactor = 4;
        supportedFeatures = ["nixos-test" "benchmark" "big-parallel" "kvm"];
      }
      {
        hostname = "nix-03.lan";
        systems = ["x86_64-linux"];
        maxJobs = 16;
        speedFactor = 4;
        supportedFeatures = ["nixos-test" "benchmark" "big-parallel" "kvm"];
      }
    ];
  };

  # Cache client already enabled via flake-modules/hosts.nix with defaults

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
    disk = "/dev/disk/by-id/nvme-eui.00000000000000000026b738281a1aa5";
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

  # Enable cgroups v2 unified hierarchy for containers
  boot.kernelParams = ["systemd.unified_cgroup_hierarchy=1"];

  # Delegate cgroup controllers for container management
  systemd.services."user@".serviceConfig.Delegate = "cpu cpuset io memory pids";

  networking = {
    hostName = "nix-01";
    hostId = variables.hostId;
  };

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
      address = "192.168.5.210/24";
      gateway = "192.168.5.1";
      dns = ["192.168.5.220"];
    };
  };

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
  time.timeZone = variables.timeZone;

  programs.zsh.enable = variables.zshEnable;

  users.users.root = {
    openssh.authorizedKeys.keys = keys.rootAuthorizedKeys;
  };

  # Enable the OpenSSH daemon.
  services.openssh.enable = variables.opensshEnable;

  networking.firewall.enable = variables.firewallEnable;

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

  system.stateVersion = variables.stateVersion;
}
