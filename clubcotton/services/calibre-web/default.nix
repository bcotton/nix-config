{
  config,
  lib,
  unstablePkgs,
  ...
}:
with lib; let
  service = "calibre-web";
  cfg = config.services.clubcotton.${service};
  clubcotton = config.clubcotton;
in {
  options.services.clubcotton.${service} = {
    enable = lib.mkEnableOption {
      description = "Enable ${service}";
    };
    configDir = lib.mkOption {
      type = lib.types.str;
      default = "/var/lib/${service}";
    };
    tailnetHostname = mkOption {
      type = types.nullOr types.str;
      default = "${service}";
      description = "The tailnet hostname to expose the code-server as.";
    };
    homepage.name = lib.mkOption {
      type = lib.types.str;
      default = "Calibre-Web";
    };
    homepage.description = lib.mkOption {
      type = lib.types.str;
      default = "E-book library browser";
    };
    homepage.icon = lib.mkOption {
      type = lib.types.str;
      default = "calibre-web.svg";
    };
    homepage.category = lib.mkOption {
      type = lib.types.str;
      default = "Media";
    };
  };
  config = lib.mkIf cfg.enable {
    services.calibre-web = {
      enable = true;
      listen = {
        ip = "0.0.0.0";
        port = 8112;
      };
      options = {
        calibreLibrary = "/media/books/epub/calibre";
        enableBookConversion = true;
      };
      user = clubcotton.user;
      group = clubcotton.group;
    };

    services.tsnsrv = {
      enable = true;
      defaults.authKeyPath = clubcotton.tailscaleAuthKeyPath;

      services."${cfg.tailnetHostname}" = mkIf (cfg.tailnetHostname != "") {
        ephemeral = true;
        toURL = "http://127.0.0.1:8112/";
      };
    };
  };
}
