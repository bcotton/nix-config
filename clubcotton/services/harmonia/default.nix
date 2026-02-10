{
  config,
  options,
  pkgs,
  lib,
  ...
}:
with lib; let
  service = "harmonia";
  cfg = config.services.clubcotton.${service};
  clubcotton = config.clubcotton;
in {
  options.services.clubcotton.${service} = {
    enable = mkEnableOption "Harmonia binary cache server";

    port = mkOption {
      type = types.port;
      default = 5000;
      description = "Port for Harmonia to listen on";
    };

    bindAddress = mkOption {
      type = types.str;
      default = "127.0.0.1";
      description = "IP address to bind to (127.0.0.1 for localhost only, 0.0.0.0 for all interfaces)";
    };

    signKeyPath = mkOption {
      type = types.nullOr types.path;
      default = null;
      description = "Path to the binary cache signing key";
    };

    maxConnections = mkOption {
      type = types.int;
      default = 25;
      description = "Maximum number of concurrent connections";
    };

    workers = mkOption {
      type = types.int;
      default = 4;
      description = "Number of worker threads";
    };

    tailnetHostname = mkOption {
      type = types.nullOr types.str;
      default = "nix-cache";
      description = "The tailnet hostname to expose the cache as";
    };
    homepage.name = lib.mkOption {
      type = lib.types.str;
      default = "Harmonia";
    };
    homepage.description = lib.mkOption {
      type = lib.types.str;
      default = "Nix binary cache server";
    };
    homepage.icon = lib.mkOption {
      type = lib.types.str;
      default = "nix.svg";
    };
    homepage.category = lib.mkOption {
      type = lib.types.str;
      default = "Infrastructure";
    };

    zfsDataset = mkOption {
      type = types.nullOr (types.submodule {
        options = {
          name = mkOption {
            type = types.str;
            description = "ZFS dataset name (e.g. ssdpool/local/nix-cache)";
          };
          properties = mkOption {
            type = types.attrsOf types.str;
            default = {};
            description = "ZFS properties to enforce on the dataset";
          };
        };
      });
      default = null;
      description = "Optional ZFS dataset to declare via disko-zfs for this service's storage";
    };
  };

  config = mkIf cfg.enable (lib.mkMerge [
    # Declare ZFS dataset if configured (only when disko module is available)
    (lib.optionalAttrs (options ? disko) {
      disko.zfs.settings.datasets = mkIf (cfg.zfsDataset != null) {
        ${cfg.zfsDataset.name} = {
          inherit (cfg.zfsDataset) properties;
        };
      };
    })

    {
      # Reference the agenix secret by default if no explicit path provided
      services.harmonia = {
        enable = true;
        # Use signKeyPaths (plural) for newer harmonia versions
        signKeyPaths = [
          (
            if cfg.signKeyPath != null
            then cfg.signKeyPath
            else config.age.secrets.harmonia-signing-key.path
          )
        ];
        settings = {
          bind = "${cfg.bindAddress}:${toString cfg.port}";
          workers = cfg.workers;
          max_connection_rate = cfg.maxConnections;
        };
      };

      # Ensure the cache directory exists with proper permissions
      systemd.tmpfiles.rules = [
        "d /ssdpool/local/nix-cache 0755 root root - -"
      ];

      # Restart harmonia when the signing key changes
      systemd.services.harmonia = {
        restartTriggers = [
          (
            if cfg.signKeyPath != null
            then cfg.signKeyPath
            else config.age.secrets.harmonia-signing-key.file
          )
        ];
      };

      # Note: Tailscale/tsnsrv integration should be configured separately
      # in host configurations where clubcotton config is available.
      # Example (add to host configuration):
      #   services.tsnsrv = mkIf (config.services.clubcotton.harmonia.tailnetHostname != null &&
      #                           config.services.clubcotton.harmonia.tailnetHostname != "") {
      #     enable = true;
      #     defaults.authKeyPath = config.clubcotton.tailscaleAuthKeyPath;
      #     services."${config.services.clubcotton.harmonia.tailnetHostname}" = {
      #       ephemeral = true;
      #       toURL = "http://127.0.0.1:${toString config.services.clubcotton.harmonia.port}/";
      #     };
      #   };

      # Allow access from local network
      networking.firewall.allowedTCPPorts = mkIf cfg.enable [cfg.port];
    }
  ]);
}
