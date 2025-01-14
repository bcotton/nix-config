{
  config,
  lib,
  ...
}:
with lib; let
  service = "readarr";
  cfg = config.services.clubcotton.${service};
  clubcotton = config.clubcotton;
in {
  options.services.clubcotton.${service} = let
    instanceOpts = types.submodule {
      options = {
        tailnetHostname = mkOption {
          type = types.nullOr types.str;
          default = null;
          description = "The tailnet hostname to expose this readarr instance as.";
        };

        port = mkOption {
          type = types.port;
          default = 8787;
          description = "Port for Readarr instance to listen on.";
        };

        dataDir = mkOption {
          type = types.str;
          description = "The directory where Readarr instance stores its data files.";
        };
      };
    };
  in {
    enable = lib.mkEnableOption {
      description = "Enable ${service}";
    };

    epub = mkOption {
      type = types.nullOr instanceOpts;
      default = null;
      description = "Configuration for epub Readarr instance.";
    };

    audio = mkOption {
      type = types.nullOr instanceOpts;
      default = null;
      description = "Configuration for audio Readarr instance.";
    };
  };

  config = lib.mkIf cfg.enable {
    services.readarr-multi.instances = let
      mkInstance = name: cfg:
        lib.mkIf (cfg != null) {
          ${name} = {
            inherit (cfg) port dataDir;
            user = clubcotton.user;
            group = clubcotton.group;
            openFirewall = true;
          };
        };
    in
      lib.mkMerge [
        (mkInstance "epub" cfg.epub)
        (mkInstance "audio" cfg.audio)
      ];

    services.tsnsrv = {
      enable = true;
      defaults.authKeyPath = clubcotton.tailscaleAuthKeyPath;

      services = let
        mkService = cfg:
          lib.mkIf (cfg != null && cfg.tailnetHostname != null) {
            ${cfg.tailnetHostname} = {
              # enable = true;
              ephemeral = true;
              toURL = "http://127.0.0.1:${toString cfg.port}/";
            };
          };
      in
        lib.mkMerge [
          (mkService cfg.epub)
          (mkService cfg.audio)
        ];
    };
  };
}
