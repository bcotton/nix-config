{
  config,
  lib,
  ...
}:
with lib; let
  service = "ntfy";
  cfg = config.services.clubcotton.${service};
  clubcotton = config.clubcotton;
in {
  options.services.clubcotton.${service} = {
    enable = mkEnableOption "ntfy.sh push notification server";

    port = mkOption {
      type = types.port;
      default = 2586;
      description = "HTTP listen port for ntfy.";
    };

    baseURL = mkOption {
      type = types.str;
      description = "Public-facing base URL of the ntfy instance (e.g. https://ntfy.example.com).";
    };

    behindProxy = mkOption {
      type = types.bool;
      default = true;
      description = "Whether ntfy is behind a reverse proxy (tsnsrv).";
    };

    tailnetHostname = mkOption {
      type = types.str;
      default = "${service}";
      description = "Tailscale hostname for the service.";
    };

    openFirewall = mkOption {
      type = types.bool;
      default = true;
      description = "Whether to open the firewall port for ntfy.";
    };

    homepage.name = lib.mkOption {
      type = lib.types.str;
      default = "ntfy";
    };
    homepage.description = lib.mkOption {
      type = lib.types.str;
      default = "Push notifications";
    };
    homepage.icon = lib.mkOption {
      type = lib.types.str;
      default = "ntfy.svg";
    };
    homepage.category = lib.mkOption {
      type = lib.types.str;
      default = "Infrastructure";
    };
  };

  config = mkIf cfg.enable {
    services.ntfy-sh = {
      enable = true;
      settings = {
        base-url = cfg.baseURL;
        listen-http = "127.0.0.1:${toString cfg.port}";
        behind-proxy = cfg.behindProxy;
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

    networking.firewall.allowedTCPPorts = mkIf cfg.openFirewall [cfg.port];
  };
}
