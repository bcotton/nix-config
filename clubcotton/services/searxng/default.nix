{
  config,
  lib,
  pkgs,
  ...
}:
with lib; let
  service = "searxng";
  cfg = config.services.clubcotton.${service};
  clubcotton = config.clubcotton;
in {
  options.services.clubcotton.${service} = {
    enable = mkEnableOption "SearXNG privacy-respecting metasearch engine";

    port = mkOption {
      type = types.port;
      default = 8888;
    };

    environmentFile = mkOption {
      type = types.nullOr types.path;
      default = null;
      description = "Path to environment file containing SEARXNG_SECRET.";
      example = "/run/secrets/searxng";
    };

    redisCreateLocally = mkOption {
      type = types.bool;
      default = true;
      description = "Whether to create a local Redis instance for rate limiting and caching.";
    };

    tailnetHostname = mkOption {
      type = types.str;
      default = "${service}";
    };

    openFirewall = mkOption {
      type = types.bool;
      default = true;
      description = "Whether to open the firewall port for SearXNG.";
    };

    homepage.name = lib.mkOption {
      type = lib.types.str;
      default = "SearXNG";
    };
    homepage.description = lib.mkOption {
      type = lib.types.str;
      default = "Privacy-respecting metasearch engine";
    };
    homepage.icon = lib.mkOption {
      type = lib.types.str;
      default = "searxng.svg";
    };
    homepage.category = lib.mkOption {
      type = lib.types.str;
      default = "Content";
    };
  };

  config = mkIf cfg.enable {
    services.searx = {
      enable = true;
      redisCreateLocally = cfg.redisCreateLocally;
      environmentFile = cfg.environmentFile;

      settings = {
        server = {
          port = cfg.port;
          bind_address = "0.0.0.0";
          secret_key = "@SEARXNG_SECRET@";
          limiter = cfg.redisCreateLocally;
          image_proxy = true;
        };
        ui = {
          static_use_hash = true;
        };
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
