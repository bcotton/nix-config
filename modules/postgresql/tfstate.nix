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
    tfstate = {
      enable = mkEnableOption "TF State store";

      database = mkOption {
        type = types.str;
        default = "tfstate";
        description = "Name of the TF state database.";
      };

      user = mkOption {
        type = types.str;
        default = "tfstate";
        description = "Name of the TF state database user.";
      };

      passwordFile = mkOption {
        type = types.nullOr types.path;
        default = null;
        description = "Path to the user's password file.";
      };
    };
  };

  config = mkIf (cfg.enable && cfg.tfstate.enable) {
    services.postgresql = {
      ensureDatabases = [cfg.tfstate.database];
      ensureUsers = [
        {
          name = cfg.tfstate.user;
          ensureDBOwnership = true;
          ensureClauses.login = true;
        }
      ];
    };

    services.clubcotton.postgresql.postStartCommands = let
      psql = "${lib.getExe' config.services.postgresql.package "psql"} -p ${toString cfg.port}";
      sqlFile = pkgs.writeText "tfstate-setup.sql" ''
        ALTER SCHEMA public OWNER TO "${cfg.tfstate.user}";
      '';
      passwordCmd = optionalString (cfg.tfstate.passwordFile != null) ''
        ${psql} -tA <<'EOF'
          DO $$
          DECLARE password TEXT;
          BEGIN
            password := trim(both from replace(pg_read_file('${cfg.tfstate.passwordFile}'), E'\n', '''));
            EXECUTE format('ALTER ROLE "${cfg.tfstate.database}" WITH PASSWORD '''%s''';', password);
          END $$;
        EOF
      '';
    in [
      passwordCmd
      ''
        ${psql} -d "${cfg.tfstate.database}" -f "${sqlFile}"
      ''
    ];
  };
}
