{
  config,
  lib,
  pkgs,
  ...
}:
with lib; let
  service = "forgejo";
  cfg = config.services.clubcotton.${service};
  clubcotton = config.clubcotton;
in {
  options.services.clubcotton.${service} = {
    enable = mkEnableOption "Enable Forgejo git forge";

    package = mkOption {
      type = types.package;
      default = pkgs.forgejo;
      description = "Forgejo package to use";
    };

    stateDir = mkOption {
      type = types.str;
      default = "/var/lib/forgejo";
      description = "Directory for Forgejo state and repositories";
    };

    # Use ssdpool by default for fast storage
    customPath = mkOption {
      type = types.nullOr types.str;
      default = "/ssdpool/local/forgejo";
      description = "Custom path for Forgejo data (repositories, LFS, etc)";
    };

    user = mkOption {
      type = types.str;
      default = "forgejo";
      description = "User account under which Forgejo runs";
    };

    group = mkOption {
      type = types.str;
      default = "forgejo";
      description = "Group under which Forgejo runs";
    };

    port = mkOption {
      type = types.port;
      default = 3000;
      description = "HTTP port for Forgejo web interface";
    };

    sshPort = mkOption {
      type = types.port;
      default = 2222;
      description = "SSH port for git operations";
    };

    domain = mkOption {
      type = types.str;
      default = "forgejo.lan";
      description = "Domain name for Forgejo instance";
    };

    tailnetHostname = mkOption {
      type = types.nullOr types.str;
      default = "forgejo";
      description = "Tailscale hostname for the service";
    };

    # Database configuration
    database = {
      enable = mkOption {
        type = types.bool;
        default = true;
        description = "Enable local PostgreSQL database";
      };

      createDB = mkOption {
        type = types.bool;
        default = true;
        description = "Automatically create the database";
      };

      name = mkOption {
        type = types.str;
        default = "forgejo";
        description = "Database name";
      };

      user = mkOption {
        type = types.str;
        default = "forgejo";
        description = "Database user";
      };

      host = mkOption {
        type = types.str;
        default = "localhost";
        description = "Database host";
      };

      port = mkOption {
        type = types.port;
        default = 5432;
        description = "Database port";
      };

      passwordFile = mkOption {
        type = types.nullOr types.path;
        default = null;
        description = "File containing database password";
      };
    };

    # Feature flags
    features = {
      actions = mkOption {
        type = types.bool;
        default = true;
        description = "Enable Forgejo Actions (CI/CD)";
      };

      packages = mkOption {
        type = types.bool;
        default = true;
        description = "Enable package registry";
      };

      lfs = mkOption {
        type = types.bool;
        default = true;
        description = "Enable Git LFS support";
      };

      federation = mkOption {
        type = types.bool;
        default = false;
        description = "Enable ActivityPub federation";
      };
    };

    # Runner configuration (for connecting runners)
    runner = {
      tokenFile = mkOption {
        type = types.nullOr types.path;
        default = null;
        description = "File containing runner registration token";
      };
    };
  };

  config = mkIf cfg.enable {
    # Ensure user exists
    users.users.${cfg.user} = {
      isSystemUser = true;
      group = cfg.group;
      home = cfg.stateDir;
      createHome = true;
      description = "Forgejo user";
    };

    # Ensure group exists
    users.groups.${cfg.group} = {};

    # Use centralized PostgreSQL configuration module
    # Enable via services.clubcotton.postgresql.forgejo.enable = true
    # This ensures proper database setup, password management, and backup integration

    # Create directories
    systemd.tmpfiles.rules =
      [
        "d '${cfg.stateDir}' 0750 ${cfg.user} ${cfg.group} - -"
      ]
      ++ optionals (cfg.customPath != null) [
        "d '${cfg.customPath}' 0750 ${cfg.user} ${cfg.group} - -"
        "d '${cfg.customPath}/repositories' 0750 ${cfg.user} ${cfg.group} - -"
        "d '${cfg.customPath}/lfs' 0750 ${cfg.user} ${cfg.group} - -"
        "d '${cfg.customPath}/data' 0750 ${cfg.user} ${cfg.group} - -"
        "d '${cfg.customPath}/packages' 0750 ${cfg.user} ${cfg.group} - -"
      ];

    # Forgejo service
    services.forgejo = {
      enable = true;
      package = cfg.package;
      user = cfg.user;
      group = cfg.group;
      stateDir = cfg.stateDir;

      database = {
        type = "postgres";
        host = cfg.database.host;
        port = cfg.database.port;
        name = cfg.database.name;
        user = cfg.database.user;
        passwordFile = cfg.database.passwordFile;
      };

      settings = {
        server = {
          DOMAIN = cfg.domain;
          HTTP_PORT = cfg.port;
          ROOT_URL =
            if (cfg.tailnetHostname != null && cfg.tailnetHostname != "")
            then "https://${cfg.tailnetHostname}.bobtail-clownfish.ts.net/"
            else "http://${cfg.domain}:${toString cfg.port}/";
          SSH_DOMAIN = cfg.domain;
          SSH_PORT = cfg.sshPort;
          START_SSH_SERVER = true;
          BUILTIN_SSH_SERVER_USER = cfg.user;
          # Bind to all interfaces for local network access
          HTTP_ADDR = "0.0.0.0";
          SSH_LISTEN_HOST = "0.0.0.0";
          SSH_LISTEN_PORT = cfg.sshPort;
        };

        service = {
          DISABLE_REGISTRATION = true;
          REQUIRE_SIGNIN_VIEW = false;
          DEFAULT_KEEP_EMAIL_PRIVATE = true;
          DEFAULT_ALLOW_CREATE_ORGANIZATION = true;
          DEFAULT_ENABLE_TIMETRACKING = true;
        };

        repository = {
          ROOT = mkIf (cfg.customPath != null) (mkForce "${cfg.customPath}/repositories");
          DEFAULT_BRANCH = "main";
          DEFAULT_PRIVATE = "private";
          ENABLE_PUSH_CREATE_USER = true;
          ENABLE_PUSH_CREATE_ORG = true;
        };

        "repository.local" = mkIf cfg.features.lfs {
          LOCAL_COPY_PATH = mkIf (cfg.customPath != null) "${cfg.customPath}/data";
        };

        lfs = mkIf cfg.features.lfs {
          ENABLE = true;
          PATH = mkIf (cfg.customPath != null) "${cfg.customPath}/lfs";
          STORAGE_TYPE = "local";
        };

        actions = mkIf cfg.features.actions {
          ENABLED = true;
          DEFAULT_ACTIONS_URL = "https://code.forgejo.org";
        };

        metrics = {
          ENABLED = true;
        };

        packages = mkIf cfg.features.packages {
          ENABLED = true;
          STORAGE_TYPE = "local";
          MINIO_BASE_PATH = mkIf (cfg.customPath != null) "${cfg.customPath}/packages";
        };

        federation = mkIf cfg.features.federation {
          ENABLED = true;
        };

        session = {
          PROVIDER = "db";
          COOKIE_SECURE = false; # Set to true if using HTTPS
        };

        log = {
          MODE = "console";
          LEVEL = "Info";
        };

        security = {
          INSTALL_LOCK = true;
          MIN_PASSWORD_LENGTH = 8;
          PASSWORD_COMPLEXITY = "lower,upper,digit";
        };
      };
    };

    # Ensure Forgejo starts after PostgreSQL when database is enabled
    # and add custom path to ReadWritePaths if configured
    systemd.services.forgejo = mkMerge [
      (mkIf cfg.database.enable {
        after = ["postgresql.service"];
        requires = ["postgresql.service"];
      })
      (mkIf (cfg.customPath != null) {
        after = ["systemd-tmpfiles-setup.service"];
        serviceConfig.ReadWritePaths = [
          cfg.customPath
          "${cfg.customPath}/repositories"
          "${cfg.customPath}/lfs"
          "${cfg.customPath}/data"
          "${cfg.customPath}/packages"
        ];
      })
    ];

    # Tailscale service
    services.tsnsrv = mkMerge [
      (mkIf (cfg.tailnetHostname != null && cfg.tailnetHostname != "") {
        enable = true;
        defaults.authKeyPath = clubcotton.tailscaleAuthKeyPath;
        services = optionalAttrs (cfg.tailnetHostname != null && cfg.tailnetHostname != "") {
          "${cfg.tailnetHostname}" = {
            ephemeral = true;
            toURL = "http://127.0.0.1:${toString cfg.port}/";
          };
        };
      })
    ];

    # Open firewall for local network access
    networking.firewall.allowedTCPPorts = [cfg.port cfg.sshPort];

    # Service assertions
    assertions = [
      {
        assertion = cfg.database.enable -> cfg.database.passwordFile != null;
        message = "Database password file must be specified when local PostgreSQL is enabled";
      }
    ];
  };
}
