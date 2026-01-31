{
  config,
  lib,
  ...
}:
with lib; let
  service = "obsidian";
  cfg = config.services.clubcotton.${service};
  clubcotton = config.clubcotton;
in {
  options.services.clubcotton.${service} = {
    enable = mkEnableOption "Obsidian containerized web instances";

    instances = mkOption {
      type = types.attrsOf (types.submodule ({name, ...}: {
        options = {
          httpPort = mkOption {
            type = types.port;
            default = 13000;
            description = "HTTP port for ${name} Obsidian instance (container port 3000).";
          };

          httpsPort = mkOption {
            type = types.port;
            default = 13001;
            description = "HTTPS port for ${name} Obsidian instance (container port 3001).";
          };

          configDir = mkOption {
            type = types.str;
            default = "/var/lib/obsidian-${name}";
            description = "Directory to store Obsidian app settings and state for ${name}.";
          };

          vaultDir = mkOption {
            type = types.str;
            description = "User's vault directory, mounted at /vaults in container.";
          };

          user = mkOption {
            type = types.str;
            default = name;
            description = "User to run ${name} Obsidian instance as.";
          };

          group = mkOption {
            type = types.str;
            default = "users";
            description = "Group to run ${name} Obsidian instance as.";
          };

          timezone = mkOption {
            type = types.str;
            default = "America/Denver";
            description = "Timezone for ${name} Obsidian instance.";
          };

          shmSize = mkOption {
            type = types.str;
            default = "1g";
            description = "Shared memory size for Electron stability.";
          };

          tailnetHostname = mkOption {
            type = types.str;
            default = "obsidian-${name}";
            description = "Tailscale hostname for ${name} Obsidian instance.";
          };
        };
      }));
      default = {};
      description = "Obsidian instance configurations.";
      example = literalExpression ''
        {
          bcotton = {
            httpPort = 13000;
            httpsPort = 13001;
            user = "bcotton";
            vaultDir = "/home/bcotton/obsidian-vaults";
          };
        }
      '';
    };
  };

  config = mkIf cfg.enable {
    virtualisation.oci-containers.containers =
      mapAttrs' (
        name: instanceCfg:
          nameValuePair "obsidian-${name}" {
            image = "lscr.io/linuxserver/obsidian:latest";
            autoStart = true;
            user = "${toString config.users.users.${instanceCfg.user}.uid}:${toString config.users.groups.${instanceCfg.group}.gid}";
            volumes = [
              "${instanceCfg.configDir}:/config"
              "${instanceCfg.vaultDir}:/vaults"
            ];
            environment = {
              TZ = instanceCfg.timezone;
            };
            ports = [
              "${toString instanceCfg.httpPort}:3000"
              "${toString instanceCfg.httpsPort}:3001"
            ];
            extraOptions = [
              "--shm-size=${instanceCfg.shmSize}"
            ];
          }
      )
      cfg.instances;

    systemd.tmpfiles.settings =
      mapAttrs' (
        name: instanceCfg:
          nameValuePair "10-obsidian-${name}" {
            ${instanceCfg.configDir}.d = {
              user = instanceCfg.user;
              group = instanceCfg.group;
              mode = "0750";
            };
          }
      )
      cfg.instances;

    services.tsnsrv = {
      enable = true;
      defaults.authKeyPath = clubcotton.tailscaleAuthKeyPath;

      services =
        mapAttrs' (
          name: instanceCfg:
            nameValuePair instanceCfg.tailnetHostname {
              ephemeral = true;
              toURL = "http://127.0.0.1:${toString instanceCfg.httpPort}/";
            }
        )
        cfg.instances;
    };
  };
}
