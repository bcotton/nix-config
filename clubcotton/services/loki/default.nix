{
  config,
  lib,
  ...
}:
with lib; let
  service = "loki";
  cfg = config.services.clubcotton.${service};
  clubcotton = config.clubcotton;
in {
  options.services.clubcotton.${service} = {
    enable = lib.mkEnableOption {
      description = "Enable Grafana Loki for log aggregation";
    };
    port = mkOption {
      type = types.port;
      default = 3100;
      description = "HTTP listen port for Loki.";
    };
    dataDir = mkOption {
      type = types.str;
      default = "/var/lib/loki";
      description = "Local data directory for TSDB WAL, compactor, and rules.";
    };
    retentionPeriod = mkOption {
      type = types.str;
      default = "720h";
      description = "Log retention period (default 30 days).";
    };

    s3 = {
      endpoint = mkOption {
        type = types.str;
        default = "localhost:3900";
        description = "S3-compatible endpoint (e.g., Garage).";
      };
      bucketName = mkOption {
        type = types.str;
        default = "loki-data";
        description = "S3 bucket name for chunks and index storage.";
      };
      region = mkOption {
        type = types.str;
        default = "garage";
        description = "S3 region (use any string for Garage).";
      };
      insecure = mkOption {
        type = types.bool;
        default = true;
        description = "Whether to use HTTP instead of HTTPS for S3.";
      };
      environmentFile = mkOption {
        type = types.path;
        description = ''
          Path to environment file with S3 credentials.
          Must contain LOKI_S3_ACCESS_KEY_ID and LOKI_S3_SECRET_ACCESS_KEY.
        '';
      };
    };

    tailnetHostname = mkOption {
      type = types.nullOr types.str;
      default = "${service}";
      description = "The tailnet hostname to expose Loki as.";
    };
    homepage.name = lib.mkOption {
      type = lib.types.str;
      default = "Loki";
    };
    homepage.description = lib.mkOption {
      type = lib.types.str;
      default = "Log aggregation";
    };
    homepage.icon = lib.mkOption {
      type = lib.types.str;
      default = "grafana.svg";
    };
    homepage.category = lib.mkOption {
      type = lib.types.str;
      default = "Infrastructure";
    };
  };

  config = lib.mkIf cfg.enable {
    services.loki = {
      enable = true;
      extraFlags = [
        "--config.expand-env=true"
      ];
      configuration = {
        target = "all";
        auth_enabled = false;

        server = {
          http_listen_port = cfg.port;
          grpc_listen_port = 9096;
          log_level = "warn";
        };

        common = {
          path_prefix = cfg.dataDir;
          replication_factor = 1;
          ring = {
            instance_addr = "127.0.0.1";
            kvstore.store = "inmemory";
          };
        };

        schema_config = {
          configs = [
            {
              from = "2024-01-01";
              store = "tsdb";
              object_store = "s3";
              schema = "v13";
              index = {
                prefix = "index_";
                period = "24h";
              };
            }
          ];
        };

        storage_config = {
          tsdb_shipper = {
            active_index_directory = "${cfg.dataDir}/tsdb-index";
            cache_location = "${cfg.dataDir}/tsdb-cache";
          };
          aws = {
            endpoint = cfg.s3.endpoint;
            bucketnames = cfg.s3.bucketName;
            region = cfg.s3.region;
            access_key_id = "\${LOKI_S3_ACCESS_KEY_ID}";
            secret_access_key = "\${LOKI_S3_SECRET_ACCESS_KEY}";
            insecure = cfg.s3.insecure;
            s3forcepathstyle = true;
          };
        };

        ingester = {
          wal = {
            dir = "${cfg.dataDir}/wal";
          };
        };

        compactor = {
          working_directory = "${cfg.dataDir}/compactor";
          compaction_interval = "10m";
          retention_enabled = true;
          retention_delete_delay = "2h";
          retention_delete_worker_count = 150;
          delete_request_store = "aws";
        };

        limits_config = {
          retention_period = cfg.retentionPeriod;
          ingestion_rate_mb = 32;
          ingestion_burst_size_mb = 64;
          max_streams_per_user = 10000;
          max_global_streams_per_user = 10000;
          max_query_parallelism = 16;
        };

        query_range = {
          results_cache = {
            cache = {
              embedded_cache = {
                enabled = true;
                max_size_mb = 100;
              };
            };
          };
        };

        analytics = {
          reporting_enabled = false;
        };
      };
    };

    systemd.services.loki.serviceConfig = {
      EnvironmentFile = cfg.s3.environmentFile;
      DynamicUser = lib.mkForce false;
      User = "loki";
      Group = "loki";
    };

    users.users.loki = {
      isSystemUser = true;
      group = "loki";
      home = cfg.dataDir;
    };
    users.groups.loki = {};

    systemd.tmpfiles.rules = [
      "d ${cfg.dataDir} 0750 loki loki - -"
      "d ${cfg.dataDir}/tsdb-index 0750 loki loki - -"
      "d ${cfg.dataDir}/tsdb-cache 0750 loki loki - -"
      "d ${cfg.dataDir}/wal 0750 loki loki - -"
      "d ${cfg.dataDir}/compactor 0750 loki loki - -"
    ];

    services.tsnsrv = {
      enable = true;
      defaults.authKeyPath = clubcotton.tailscaleAuthKeyPath;

      services."${cfg.tailnetHostname}" = mkIf (cfg.tailnetHostname != "") {
        ephemeral = true;
        toURL = "http://127.0.0.1:${toString cfg.port}/";
      };
    };

    networking.firewall.allowedTCPPorts = [cfg.port];
  };
}
