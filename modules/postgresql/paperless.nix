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
    paperless = {
      enable = mkEnableOption "paperless database support";

      database = mkOption {
        type = types.str;
        default = "paperless";
        description = "Name of the paperless database.";
      };

      user = mkOption {
        type = types.str;
        default = "paperless";
        description = "Name of the paperless database user.";
      };

      passwordFile = mkOption {
        type = types.nullOr types.path;
        default = null;
        description = "Path to the user's password file.";
      };
    };
  };

  config = mkIf (cfg.enable && cfg.paperless.enable) {
    services.postgresql = {
      ensureDatabases = [cfg.paperless.database];
      ensureUsers = [
        {
          name = cfg.paperless.user;
          ensureDBOwnership = true;
          ensureClauses.login = true;
        }
      ];
    };

    services.clubcotton.postgresql.postStartCommands = let
      psql = "${lib.getExe' config.services.postgresql.package "psql"} -p ${toString cfg.port}";
      sqlFile = pkgs.writeText "paperless-setup.sql" ''
        ALTER SCHEMA public OWNER TO "${cfg.paperless.user}";
      '';
      passwordCmd = optionalString (cfg.paperless.passwordFile != null) ''
        ${psql} -tA <<'EOF'
          DO $$
          DECLARE password TEXT;
          BEGIN
            password := trim(both from replace(pg_read_file('${cfg.paperless.passwordFile}'), E'\n', '''));
            EXECUTE format('ALTER ROLE "${cfg.paperless.database}" WITH PASSWORD '''%s''';', password);
          END $$;
        EOF
      '';
    in [
      passwordCmd
      ''
        ${psql} -d "${cfg.paperless.database}" -f "${sqlFile}"
      ''
    ];
  };
}
