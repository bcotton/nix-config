{
  config,
  pkgs,
  lib,
  unstablePkgs,
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
    musicFolder = lib.mkOption {
      type = lib.types.str;
      default = "/media/music/curated";
      description = "The music folder path for navidrome.";
    };
    musicFolderRoot = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "Root directory for music folders. When set, this path will be added to BindReadOnlyPaths to support multi-library feature.";
    };
    tailnetHostname = mkOption {
      type = types.nullOr types.str;
      default = "${service}";
      description = "The tailnet hostname to expose the code-server as.";
    };
    homepage.name = lib.mkOption {
      type = lib.types.str;
      default = "Navidrome";
    };
    homepage.description = lib.mkOption {
      type = lib.types.str;
      default = "Music streaming server";
    };
    homepage.icon = lib.mkOption {
      type = lib.types.str;
      default = "navidrome.svg";
    };
    homepage.category = lib.mkOption {
      type = lib.types.str;
      default = "Media";
    };
  };
  config = lib.mkIf cfg.enable {
    services.${service} = {
      enable = true;
      openFirewall = true;
      package = unstablePkgs.${service};
      user = clubcotton.user;
      group = clubcotton.group;

      settings = {
        # LogLevel = "DEBUG";
        MusicFolder = cfg.musicFolder;
        Address = "0.0.0.0";
        DefaultDownsamplingFormat = "mp3";
        # EnableTranscodingConfig = true;
        AutoImportPlaylists = false;
        Prometheus.Enabled = true;
      };
    };
    systemd.services.navidrome.serviceConfig = {
      EnvironmentFile = config.age.secrets.navidrome.path;
      BindReadOnlyPaths = lib.mkIf (cfg.musicFolderRoot != null) [
        cfg.musicFolderRoot
      ];
    };
    services.tsnsrv = {
      enable = true;
      defaults.authKeyPath = clubcotton.tailscaleAuthKeyPath;

      services."${cfg.tailnetHostname}" = mkIf (cfg.tailnetHostname != "") {
        ephemeral = true;
        toURL = "http://0.0.0.0:${toString config.services.navidrome.settings.Port}/";
      };
    };
  };
}
