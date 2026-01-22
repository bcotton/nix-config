{
  config,
  lib,
  pkgs,
  unstablePkgs,
  inputs,
  ...
}:
with lib; let
  service = "immich";
  cfg = config.services.clubcotton.${service};
  clubcotton = config.clubcotton;
in {
  options.services.clubcotton.${service} = {
    enable = mkEnableOption {
      description = "Enable ${service}";
    };

    openFirewall = mkOption {
      type = types.bool;
      default = false;
      description = "Whether to open ports in the firewall for Immich.";
    };

    secretsFile = mkOption {
      type = types.nullOr (
        types.str
        // {
          # We don't want users to be able to pass a path literal here but
          # it should look like a path.
          check = it: lib.isString it && lib.types.path.check it;
        }
      );
      default = null;
      example = "/run/secrets/immich";
      description = ''
        Path of a file with extra environment variables to be loaded from disk. This file is not added to the nix store, so it can be used to pass secrets to immich. Refer to the [documentation](https://immich.app/docs/install/environment-variables) for options.

        To set a database password set this to a file containing:
        ```
        DB_PASSWORD=<pass>
        ```
      '';
    };

    tailnetHostname = mkOption {
      type = types.nullOr types.str;
      default = "${service}";
      description = "The tailnet hostname to expose the server as.";
    };

    homepage.name = mkOption {
      type = types.str;
      default = "Immich";
    };

    homepage.description = mkOption {
      type = types.str;
      default = "Self-hosted photo and video backup solution";
    };

    homepage.icon = mkOption {
      type = types.str;
      default = "immich.svg";
    };

    homepage.category = mkOption {
      type = types.str;
      default = "Media";
    };

    serverConfig = {
      host = mkOption {
        type = types.str;
        default = "0.0.0.0";
        description = "The address Immich server will listen on.";
      };

      port = mkOption {
        type = types.port;
        default = 2283;
        description = "The port Immich server will listen on.";
      };

      mediaLocation = mkOption {
        type = types.str;
        default = "/var/lib/immich";
        description = "Directory where media files will be stored.";
      };

      logLevel = mkOption {
        type = types.enum ["verbose" "debug" "log" "warn" "error"];
        default = "log";
        description = "Log level for Immich server.";
      };

      externalDomain = mkOption {
        type = types.str;
        default = "";
        description = "External domain for accessing Immich, including http(s)://.";
      };
    };

    database = {
      enable = mkOption {
        type = types.bool;
        default = false;
        description = "Whether to enable and configure the PostgreSQL database.";
      };

      createDB = mkOption {
        type = types.bool;
        default = false;
        description = "Whether to automatically create the database.";
      };

      name = mkOption {
        type = types.str;
        default = "immich";
        description = "Name of the PostgreSQL database.";
      };

      user = mkOption {
        type = types.str;
        default = "immich";
        description = "PostgreSQL user for Immich.";
      };

      host = mkOption {
        type = types.str;
        default = "localhost";
        description = "PostgreSQL server hostname or IP address.";
      };

      port = mkOption {
        type = types.port;
        default = 5432;
        description = "PostgreSQL server port number.";
      };

      password = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "PostgreSQL password for authentication. If null, password should be provided via secretsFile.";
      };
    };

    redis = {
      enable = mkOption {
        type = types.bool;
        default = true;
        description = "Whether to enable and configure Redis.";
      };
    };

    machineLearning = {
      enable = mkOption {
        type = types.bool;
        default = true;
        description = "Whether to enable machine learning features.";
      };

      workers = mkOption {
        type = types.int;
        default = 1;
        description = "Number of machine learning workers.";
      };

      workerTimeout = mkOption {
        type = types.int;
        default = 120;
        description = "Timeout in seconds for machine learning workers.";
      };
    };
  };

  config = mkIf cfg.enable {
    services.immich = {
      enable = true;
      openFirewall = cfg.openFirewall;
      secretsFile = cfg.secretsFile;

      # Server configuration
      host = cfg.serverConfig.host;
      port = cfg.serverConfig.port;
      mediaLocation = cfg.serverConfig.mediaLocation;

      # Database configuration
      database = {
        enable = cfg.database.enable;
        createDB = cfg.database.createDB;
        name = cfg.database.name;
        host = cfg.database.host;
        port = cfg.database.port;
        user = cfg.database.user;
      };

      # Redis configuration
      redis.enable = cfg.redis.enable;

      # Machine learning configuration
      machine-learning = {
        enable = cfg.machineLearning.enable;
        environment = {
          MACHINE_LEARNING_WORKERS = toString cfg.machineLearning.workers;
          MACHINE_LEARNING_WORKER_TIMEOUT = toString cfg.machineLearning.workerTimeout;
        };
      };

      # Basic settings
      settings = {
        newVersionCheck.enabled = false;
        server.externalDomain = cfg.serverConfig.externalDomain;
      };

      # Environment variables
      environment = {
        IMMICH_LOG_LEVEL = cfg.serverConfig.logLevel;
      };
    };

    # PostgreSQL configuration
    services.postgresql = mkIf cfg.database.enable {
      enable = true;
      package = pkgs.postgresql_16;
      extraPlugins = with pkgs.postgresql16Packages; [vectorchord];
      settings = {
        shared_preload_libraries = "vectors.so";
        search_path = "\"$user\", public, vectors";
      };
    };

    # Tailscale integration
    services.tsnsrv = mkIf (cfg.tailnetHostname != null && cfg.tailnetHostname != "") {
      enable = true;
      defaults.authKeyPath = clubcotton.tailscaleAuthKeyPath;

      services."${cfg.tailnetHostname}" = {
        ephemeral = true;
        toURL = "http://127.0.0.1:${toString cfg.serverConfig.port}/";
      };
    };
  };
}
