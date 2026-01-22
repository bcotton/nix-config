{
  config,
  lib,
  pkgs,
  ...
}:
with lib; let
  service = "forgejo-runner";
  cfg = config.services.clubcotton.${service};
in {
  options.services.clubcotton.${service} = {
    enable = mkEnableOption "Enable Forgejo Actions runner";

    package = mkOption {
      type = types.package;
      default = pkgs.forgejo-runner;
      description = "Forgejo runner package to use";
    };

    instances = mkOption {
      type = types.attrsOf (types.submodule {
        options = {
          enable = mkOption {
            type = types.bool;
            default = true;
            description = "Enable this runner instance";
          };

          name = mkOption {
            type = types.str;
            description = "Name for this runner instance";
          };

          url = mkOption {
            type = types.str;
            default = "http://nas-01.lan:3000";
            description = "URL of the Forgejo instance";
          };

          tokenFile = mkOption {
            type = types.path;
            description = "File containing runner registration token";
          };

          labels = mkOption {
            type = types.listOf types.str;
            default = ["nixos:docker://node:20-bookworm" "ubuntu-latest:docker://node:20-bookworm"];
            description = "Labels for this runner";
          };

          hostPackages = mkOption {
            type = types.listOf types.package;
            default = with pkgs; [bash coreutils git gnutar gzip];
            description = "Packages available to the runner";
          };

          capacity = mkOption {
            type = types.int;
            default = 2;
            description = "Maximum number of parallel jobs";
          };

          stateDir = mkOption {
            type = types.str;
            default = "/var/lib/forgejo-runner";
            description = "State directory for runner data";
          };
        };
      });
      default = {};
      description = "Runner instances to configure";
    };
  };

  config = mkIf cfg.enable {
    # Note: Docker/Podman should be configured at the host level
    # The runner will use the Docker-compatible socket provided by Podman

    # Configure each runner instance
    services.gitea-actions-runner = {
      package = pkgs.forgejo-runner;
      instances =
        mapAttrs (name: runnerCfg: {
          # package = pkgs.forgejo-runner;
          enable = runnerCfg.enable;
          name = runnerCfg.name;
          url = runnerCfg.url;
          tokenFile = runnerCfg.tokenFile;
          labels = runnerCfg.labels;
          hostPackages = runnerCfg.hostPackages;
          settings = {
            runner = {
              capacity = runnerCfg.capacity;
              timeout = "3h";
            };
            cache = {
              enabled = true;
            };
            container = {
              network = "bridge";
              privileged = false;
              options = "-v /nix:/nix:ro";
            };
          };
        })
        cfg.instances;
    };

    # Open firewall if needed (runners initiate connections, usually not needed)
    # networking.firewall.allowedTCPPorts = [];
  };
}
