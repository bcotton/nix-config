{
  config,
  lib,
  ...
}:
with lib; let
  service = "mimir";
  cfg = config.services.clubcotton.${service};
  clubcotton = config.clubcotton;
in {
  options.services.clubcotton.${service} = {
    enable = lib.mkEnableOption {
      description = "Enable Grafana Mimir for long-term metrics storage";
    };
    port = mkOption {
      type = types.port;
      default = 9009;
      description = "HTTP listen port for Mimir.";
    };
    dataDir = mkOption {
      type = types.str;
      default = "/var/lib/mimir";
      description = "Local data directory for TSDB and compactor.";
    };
    retentionPeriod = mkOption {
      type = types.str;
      default = "720h";
      description = "Compactor blocks retention period (default 30 days).";
    };

    s3 = {
      endpoint = mkOption {
        type = types.str;
        default = "localhost:3900";
        description = "S3-compatible endpoint (e.g., Garage).";
      };
      bucketName = mkOption {
        type = types.str;
        default = "mimir-blocks";
        description = "S3 bucket name for block storage.";
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
          Must contain MIMIR_S3_ACCESS_KEY_ID and MIMIR_S3_SECRET_ACCESS_KEY.
        '';
      };
    };

    tailnetHostname = mkOption {
      type = types.nullOr types.str;
      default = "${service}";
      description = "The tailnet hostname to expose Mimir as.";
    };
    homepage.name = lib.mkOption {
      type = lib.types.str;
      default = "Mimir";
    };
    homepage.description = lib.mkOption {
      type = lib.types.str;
      default = "Long-term metrics storage";
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
    services.mimir = {
      enable = true;
      extraFlags = [
        "--config.expand-env=true"
      ];
      configuration = {
        target = "all";
        multitenancy_enabled = false;

        server = {
          http_listen_port = cfg.port;
        };

        blocks_storage = {
          backend = "s3";
          s3 = {
            endpoint = cfg.s3.endpoint;
            bucket_name = cfg.s3.bucketName;
            region = cfg.s3.region;
            access_key_id = "\${MIMIR_S3_ACCESS_KEY_ID}";
            secret_access_key = "\${MIMIR_S3_SECRET_ACCESS_KEY}";
            insecure = cfg.s3.insecure;
          };
          tsdb = {
            dir = "${cfg.dataDir}/tsdb";
          };
        };

        compactor = {
          data_dir = "${cfg.dataDir}/compactor";
          deletion_delay = "2h";
        };

        limits = {
          compactor_blocks_retention_period = cfg.retentionPeriod;
          ingestion_rate = 50000;
          ingestion_burst_size = 500000;
          max_global_series_per_user = 300000;
        };

        ingester = {
          ring = {
            replication_factor = 1;
            kvstore.store = "memberlist";
          };
        };

        store_gateway = {
          sharding_ring = {
            replication_factor = 1;
          };
        };

        ruler_storage = {
          backend = "local";
          local.directory = "${cfg.dataDir}/rules";
        };
      };
    };

    systemd.services.mimir.serviceConfig = {
      EnvironmentFile = cfg.s3.environmentFile;
      # The upstream module sets DynamicUser=true, which allocates a
      # transient UID that conflicts with the static mimir user our
      # tmpfiles rules expect.  Disable it so the service runs as
      # the static mimir user consistently.
      DynamicUser = lib.mkForce false;
      User = "mimir";
      Group = "mimir";
    };

    users.users.mimir = {
      isSystemUser = true;
      group = "mimir";
      home = cfg.dataDir;
    };
    users.groups.mimir = {};

    systemd.tmpfiles.rules = [
      "d ${cfg.dataDir} 0750 mimir mimir - -"
      "d ${cfg.dataDir}/tsdb 0750 mimir mimir - -"
      "d ${cfg.dataDir}/compactor 0750 mimir mimir - -"
      "d ${cfg.dataDir}/rules 0750 mimir mimir - -"
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
