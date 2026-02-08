{
  config,
  lib,
  pkgs,
  ...
}:
with lib; let
  service = "freshrss";
  cfg = config.services.clubcotton.freshrss;
  clubcotton = config.clubcotton;
in {
  options.services.clubcotton.freshrss = {
    enable = mkEnableOption "FreshRSS RSS aggregator and reader";

    extensions = mkOption {
      type = types.listOf types.package;
      default = [];
      description = "Additional extensions to be used.";
    };

    port = mkOption {
      type = types.port;
      default = 8080;
    };

    passwordFile = mkOption {
      type = types.nullOr types.path;
      default = null;
      description = "Password for the defaultUser for FreshRSS.";
      example = "/run/secrets/freshrss";
    };

    authType = mkOption {
      type = types.enum ["form" "http_auth" "none"];
      default = "form";
      description = "Authentication type for FreshRSS.";
    };

    tailnetHostname = mkOption {
      type = types.str;
      default = "${service}";
    };

    openFirewall = mkOption {
      type = types.bool;
      default = true;
      description = "Whether to open the firewall port for FreshRSS.";
    };
    homepage.name = lib.mkOption {
      type = lib.types.str;
      default = "FreshRSS";
    };
    homepage.description = lib.mkOption {
      type = lib.types.str;
      default = "RSS feed aggregator";
    };
    homepage.icon = lib.mkOption {
      type = lib.types.str;
      default = "freshrss.svg";
    };
    homepage.category = lib.mkOption {
      type = lib.types.str;
      default = "Content";
    };
  };

  config = mkIf cfg.enable {
    services.freshrss = {
      enable = cfg.enable;
      passwordFile = cfg.passwordFile;
      baseUrl = "https://freshrss.bobtail-clownfish.ts.net";
      virtualHost = "freshrss";
      authType = cfg.authType;
      extensions = cfg.extensions;
      database = {
        type = "pgsql";
        host = "nas-01.lan";
        port = 5432;
        passFile = config.age.secrets."freshrss-database-raw".path;
      };
    };

    services.nginx.virtualHosts."freshrss" = {
      listen = [
        {
          addr = "0.0.0.0";
          port = cfg.port;
        }
      ];

      extraConfig = ''
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_set_header Host $host;

        # PHP Session handling
        fastcgi_param PHP_VALUE "session.cookie_httponly=1; session.cookie_secure=1; session.use_only_cookies=1";
        fastcgi_param HTTPS on;
        fastcgi_param HTTP_PROXY "";

        # Cookie handling
        proxy_cookie_path / "/; secure; HttpOnly; SameSite=Strict";
        proxy_cookie_domain $host $host;

        # Additional security headers
        add_header X-Content-Type-Options nosniff;
        add_header X-Frame-Options SAMEORIGIN;
        add_header X-XSS-Protection "1; mode=block";
      '';
    };

    services.tsnsrv = {
      enable = true;
      defaults.authKeyPath = clubcotton.tailscaleAuthKeyPath;

      services."${cfg.tailnetHostname}" = mkIf (cfg.tailnetHostname != "") {
        ephemeral = true;
        toURL = "http://127.0.0.1:${toString cfg.port}/";
      };
    };

    networking.firewall.allowedTCPPorts = mkIf cfg.openFirewall [cfg.port];
  };
}
