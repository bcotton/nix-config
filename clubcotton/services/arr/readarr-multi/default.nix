{
  config,
  pkgs,
  lib,
  ...
}:
with lib; let
  cfg = config.services.readarr-multi;
in {
  options = {
    services.readarr-multi = {
      instances = mkOption {
        type = types.attrsOf (types.submodule ({name, ...}: {
          options = {
            port = mkOption {
              type = types.port;
              default = 8787 + (builtins.hashString "md5" name) mod 1000;
              description = "Port for ${name} Readarr instance to listen on.";
            };

            dataDir = mkOption {
              type = types.str;
              default = "/var/lib/readarr-${name}";
              description = "The directory where ${name} Readarr instance stores its data files.";
            };

            user = mkOption {
              type = types.str;
              default = "readarr-${name}";
              description = "User account under which ${name} Readarr instance runs.";
            };

            group = mkOption {
              type = types.str;
              default = "readarr-${name}";
              description = "Group under which ${name} Readarr instance runs.";
            };

            package = mkPackageOption pkgs "readarr" {};

            openFirewall = mkOption {
              type = types.bool;
              default = false;
              description = "Open ports in the firewall for ${name} Readarr instance.";
            };
          };
        }));
        default = {};
        description = "Readarr instance configurations.";
        example = literalExpression ''
          {
            epub = {
              port = 8787;
              dataDir = "/var/lib/readarr-epub";
            };
            audio = {
              port = 8788;
              dataDir = "/var/lib/readarr-audio";
            };
          }
        '';
      };
    };
  };

  config = mkIf (cfg.instances != {}) {
    systemd.tmpfiles.settings =
      mapAttrs' (
        name: instanceCfg:
          nameValuePair "10-readarr-${name}" {
            ${instanceCfg.dataDir}.d = {
              inherit (instanceCfg) user group;
              mode = "0700";
            };
          }
      )
      cfg.instances;

    systemd.services =
      mapAttrs' (
        name: instanceCfg:
          nameValuePair "readarr-${name}" {
            description = "Readarr (${name})";
            after = ["network.target"];
            wantedBy = ["multi-user.target"];

            serviceConfig = {
              Type = "simple";
              User = instanceCfg.user;
              Group = instanceCfg.group;
              ExecStart = ''
                ${instanceCfg.package}/bin/Readarr \
                  -nobrowser \
                  -data='${instanceCfg.dataDir}' \
                  -port=${toString instanceCfg.port}
              '';
              Restart = "on-failure";
            };
          }
      )
      cfg.instances;

    networking.firewall.allowedTCPPorts = let
      enabledPorts =
        mapAttrsToList (
          name: instanceCfg:
            lib.optional instanceCfg.openFirewall instanceCfg.port
        )
        cfg.instances;
    in
      flatten enabledPorts;

    users.users =
      mapAttrs' (
        name: instanceCfg:
          nameValuePair instanceCfg.user {
            description = "Readarr service (${name})";
            home = instanceCfg.dataDir;
            group = instanceCfg.group;
            isSystemUser = true;
          }
      )
      cfg.instances;

    users.groups =
      mapAttrs' (
        name: instanceCfg:
          nameValuePair instanceCfg.group {}
      )
      cfg.instances;
  };
}
