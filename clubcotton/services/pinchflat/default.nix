{
  config,
  lib,
  pkgs,
  ...
}:
with lib; let
  service = "pinchflat";
  cfg = config.services.clubcotton.${service};
  clubcotton = config.clubcotton;
in {
  options.services.clubcotton.${service} = {
    enable = mkEnableOption "Pinchflat youtube downloader";

    port = mkOption {
      type = types.port;
      default = 8945;
      description = "Port to run Pinchflat on";
    };

    configDir = mkOption {
      type = types.str;
      default = "/var/lib/pinchflat/config";
      description = "Directory to store Pinchflat configuration";
    };

    mediaDir = mkOption {
      type = types.str;
      default = "/var/lib/pinchflat/media";
      description = "Directory to store downloaded media";
    };

    user = mkOption {
      type = types.str;
      default = "share";
      description = "User to run Pinchflat as";
    };

    group = mkOption {
      type = types.str;
      default = "share";
      description = "Group to run Pinchflat as";
    };

    timezone = mkOption {
      type = types.str;
      default = "America/Denver";
      description = "Timezone for Pinchflat";
    };

    tailnetHostname = mkOption {
      type = types.str;
      default = "${service}";
      description = "Tailscale hostname for the service";
    };
  };

  config = mkIf cfg.enable {
    virtualisation.oci-containers.containers.${service} = {
      image = "ghcr.io/kieraneglin/pinchflat:latest";
      autoStart = true;
      user = "${toString config.users.users.${cfg.user}.uid}:${toString config.users.groups.${cfg.group}.gid}";
      volumes = [
        "${cfg.configDir}:/config"
        "${cfg.mediaDir}:/downloads"
      ];
      environment = {
        TZ = cfg.timezone;
      };
      ports = ["${toString cfg.port}:${toString cfg.port}"];
    };

    systemd.tmpfiles.rules = [
      "d ${cfg.configDir} 0750 ${cfg.user} ${cfg.group} - -"
      "d ${cfg.mediaDir} 0750 ${cfg.user} ${cfg.group} - -"
    ];

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
