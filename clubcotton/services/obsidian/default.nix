{
  config,
  lib,
  pkgs,
  ...
}:
with lib; let
  cfg = config.services.clubcotton.obsidian;
  clubcotton = config.clubcotton;
in {
  options.services.clubcotton.obsidian = {
    enable = mkEnableOption "Obsidian containerized web instances";

    openFirewall = mkOption {
      type = types.bool;
      default = true;
      description = "Whether to open the firewall ports for all Obsidian instances.";
    };

    instances = mkOption {
      type = types.attrsOf (types.submodule ({name, ...}: {
        options = {
          httpPort = mkOption {
            type = types.port;
            default = 13000;
            description = "HTTP port for the Obsidian web interface";
          };

          httpsPort = mkOption {
            type = types.port;
            default = 13001;
            description = "HTTPS port for the Obsidian web interface";
          };

          configDir = mkOption {
            type = types.str;
            default = "/var/lib/obsidian-${name}";
            description = "Directory to store Obsidian app configuration";
          };

          vaultDir = mkOption {
            type = types.str;
            description = "User's vault directory, mounted at /vaults in container";
          };

          user = mkOption {
            type = types.str;
            default = name;
            description = "User to run Obsidian as";
          };

          group = mkOption {
            type = types.str;
            default = "users";
            description = "Group to run Obsidian as";
          };

          timezone = mkOption {
            type = types.str;
            default = "America/Denver";
            description = "Timezone for Obsidian";
          };

          shmSize = mkOption {
            type = types.str;
            default = "1g";
            description = "Shared memory size for Electron stability";
          };

          tailnetHostname = mkOption {
            type = types.str;
            default = "obsidian-${name}";
            description = "Tailscale hostname for the service";
          };

          sshDir = mkOption {
            type = types.nullOr types.str;
            default = null;
            description = ''
              Path to SSH directory containing keys for git operations.
              Will be mounted read-only at /config/.ssh in the container.
              Can be the user's ~/.ssh or a dedicated directory with specific keys.
            '';
            example = "/home/bcotton/.ssh";
          };

          basicAuth = {
            enable = mkOption {
              type = types.bool;
              default = false;
              description = "Enable HTTP Basic Authentication";
            };

            username = mkOption {
              type = types.str;
              default = name;
              description = "Username for HTTP Basic Auth";
            };

            environmentFile = mkOption {
              type = types.nullOr types.path;
              default = null;
              description = ''
                Path to environment file containing PASSWORD=<secret>.
                Can be an agenix secret. The file should contain:
                PASSWORD=your-secret-password
              '';
            };
          };
        };
      }));
      default = {};
      description = "Per-user Obsidian instance configurations";
      example = literalExpression ''
        {
          bcotton = {
            httpPort = 13000;
            httpsPort = 13001;
            vaultDir = "/home/bcotton/obsidian-vaults";
            basicAuth = {
              enable = true;
              username = "bcotton";
              environmentFile = config.age.secrets.obsidian-bcotton.path;
            };
          };
        }
      '';
    };
  };

  config = mkIf (cfg.enable && cfg.instances != {}) {
    assertions =
      mapAttrsToList (
        name: instanceCfg: {
          assertion = instanceCfg.basicAuth.enable -> instanceCfg.basicAuth.environmentFile != null;
          message = "Obsidian instance '${name}': basicAuth.environmentFile must be set when basicAuth.enable is true";
        }
      )
      cfg.instances;

    virtualisation.oci-containers.containers =
      mapAttrs' (
        name: instanceCfg:
          nameValuePair "obsidian-${name}" {
            image = "lscr.io/linuxserver/obsidian:latest";
            autoStart = true;
            environment =
              {
                PUID = toString config.users.users.${instanceCfg.user}.uid;
                PGID = toString config.users.groups.${instanceCfg.group}.gid;
                TZ = instanceCfg.timezone;
              }
              // optionalAttrs instanceCfg.basicAuth.enable {
                CUSTOM_USER = instanceCfg.basicAuth.username;
              };
            environmentFiles = optional (instanceCfg.basicAuth.enable && instanceCfg.basicAuth.environmentFile != null) instanceCfg.basicAuth.environmentFile;
            volumes =
              [
                "${instanceCfg.configDir}:/config"
                "${instanceCfg.vaultDir}:/vaults"
              ]
              ++ optional (instanceCfg.sshDir != null) "${instanceCfg.sshDir}:/config/.ssh:ro";
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

    networking.firewall.allowedTCPPorts = mkIf cfg.openFirewall (
      concatMap (instanceCfg: [instanceCfg.httpPort instanceCfg.httpsPort]) (attrValues cfg.instances)
    );
  };
}
