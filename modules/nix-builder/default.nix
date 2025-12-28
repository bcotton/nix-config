{
  config,
  lib,
  pkgs,
  ...
}:
with lib; let
  cfg = config.services.nix-builder.coordinator;
in {
  options.services.nix-builder.coordinator = {
    enable = mkEnableOption "Nix build coordinator";

    builders = mkOption {
      type = types.listOf (types.submodule {
        options = {
          hostname = mkOption {
            type = types.str;
            description = "Builder hostname";
          };
          sshUser = mkOption {
            type = types.str;
            default = "nix-builder";
            description = "SSH user for remote builds";
          };
          systems = mkOption {
            type = types.listOf types.str;
            default = ["x86_64-linux"];
            description = "Supported systems";
          };
          maxJobs = mkOption {
            type = types.int;
            default = 4;
            description = "Maximum parallel builds";
          };
          speedFactor = mkOption {
            type = types.int;
            default = 1;
            description = "Relative build speed (higher = faster)";
          };
          supportedFeatures = mkOption {
            type = types.listOf types.str;
            default = ["nixos-test" "benchmark" "big-parallel" "kvm"];
            description = "Supported build features";
          };
        };
      });
      default = [];
      description = "List of remote builders";
    };

    sshKeyPath = mkOption {
      type = types.nullOr types.path;
      default = null;
      description = "Path to SSH private key for builders";
    };

    localCache = mkOption {
      type = types.nullOr types.str;
      default = "http://localhost:5000";
      description = "Local cache URL to push builds to";
    };

    enableLocalBuilds = mkOption {
      type = types.bool;
      default = true;
      description = "Allow local builds when remote builders unavailable";
    };
  };

  config = mkIf cfg.enable {
    # Configure distributed builds
    nix.buildMachines =
      map (builder: {
        hostName = builder.hostname;
        sshUser = builder.sshUser;
        sshKey =
          if cfg.sshKeyPath != null
          then cfg.sshKeyPath
          else config.age.secrets.nix-builder-ssh-key.path;
        systems = builder.systems;
        maxJobs = builder.maxJobs;
        speedFactor = builder.speedFactor;
        supportedFeatures = builder.supportedFeatures;
        mandatoryFeatures = [];
      })
      cfg.builders;

    # Nix daemon settings
    nix.settings = {
      # Max jobs - let build machines handle most of it
      max-jobs =
        if cfg.enableLocalBuilds
        then 2
        else 0;

      # Trust builder SSH key and other settings
      trusted-users = ["root" "@wheel"];
    };

    nix.distributedBuilds = true;

    # Post-build hook to sign store paths for cache
    nix.extraOptions = mkIf (cfg.localCache != null) ''
      post-build-hook = ${pkgs.writeShellScript "post-build-hook" ''
        set -euf -o pipefail

        # Get build outputs
        export IFS=' '
        echo "Signing paths for cache: $OUT_PATHS" >&2

        # Sign paths - Harmonia will automatically serve them from /nix/store
        exec ${pkgs.nix}/bin/nix store sign \
          --key-file ${
          if cfg.sshKeyPath != null
          then cfg.sshKeyPath
          else config.age.secrets.harmonia-signing-key.path
        } \
          $OUT_PATHS
      ''}
    '';

    # SSH client configuration for builder connections
    programs.ssh.extraConfig = ''
      Host ${concatStringsSep " " (map (b: b.hostname) cfg.builders)}
        StrictHostKeyChecking accept-new
        ServerAliveInterval 60
        ServerAliveCountMax 3
        IdentitiesOnly yes
        ${optionalString (cfg.sshKeyPath != null) "IdentityFile ${cfg.sshKeyPath}"}
        ${optionalString (cfg.sshKeyPath == null && config.age.secrets ? nix-builder-ssh-key) "IdentityFile ${config.age.secrets.nix-builder-ssh-key.path}"}
    '';
  };
}
