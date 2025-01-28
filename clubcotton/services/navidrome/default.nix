{
  config,
  pkgs,
  lib,
  ...
}:
with lib; let
  service = "navidrome";
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
    services.${service} = {
      enable = true;

      user = clubcotton.user;
      group = clubcotton.group;

      settings = {
        MusicFolder = "/media/music";
        DefaultDownsamplingFormat = "aac";
      };


    };
    systemd.services.navidrome.serviceConfig = {
        EnvironmentFile = config.age.secrets.navidrome.path;
    };
    services.tsnsrv = {
      enable = true;
      defaults.authKeyPath = clubcotton.tailscaleAuthKeyPath;

      services."${cfg.tailnetHostname}" = mkIf (cfg.tailnetHostname != "") {
        ephemeral = true;
        toURL = "http://127.0.0.1:${toString config.services.navidrome.settings.Port}/";
      };
    };
  };
}
