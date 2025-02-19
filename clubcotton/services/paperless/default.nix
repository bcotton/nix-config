{
  config,
  lib,
  pkgs,
  unstablePkgs,
  ...
}:
with lib; let
  service = "paperless";
  cfg = config.services.clubcotton.paperless;
  clubcotton = config.clubcotton;
in {
  options.services.clubcotton.paperless = {
    enable = mkEnableOption "PDF reader and archiver for documents.";
    user = mkOption {
      type = types.str;
      default = "paperless";
    };
    port = mkOption {
      type = lib.types.port;
      default = 28981;
    };
    mediaDir = lib.mkOption {
      type = lib.types.str;
      default = "/var/lib/paperless/media";
    };
    configDir = lib.mkOption {
      type = lib.types.str;
      default = "/var/lib/paperless";
    };
    consumptionDir = lib.mkOption {
      type = lib.types.str;
      default = "/var/lib/paperless/consumption";
    };
    passwordFile = lib.mkOption {
      type = lib.types.path;
    };
    database.createLocally = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Configure local PostgreSQL database server for Paperless.
      '';
    };

    tailnetHostname = mkOption {
      type = types.str;
      default = "${service}";
    };
  };

  config = mkIf cfg.enable {
    systemd.tmpfiles.rules = [
      "d '${cfg.mediaDir}' 0750 ${cfg.user} ${cfg.user} - -"
      "d '${cfg.configDir}' 0750 ${cfg.user} ${cfg.user} - -"
      "d '${cfg.consumptionDir}' 0777 ${cfg.user} ${cfg.user} - -"
    ];

    systemd.services = builtins.listToAttrs (map (serviceName: {
        name = serviceName;
        value = {
          serviceConfig = {
            StateDirectory = "paperless";
            EnvironmentFile = config.age.secrets."paperless-database-raw".path;
            PrivateNetwork = lib.mkForce false;
          };
        };
      }) [
        "paperless"
        "paperless-consumer"
        "paperless-scheduler"
        "paperless-task-queue"
        "paperless-web"
      ]);

    services.paperless = {
      enable = true;
      package = unstablePkgs.paperless-ngx;
      passwordFile = cfg.passwordFile;
      user = cfg.user;
      mediaDir = cfg.mediaDir;
      consumptionDir = cfg.consumptionDir;
      consumptionDirIsPublic = true;
      settings = {
        PAPERLESS_CONSUMER_IGNORE_PATTERN = [
          ".DS_STORE/*"
          "desktop.ini"
        ];
        PAPERLESS_OCR_LANGUAGE = "eng";
        PAPERLESS_OCR_USER_ARGS = {
          optimize = 1;
          pdfa_image_compression = "lossless";
        };
        PAPERLESS_DBENGINE = "postgresql";
        PAPERLESS_DBHOST = "nas-01.lan";
        PAPERLESS_DBPORT = "5432";
        PAPERLESS_DBPASS = "{env}PAPERLESS_DBPASS";
        PAPERLESS_CONSUMER_RECURSIVE = "true";
        PAPERLESS_CONSUMER_SUBDIRS_AS_TAGS = "false";
        PAPERLESS_TASK_WORKERS = "10";
      };
    };

    services.tsnsrv = {
      enable = true;
      defaults.authKeyPath = clubcotton.tailscaleAuthKeyPath;

      services."${cfg.tailnetHostname}" = mkIf (cfg.tailnetHostname != "") {
        ephemeral = true;
        toURL = "http://127.0.0.1:${toString cfg.port}/";
      };
    };
  };
}
