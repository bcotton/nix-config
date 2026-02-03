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

    replicationMode = mkOption {
      type = types.enum ["1" "2" "3" "4" "5" "6" "7" "8" "9" "10" "none"];
      default = "1";
      description = ''
        Replication mode for Garage. Defines how many copies of each object
        are stored across the cluster. "1" means no replication (single copy),
        "3" means 3 copies for redundancy, etc.
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
      type = types.str;
      default = "[::]:3902";
      description = "Address to bind for S3 web UI.";
    };

    s3RootDomain = mkOption {
      type = types.nullOr types.str;
      default = null;
      example = "s3.example.com";
      description = ''
        Root domain for virtual-hosted-style S3 requests.
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
  };

  config = mkIf cfg.enable {
    assertions = [
      {
        assertion = cfg.replicationMode == "1" || cfg.rpcSecretFile != null;
        message = "Garage replicationMode > 1 requires rpcSecretFile to be set for cluster security";
      }
    ];

    # Create Garage configuration
    environment.etc."garage/garage.toml".source = tomlFormat.generate "garage.toml" {
      metadata_dir = cfg.metadataDir;
      data_dir = cfg.dataDir;
      replication_mode = cfg.replicationMode;
      rpc_bind_addr = cfg.rpcBindAddr;
      rpc_secret_file = optionalString (cfg.rpcSecretFile != null) (toString cfg.rpcSecretFile);
      s3_api =
        {
          s3_region = cfg.s3Region;
          bind_addr = cfg.s3ApiBindAddr;
        }
        // optionalAttrs (cfg.s3RootDomain != null) {
          root_domain = cfg.s3RootDomain;
        }
        // optionalAttrs cfg.allowUnauthenticatedReads {
          allow_unauthenticated_reads = true;
        };
      s3_web = {
        bind_addr = cfg.s3WebBindAddr;
      };
    };

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

      serviceConfig = {
        Type = "simple";
        User = "garage";
        Group = "garage";
        ExecStart = "${cfg.package}/bin/garage server -c /etc/garage/garage.toml";
        Restart = "on-failure";
        RestartSec = 5;

        # Security hardening
        NoNewPrivileges = true;
        ProtectSystem = "strict";
        ProtectHome = true;
        ReadWritePaths = [cfg.dataDir cfg.metadataDir];
        PrivateTmp = true;

        # Resource limits
        LimitNOFILE = 65536;

        # Environment file for additional configuration
        EnvironmentFile = optionalString (cfg.environmentFile != null) (toString cfg.environmentFile);
      };

      # Ensure directories exist before starting
      preStart = ''
        mkdir -p ${cfg.dataDir} ${cfg.metadataDir}
        chown -R garage:garage ${cfg.dataDir} ${cfg.metadataDir}
      '';
    };

    # Firewall configuration
    networking.firewall = mkIf cfg.openFirewall {
      allowedTCPPorts = [
        (toInt (elemAt (splitString ":" cfg.s3ApiBindAddr) 1)) # S3 API port
        (toInt (elemAt (splitString ":" cfg.rpcBindAddr) 1)) # RPC port
        (toInt (elemAt (splitString ":" cfg.s3WebBindAddr) 1)) # Web UI port
      ];
    };

    environment.systemPackages = [cfg.package];
  };
}
