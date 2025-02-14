{
  config,
  lib,
  pkgs,
  ...
}:
with lib; let
  service = "filebrowser";
  cfg = config.services.clubcotton.filebrowser;
  clubcotton = config.clubcotton;
in {
  options.services.clubcotton.filebrowser = {
    enable = mkEnableOption "Filebrowser web file manager";

    port = mkOption {
      type = types.port;
      default = 8082;
      description = "Port to run Filebrowser on";
    };

    dataDir = mkOption {
      type = types.str;
      default = "/var/lib/filebrowser";
      description = "Directory to store Filebrowser data";
    };

    filesDir = mkOption {
      type = types.str;
      default = "/var/lib/filebrowser/files";
      description = "Directory to serve files from";
    };

    user = mkOption {
      type = types.str;
      default = clubcotton.user;
      description = "User to run Filebrowser as";
    };

    group = mkOption {
      type = types.str;
      default = clubcotton.group;
      description = "Group to run Filebrowser as";
    };

    tailnetHostname = mkOption {
      type = types.str;
      default = "";
      description = "Tailscale hostname for the service";
    };
  };

  config = mkIf cfg.enable {
    virtualisation.oci-containers.containers.filebrowser = {
      image = "filebrowser/filebrowser:latest";
      autoStart = true;
      volumes = [
        "${cfg.filesDir}:/srv"
        "${cfg.dataDir}/database.db:/database/filebrowser.db"
        "${cfg.dataDir}/settings.json:/config/settings.json"
      ];
      environment = {
        PUID = toString config.users.users.share.uid;
        PGID = toString config.users.groups.share.gid;
      };
      ports = ["${toString cfg.port}:80"];
    };

    systemd.tmpfiles.rules = [
      "d ${cfg.dataDir} 0755 ${cfg.user} ${cfg.group} -"
      "d ${cfg.filesDir} 0755 ${cfg.user} ${cfg.group} -"
      "f ${cfg.dataDir}/database.db 0644 ${cfg.user} ${cfg.group} -"
      "f ${cfg.dataDir}/settings.json 0644 ${cfg.user} ${cfg.group} - "
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
