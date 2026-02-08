{
  config,
  lib,
  unstablePkgs,
  ...
}:
with lib; let
  service = "lidarr";
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
      default = "Lidarr";
    };
    homepage.description = lib.mkOption {
      type = lib.types.str;
      default = "Music collection manager";
    };
    homepage.icon = lib.mkOption {
      type = lib.types.str;
      default = "lidarr.svg";
    };
    homepage.category = lib.mkOption {
      type = lib.types.str;
      default = "Arr";
    };
  };
  config = lib.mkIf cfg.enable {
    services.${service} = {
      enable = true;
      openFirewall = true;
      user = clubcotton.user;
      group = clubcotton.group;
      package = unstablePkgs.${service};
    };

    services.tsnsrv = {
      enable = true;
      defaults.authKeyPath = clubcotton.tailscaleAuthKeyPath;

      services."${cfg.tailnetHostname}" = mkIf (cfg.tailnetHostname != "") {
        ephemeral = true;
        toURL = "http://127.0.0.1:8686/";
      };
    };
  };
}
