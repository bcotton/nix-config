{
  config,
  lib,
  pkgs,
  ...
}:
with lib; let
  cfg = config.services.clubcotton.postgresql;
in {
  options.services.clubcotton.postgresql = {
    atuin = {
      enable = mkEnableOption "Atuin database support";

      database = mkOption {
        type = types.str;
        default = "atuin";
        description = "Name of the Atuin database.";
      };

      user = mkOption {
        type = types.str;
        default = "atuin";
        description = "Name of the Atuin database user.";
      };

      passwordFile = mkOption {
        type = types.nullOr types.path;
        default = null;
        description = "Path to the user's password file.";
      };
    };
  };

  config = mkIf (cfg.enable && cfg.atuin.enable) {
    services.postgresql = {
      ensureDatabases = [cfg.atuin.database];
      ensureUsers = [
        {
          name = cfg.atuin.user;
          ensureDBOwnership = true;
          ensureClauses.login = true;
        }
      ];
    };

    services.clubcotton.postgresql.postStartCommands = let
      psql = "${lib.getExe' config.services.postgresql.package "psql"} -p ${toString cfg.port}";
      sqlFile = pkgs.writeText "atuin-setup.sql" ''
        ALTER SCHEMA public OWNER TO "${cfg.atuin.user}";
      '';
      passwordCmd = optionalString (cfg.atuin.passwordFile != null) ''
        ${psql} -tA <<'EOF'
          DO $$
          DECLARE password TEXT;
          BEGIN
            password := trim(both from replace(pg_read_file('${cfg.atuin.passwordFile}'), E'\n', '''));
            EXECUTE format('ALTER ROLE "${cfg.atuin.database}" WITH PASSWORD '''%s''';', password);
          END $$;
        EOF
      '';
    in [
      passwordCmd
      ''
        ${psql} -d "${cfg.atuin.database}" -f "${sqlFile}"
      ''
    ];
  };
}
