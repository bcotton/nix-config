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
    forgejo = {
      enable = mkEnableOption "Forgejo database support";

      database = mkOption {
        type = types.str;
        default = "forgejo";
        description = "Name of the Forgejo database.";
      };

      user = mkOption {
        type = types.str;
        default = "forgejo";
        description = "Name of the Forgejo database user.";
      };

      passwordFile = mkOption {
        type = types.nullOr types.path;
        default = null;
        description = "Path to the user's password file.";
      };
    };
  };

  config = mkIf (cfg.enable && cfg.forgejo.enable) {
    services.postgresql = {
      ensureDatabases = [cfg.forgejo.database];
      ensureUsers = [
        {
          name = cfg.forgejo.user;
          ensureDBOwnership = true;
          ensureClauses.login = true;
        }
      ];
    };

    # Set password from file if passwordFile is provided
    systemd.services.postgresql.postStart = mkIf (cfg.forgejo.passwordFile != null) (let
      password_file_path = cfg.forgejo.passwordFile;
    in ''
      $PSQL -tA <<'EOF'
        DO $$
        DECLARE password TEXT;
        BEGIN
          password := trim(both from replace(pg_read_file('${password_file_path}'), E'\n', '''));
          EXECUTE format('ALTER ROLE "${cfg.forgejo.user}" WITH PASSWORD '''%s''';', password);
        END $$;
      EOF
    '');

    services.clubcotton.postgresql.postStartCommands = let
      sqlFile = pkgs.writeText "forgejo-setup.sql" ''
        ALTER SCHEMA public OWNER TO "${cfg.forgejo.user}";
      '';
    in [
      ''
        ${lib.getExe' config.services.postgresql.package "psql"} -p ${toString cfg.port} -d "${cfg.forgejo.database}" -f "${sqlFile}"
      ''
    ];
  };
}
