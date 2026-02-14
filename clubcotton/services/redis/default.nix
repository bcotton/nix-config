{
  config,
  options,
  pkgs,
  lib,
  ...
}:
with lib; let
  service = "redis";
  cfg = config.services.clubcotton.${service};
in {
  options.services.clubcotton.${service} = {
    enable = mkEnableOption "Redis in-memory data store";

    port = mkOption {
      type = types.port;
      default = 6379;
      description = "Port for Redis to listen on";
    };

    bindAddress = mkOption {
      type = types.str;
      default = "127.0.0.1";
      description = "IP address to bind to (127.0.0.1 for localhost only, 0.0.0.0 for all interfaces)";
    };

    dataDir = mkOption {
      type = types.str;
      default = "/ssdpool/local/redis";
      description = "Directory for Redis persistent data (RDB and AOF files)";
    };

    maxMemory = mkOption {
      type = types.str;
      default = "4gb";
      description = "Maximum memory Redis will use before eviction (e.g. 1gb, 500mb)";
    };

    maxMemoryPolicy = mkOption {
      type = types.enum [
        "noeviction"
        "allkeys-lru"
        "volatile-lru"
        "allkeys-random"
        "volatile-random"
        "volatile-ttl"
        "allkeys-lfu"
        "volatile-lfu"
      ];
      default = "noeviction";
      description = "Eviction policy when maxmemory is reached";
    };

    requirePassFile = mkOption {
      type = types.nullOr types.path;
      default = null;
      description = "Path to a file containing the Redis password (managed via agenix)";
    };

    openFirewall = mkOption {
      type = types.bool;
      default = false;
      description = "Whether to open the firewall port for Redis";
    };

    zfsDataset = mkOption {
      type = types.nullOr (types.submodule {
        options = {
          name = mkOption {
            type = types.str;
            description = "ZFS dataset name (e.g. ssdpool/local/redis)";
          };
          properties = mkOption {
            type = types.attrsOf types.str;
            default = {};
            description = "ZFS properties to enforce on the dataset";
          };
        };
      });
      default = null;
      description = "Optional ZFS dataset to declare via disko-zfs for Redis storage";
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
      services.redis.servers.clubcotton = {
        enable = true;
        port = cfg.port;
        bind = cfg.bindAddress;

        # RDB snapshots (NixOS default: save at 900/1, 300/10, 60/10000)
        # AOF persistence
        appendOnly = true;
        appendFsync = "everysec";

        # Password from file
        requirePassFile = cfg.requirePassFile;

        settings = {
          # Data directory on ZFS mount (mkForce needed to override NixOS module default)
          dir = mkForce cfg.dataDir;

          # AOF rewrite thresholds
          auto-aof-rewrite-percentage = "100";
          auto-aof-rewrite-min-size = "64mb";

          # Memory management
          maxmemory = cfg.maxMemory;
          maxmemory-policy = cfg.maxMemoryPolicy;
        };
      };

      # Ensure data directory exists on the ZFS mount with correct ownership
      systemd.tmpfiles.rules = [
        "d '${cfg.dataDir}' 0700 redis-clubcotton redis-clubcotton - -"
      ];

      # Allow the service to write to the ZFS-mounted data directory
      # (NixOS Redis module sets ProtectSystem = "strict")
      systemd.services.redis-clubcotton = {
        unitConfig.RequiresMountsFor = [cfg.dataDir];
        serviceConfig.ReadWritePaths = [cfg.dataDir];
      };

      networking.firewall.allowedTCPPorts = mkIf cfg.openFirewall [cfg.port];

      # Prometheus redis exporter - connects via unix socket
      services.prometheus.exporters.redis = {
        enable = true;
        extraFlags = [
          "-redis.addr"
          "unix:///run/redis-clubcotton/redis.sock"
        ];
      };

      # Fix exporter systemd service:
      # - Add AF_INET so the exporter can listen on TCP for Prometheus scrapes
      # - Add redis-clubcotton group so it can access the unix socket
      # - Pass password via environment if authentication is configured
      systemd.services.prometheus-redis-exporter = lib.mkMerge [
        {
          serviceConfig = {
            RestrictAddressFamilies = mkForce ["AF_UNIX" "AF_INET" "AF_INET6"];
            SupplementaryGroups = ["redis-clubcotton"];
          };
        }
        (mkIf (cfg.requirePassFile != null) {
          # The redis_exporter reads REDIS_PASSWORD env var, but agenix files
          # contain just the raw password. Wrap it in the expected env var.
          serviceConfig.ExecStartPre = let
            script = pkgs.writeShellScript "redis-exporter-env" ''
              echo "REDIS_PASSWORD=$(cat ${cfg.requirePassFile})" > /run/prometheus-redis-exporter/env
              chmod 600 /run/prometheus-redis-exporter/env
            '';
          in "+${script}";
          serviceConfig.EnvironmentFile = mkForce "/run/prometheus-redis-exporter/env";
          serviceConfig.RuntimeDirectory = "prometheus-redis-exporter";
        })
      ];
    }
  ]);
}
