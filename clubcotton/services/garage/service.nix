{
  config,
  pkgs,
  lib,
  ...
}:
with lib; let
  cfg = config.services.clubcotton.garage;
  tomlFormat = pkgs.formats.toml {};
in {
  options.services.clubcotton.garage = {
    enable = mkEnableOption "Garage S3-compatible object storage";

    package = mkOption {
      type = types.package;
      default = pkgs.garage;
      defaultText = literalExpression "pkgs.garage";
      description = "Garage package to use.";
    };

    dataDir = mkOption {
      type = types.path;
      default = "/var/lib/garage/data";
      description = "Data directory for Garage object storage.";
    };

    metadataDir = mkOption {
      type = types.path;
      default = "/var/lib/garage/meta";
      description = "Metadata directory for Garage.";
    };

    replicationFactor = mkOption {
      type = types.ints.positive;
      default = 1;
      description = ''
        Replication factor for Garage. Defines how many copies of each object
        are stored across the cluster. 1 means no replication (single copy),
        3 means 3 copies for redundancy, etc.
      '';
    };

    consistencyMode = mkOption {
      type = types.enum ["consistent" "degraded" "dangerous"];
      default = "consistent";
      description = ''
        Consistency mode for read/write operations.
        "consistent" provides read-after-write consistency.
        "degraded" lowers the read quorum for better availability.
        "dangerous" lowers both read and write quorums to 1.
      '';
    };

    rpcBindAddr = mkOption {
      type = types.str;
      default = "[::]:3901";
      description = "Address to bind for internal RPC communication between Garage nodes.";
    };

    rpcSecretFile = mkOption {
      type = types.nullOr types.path;
      default = null;
      description = ''
        Path to file containing the RPC secret key for cluster communication.
        This secret must be shared across all nodes in a cluster.
        If null and replicationMode > 1, a warning will be issued.
      '';
    };

    s3Region = mkOption {
      type = types.str;
      default = "garage";
      description = "Region name exposed via S3 API.";
    };

    s3ApiBindAddr = mkOption {
      type = types.str;
      default = "[::]:3900";
      description = "Address to bind for S3 API endpoint.";
    };

    s3WebBindAddr = mkOption {
      type = types.nullOr types.str;
      default = null;
      example = "[::]:3902";
      description = ''
        Address to bind for S3 static website hosting endpoint.
        Only enabled when s3WebRootDomain is also set.
      '';
    };

    s3WebRootDomain = mkOption {
      type = types.nullOr types.str;
      default = null;
      example = "web.example.com";
      description = ''
        Root domain for static website hosting.
        Required when s3WebBindAddr is set.
        Buckets can be accessed as <bucket>.web.example.com
      '';
    };

    s3RootDomain = mkOption {
      type = types.nullOr types.str;
      default = null;
      example = "s3.example.com";
      description = ''
        Root domain for virtual-hosted-style S3 API requests.
        If set, requests to <bucket>.s3.example.com will be handled.
      '';
    };

    allowUnauthenticatedReads = mkOption {
      type = types.bool;
      default = false;
      description = ''
        Allow unauthenticated read access to public buckets.
        WARNING: Only enable if you understand the security implications.
      '';
    };

    adminApiBindAddr = mkOption {
      type = types.nullOr types.str;
      default = null;
      example = "0.0.0.0:3903";
      description = "Address to bind for admin API (metrics, health). Disabled when null.";
    };

    metricsTokenFile = mkOption {
      type = types.nullOr types.path;
      default = null;
      description = "Path to file containing bearer token for /metrics endpoint. Unauthenticated when null.";
    };

    openFirewall = mkOption {
      type = types.bool;
      default = true;
      description = "Open firewall ports for Garage services.";
    };

    environmentFile = mkOption {
      type = types.nullOr types.path;
      default = null;
      description = ''
        Path to environment file for sensitive configuration.
        Can be used for RUST_LOG, etc.
      '';
    };

    zfsDataset = mkOption {
      type = types.nullOr (types.submodule {
        options = {
          name = mkOption {
            type = types.str;
            description = "ZFS dataset name (e.g. ssdpool/local/garage)";
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

  config = mkIf cfg.enable {
    assertions = [
      {
        assertion = cfg.rpcSecretFile != null;
        message = "Garage requires rpcSecretFile to be set for RPC authentication";
      }
    ];

    # Create Garage configuration
    environment.etc."garage/garage.toml".source = tomlFormat.generate "garage.toml" ({
        metadata_dir = cfg.metadataDir;
        data_dir = cfg.dataDir;
        replication_factor = cfg.replicationFactor;
        consistency_mode = cfg.consistencyMode;
        rpc_bind_addr = cfg.rpcBindAddr;
        s3_api =
          {
            s3_region = cfg.s3Region;
            api_bind_addr = cfg.s3ApiBindAddr;
          }
          // optionalAttrs (cfg.s3RootDomain != null) {
            root_domain = cfg.s3RootDomain;
          }
          // optionalAttrs cfg.allowUnauthenticatedReads {
            allow_unauthenticated_reads = true;
          };
      }
      // optionalAttrs (cfg.rpcSecretFile != null) {
        rpc_secret_file = toString cfg.rpcSecretFile;
      }
      // optionalAttrs (cfg.s3WebBindAddr != null && cfg.s3WebRootDomain != null) {
        s3_web = {
          bind_addr = cfg.s3WebBindAddr;
          root_domain = cfg.s3WebRootDomain;
        };
      }
      // optionalAttrs (cfg.adminApiBindAddr != null) {
        admin =
          {
            api_bind_addr = cfg.adminApiBindAddr;
          }
          // optionalAttrs (cfg.metricsTokenFile != null) {
            metrics_token_file = toString cfg.metricsTokenFile;
          };
      });

    # Create data and metadata directories
    systemd.tmpfiles.rules = [
      "d '${cfg.dataDir}' 0750 garage garage -"
      "d '${cfg.metadataDir}' 0750 garage garage -"
    ];

    # Garage service user
    users.users.garage = {
      isSystemUser = true;
      group = "garage";
      home = "/var/lib/garage";
      createHome = true;
    };

    users.groups.garage = {};

    # Main Garage service
    systemd.services.garage = {
      description = "Garage S3-compatible object storage";
      after = ["network.target"];
      wantedBy = ["multi-user.target"];

      environment = {
        GARAGE_CONFIG_FILE = "/etc/garage/garage.toml";
      };

      serviceConfig = {
        Type = "simple";
        User = "garage";
        Group = "garage";
        ExecStart = "${cfg.package}/bin/garage server";
        Restart = "on-failure";
        RestartSec = 5;

        # Run as root (+) to create dirs in potentially root-owned ZFS mounts
        ExecStartPre = let
          script = pkgs.writeShellScript "garage-prestart" ''
            mkdir -p ${cfg.dataDir} ${cfg.metadataDir}
            chown garage:garage ${cfg.dataDir} ${cfg.metadataDir}
          '';
        in "+${script}";

        # Security hardening
        NoNewPrivileges = true;
        ProtectSystem = "strict";
        ProtectHome = true;
        ReadWritePaths = unique [
          (dirOf cfg.dataDir)
          (dirOf cfg.metadataDir)
          cfg.dataDir
          cfg.metadataDir
        ];
        PrivateTmp = true;

        # Resource limits
        LimitNOFILE = 65536;

        # Environment file for additional configuration
        EnvironmentFile = optionalString (cfg.environmentFile != null) (toString cfg.environmentFile);
      };
    };

    # Firewall configuration
    networking.firewall = mkIf cfg.openFirewall {
      allowedTCPPorts =
        [
          (toInt (elemAt (splitString ":" cfg.s3ApiBindAddr) 1)) # S3 API port
          (toInt (elemAt (splitString ":" cfg.rpcBindAddr) 1)) # RPC port
        ]
        ++ optional (cfg.s3WebBindAddr != null) (toInt (elemAt (splitString ":" cfg.s3WebBindAddr) 1)) # Web port
        ++ optional (cfg.adminApiBindAddr != null) (toInt (elemAt (splitString ":" cfg.adminApiBindAddr) 1)); # Admin API port
    };

    environment.systemPackages = [cfg.package];
  };
}
