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

    # Set password from file if passwordFile is provided
    systemd.services.postgresql.postStart = mkIf (cfg.atuin.passwordFile != null) (let
      password_file_path = cfg.atuin.passwordFile;
    in ''
      $PSQL -tA <<'EOF'
        DO $$
        DECLARE password TEXT;
        BEGIN
          password := trim(both from replace(pg_read_file('${password_file_path}'), E'\n', '''));
          EXECUTE format('ALTER ROLE "${cfg.atuin.database}" WITH PASSWORD '''%s''';', password);
        END $$;
      EOF
    '');

    services.clubcotton.postgresql.postStartCommands = let
      sqlFile = pkgs.writeText "atuin-setup.sql" ''
        ALTER SCHEMA public OWNER TO "${cfg.atuin.user}";
      '';
    in [
      ''
        ${lib.getExe' config.services.postgresql.package "psql"} -p ${toString cfg.port} -d "${cfg.atuin.database}" -f "${sqlFile}"
      ''
    ];
  };
}
