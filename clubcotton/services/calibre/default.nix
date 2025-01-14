{
  config,
  lib,
  unstablePkgs,
  ...
}:
with lib; let
  service = "calibre";
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
      default = "";
      description = "The tailnet hostname to expose the code-server as.";
    };
  };
  config = lib.mkIf cfg.enable {
    services.calibre-server = {
      enable = true;
      port = 8111;
      libraries = [
        "/media/books/epub/calibre"
      ];
      user = clubcotton.user;
      group = clubcotton.group;
      auth.enable = false;
    };

    services.tsnsrv = {
      enable = true;
      defaults.authKeyPath = clubcotton.tailscaleAuthKeyPath;

      services."${cfg.tailnetHostname}" = mkIf (cfg.tailnetHostname != "") {
        ephemeral = true;
        toURL = "http://127.0.0.1:8111/";
      };
    };
  };
}
