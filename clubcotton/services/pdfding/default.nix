{
  config,
  lib,
  pkgs,
  ...
}:
with lib; let
  cfg = config.services.clubcotton.pdfding;
  clubcotton = config.clubcotton; # this fails in tests with the following error aka fuckery
in {
  options.services.clubcotton.pdfding = {
    enable = mkEnableOption "PDFDing Docker pdf hoster";

    port = mkOption {
      type = types.str;
      default = "8000";
    };

    dbDir = mkOption {
      type = types.str;
      default = "";
      description = "a full path";
    };

    mediaDir = mkOption {
      type = types.str;
      default = "";
      description = "a full path";
    };

    tailnetHostname = mkOption {
      type = types.str;
      default = "";
    };

    secretKey = mkOption {
      type = types.path;
      default = config.age.secrets.pdfding-secret-key.path;
      description = "Path to file containing the SECRET_KEY";
    };

    databasePassword = mkOption {
      type = types.path;
      default = config.age.secrets.pdfding-database-password.path;
      description = "Path to file containing the PostgreSQL password";
    };
  };

  config = mkIf cfg.enable {
    systemd.tmpfiles.rules = [
      "d ${cfg.dbDir} 0775 root root - -"
      "d ${cfg.mediaDir} 0775 root root - -"
    ];

    virtualisation.oci-containers.containers."pdfding" = {
      image = "mrmn/pdfding";
      autoStart = true;
      ports = ["${cfg.port}:${cfg.port}"];
      volumes = [
        "${cfg.dbDir}:/sqlite_data"
        "${cfg.mediaDir}:/media"
        "/home/tomcotton/tmp/consume:/home/nonroot/pdfding/consume/1"
      ];
      log-driver = "journald";
      environment = {
        HOST_NAME = "pdfding.bobtail-clownfish.ts.net, 127.0.0.1, localhost, nix-04, nas-01"; # A CSV of allowed hosts, not where it is hosted.
        HOST_PORT = cfg.port;
        SECRET_KEY = "some-secret";
        CSRF_COOKIE_SECURE = "true";
        SESSION_COOKIE_SECURE = "true";
        DATABASE_TYPE = "SQLITE";
        CONSUME_ENABLE = "true";
      };
      extraOptions = [
        "--log-level=debug"
      ];
    };

    # systemd.timers."podman-prune" = {
    #   wantedBy = [ "timers.target" ];
    #   timerConfig = {
    #     OnCalendar = "daily";
    #     Persistent = true;
    #   };
    # };

    # systemd.services."podman-prune" = {
    #   serviceConfig.Type = "oneshot";
    #   script = ''
    #     ${pkgs.podman}/bin/podman system prune -f
    #   '';
    # };

    # virtualisation.oci-containers = {
    #   containers = {
    #     pdfding = {
    #       image = "mrmn/pdfding";
    #       autoStart = true;
    #       extraOptions = [
    #         "-p ${cfg.port}:${cfg.port}" # Publish a container's port(s) to the host
    #         "-v dbDir:${dbDir} -v mediaDir:${mediaDir}"
    #       ];
    #       environment = {
    #         HOST_NAME = "127.0.0.1";
    #         HOST_PORT = cfg.port;
    #         SECRET_KEY = builtins.readFile cfg.secretKeyPath;
    #         CSRF_COOKIE_SECURE = true; # Set this to TRUE to avoid transmitting the CSRF cookie over HTTP accidentally.
    #         SESSION_COOKIE_SECURE = true; # Set this to TRUE to avoid transmitting the session cookie over HTTP accidentally.

    #         DATABASE_TYPE = "POSTGRES";
    #         POSTGRES_HOST = "postgres";
    #         POSTGRES_PASSWORD = builtins.readFile cfg.databasePasswordPath;
    #         POSTGRES_PORT = 5432;
    #       };
    #     };
    #   };
    # };

    # Expose this code-server as a host on the tailnet if tsnsrv module is available
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
