{
  config,
  pkgs,
  lib,
  ...
}:
with lib; let
  service = "atuin";
  cfg = config.services.clubcotton.${service};
  clubcotton = config.clubcotton;
in {
  options.services.clubcotton.${service} = {
    enable = lib.mkEnableOption {
      description = "Enable ${service}";
    };
    tailnetHostname = mkOption {
      type = types.nullOr types.str;
      default = "${service}";
      description = "The tailnet hostname to expose the code-server as.";
    };
  };
  config = lib.mkIf cfg.enable {
    services.${service} = {
      enable = true;
      openRegistration = true;
      host = "0.0.0.0";
      database.uri = null;
    };
    systemd.services.atuin.serviceConfig = {
      EnvironmentFile = config.age.secrets.atuin.path;
    };
    services.tsnsrv = {
      enable = true;
      defaults.authKeyPath = clubcotton.tailscaleAuthKeyPath;

      services."${cfg.tailnetHostname}" = mkIf (cfg.tailnetHostname != "") {
        ephemeral = true;
        toURL = "http://0.0.0.0:${toString config.services.atuin.port}/";
      };
    };
  };
}
