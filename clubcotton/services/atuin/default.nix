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

    openFirewall = mkOption {
      type = types.bool;
      default = true;
      description = "Whether to open the firewall port for Atuin.";
    };
    homepage.name = lib.mkOption {
      type = lib.types.str;
      default = "Atuin";
    };
    homepage.description = lib.mkOption {
      type = lib.types.str;
      default = "Shell history sync server";
    };
    homepage.icon = lib.mkOption {
      type = lib.types.str;
      default = "atuin.png";
    };
    homepage.category = lib.mkOption {
      type = lib.types.str;
      default = "Infrastructure";
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

    networking.firewall.allowedTCPPorts = mkIf cfg.openFirewall [config.services.atuin.port];
  };
}
