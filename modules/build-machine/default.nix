# Remote Building Usage:
#
# To request a remote build:
# 1. One-time build: Add --builders "ssh://nix-03" to your nix build command
#    Example: nix build --builders "ssh://nix-03" .#somePackage
#
# 2. Persistent configuration: Add to your nix.conf or environment:
#    extra-builders = ssh://nix-03
#    Example locations:
#    - Global: /etc/nix/nix.conf
#    - Per-user: ~/.config/nix/nix.conf
#    - Environment: export NIX_REMOTE_BUILDERS="ssh://nix-03"
#
# To force local building only:
# 1. One-time: Add --max-jobs 0 to your builders
#    Example: nix build --builders "" --max-jobs 0 .#somePackage
#
# 2. Persistent configuration: Add to your nix.conf:
#    builders = ""
#    max-jobs = 0
#
{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.services.clubcotton.build-machine;
in {
  options.services.clubcotton.build-machine = {
    enable = lib.mkEnableOption "Enable remote build machine capabilities";
    
    systems = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = ["x86_64-linux"];
      description = "List of systems this machine can build for";
    };

    maxJobs = lib.mkOption {
      type = lib.types.int;
      default = 8;
      description = "Maximum number of concurrent build jobs";
    };

    speedFactor = lib.mkOption {
      type = lib.types.int;
      default = 1;
      description = "Relative speed factor compared to other build machines";
    };

    supportedFeatures = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = ["nixos-test" "benchmark" "big-parallel" "kvm"];
      description = "List of supported Nix features";
    };

    mandatoryFeatures = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [];
      description = "List of features that must be supported for this machine to be used";
    };
  };

  config = lib.mkIf cfg.enable {
    nix = {
      # Enable distributed builds
      distributedBuilds = true;
      
      # Configure SSH-based authentication for builds
      buildMachines = [{
        hostName = config.networking.hostName;
        systems = cfg.systems;
        maxJobs = cfg.maxJobs;
        speedFactor = cfg.speedFactor;
        supportedFeatures = cfg.supportedFeatures;
        mandatoryFeatures = cfg.mandatoryFeatures;
      }];
      
      # Extra settings for build machine
      settings = {
        # Accept connections from any machine in the network
        trusted-users = ["root" "@wheel"];
        
        # Allow remote builds
        builders-use-substitutes = true;
      };

      # Enable nix daemon which is required for remote builds
      daemonIONiceLevel = 7;
      daemonNiceLevel = 19;
    };

    # Ensure the nix daemon service is enabled
    systemd.services.nix-daemon = {
      enable = true;
      serviceConfig = {
        Nice = 19;
        IOSchedulingClass = "idle";
      };
    };
  };
}
