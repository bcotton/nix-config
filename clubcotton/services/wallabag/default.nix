{
  config,
  lib,
  pkgs,
  ...
}:
with lib; let
  service = "wallabag";
  cfg = config.services.clubcotton.${service};
  clubcotton = config.clubcotton;
in {
  options.services.clubcotton.${service} = {
    enable = mkEnableOption "Wallabag web article archiver";

    port = mkOption {
      type = types.port;
      default = 9880;
      description = "Port to run Wallabag on";
    };

    dataDir = mkOption {
      type = types.str;
      default = "/var/lib/${service}";
      description = "Directory to store Wallabag data";
    };

    user = mkOption {
      type = types.str;
      default = "${service}";
      description = "User to run Wallabag as";
    };

    group = mkOption {
      type = types.str;
      default = "${service}";
      description = "Group to run Wallabag as";
    };

    secret = mkOption {
      type = types.str;
      default = "some_secret_string_for_wallabag";
      description = "Secret string for Wallabag";
    };

    memoryLimit = mkOption {
      type = types.str;
      default = "256M";
      description = "PHP memory limit for Wallabag";
    };

    tailnetHostname = mkOption {
      type = types.str;
      default = "${service}";
      description = "Tailscale hostname for the service";
    };
    homepage.name = lib.mkOption {
      type = lib.types.str;
      default = "Wallabag";
    };
    homepage.description = lib.mkOption {
      type = lib.types.str;
      default = "Read-it-later service";
    };
    homepage.icon = lib.mkOption {
      type = lib.types.str;
      default = "wallabag.svg";
    };
    homepage.category = lib.mkOption {
      type = lib.types.str;
      default = "Content";
    };
  };

  config = mkIf cfg.enable {
    users.users.${cfg.user} = {
      isSystemUser = true;
      group = cfg.group;
    };

    users.groups.${cfg.group} = {};

    virtualisation.oci-containers.containers.${service} = {
      image = "wallabag/wallabag";
      autoStart = true;
      environment = {
        SYMFONY__ENV__DOMAIN_NAME = "https://wallabag.bobtail-clownfish.ts.net";
        SYMFONY__ENV__DATABASE_DRIVER = "pdo_sqlite";
        SYMFONY__ENV__SECRET = cfg.secret;
        PHP_MEMORY_LIMIT = cfg.memoryLimit;
        POPULATE_DATABASE = "True";
        SYMFONY__ENV__DATABASE_TABLE_PREFIX = "wallabag_";
        SYMFONY__ENV__FOSUSER_REGISTRATION = "True";
      };
      volumes = [
        "${cfg.dataDir}/data:/var/www/wallabag/data"
        "${cfg.dataDir}/images:/var/www/wallabag/web/assets/images"
      ];
      ports = ["${toString cfg.port}:80"];
    };

    systemd.tmpfiles.rules = [
      "d ${cfg.dataDir}/data 0777 ${cfg.user} ${cfg.group} - -"
      "d ${cfg.dataDir}/images 0777 ${cfg.user} ${cfg.group} - -"
      "f ${cfg.dataDir}/data/wallabag.sqlite 0666 ${cfg.user} ${cfg.group} - -"
    ];

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
