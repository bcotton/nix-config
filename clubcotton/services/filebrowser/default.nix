{
  config,
  lib,
  pkgs,
  ...
}:
with lib; let
  service = "filebrowser";
  cfg = config.services.clubcotton.${service};
  clubcotton = config.clubcotton;
in {
  options.services.clubcotton.${service} = {
    enable = mkEnableOption "Filebrowser web file manager";

    port = mkOption {
      type = types.port;
      default = 8082;
      description = "Port to run Filebrowser on";
    };

    dataDir = mkOption {
      type = types.str;
      default = "/var/lib/${service}";
      description = "Directory to store Filebrowser data";
    };

    filesDir = mkOption {
      type = types.str;
      default = "/var/lib/${service}/files";
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
      default = "${service}";
      description = "Tailscale hostname for the service";
    };

    openFirewall = mkOption {
      type = types.bool;
      default = true;
      description = "Whether to open the firewall port for Filebrowser.";
    };
    homepage.name = lib.mkOption {
      type = lib.types.str;
      default = "File Browser";
    };
    homepage.description = lib.mkOption {
      type = lib.types.str;
      default = "Web-based file manager";
    };
    homepage.icon = lib.mkOption {
      type = lib.types.str;
      default = "filebrowser.svg";
    };
    homepage.category = lib.mkOption {
      type = lib.types.str;
      default = "Content";
    };
  };

  config = mkIf cfg.enable {
    virtualisation.oci-containers.containers.${service} = {
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

    networking.firewall.allowedTCPPorts = mkIf cfg.openFirewall [cfg.port];
  };
}
