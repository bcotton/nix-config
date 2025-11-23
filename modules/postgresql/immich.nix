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
    immich = {
      enable = mkEnableOption "Immich database support";

      database = mkOption {
        type = types.str;
        default = "immich";
        description = "Name of the Immich database.";
      };

      user = mkOption {
        type = types.str;
        default = "immich";
        description = "Name of the Immich database user.";
      };

      passwordFile = mkOption {
        type = types.nullOr types.path;
        default = null;
        description = "Path to the user's password.";
      };
    };
  };

  config = mkIf (cfg.enable && cfg.immich.enable) {
    services.postgresql = {
      ensureDatabases = [cfg.immich.database];
      ensureUsers = [
        {
          name = cfg.immich.user;
          ensureDBOwnership = true;
          ensureClauses.login = true;
        }
      ];
      settings = {
        shared_preload_libraries = ["vchord.so" "vector.so"];
        search_path = "\"$user\", public, vector, vchor";
      };
      extensions = ps: with ps; [vectorchord pgvector];
    };

    # https://discourse.nixos.org/t/set-password-for-a-postgresql-user-from-a-file-agenix/41377/13
    # TODO: use agenix for the password
    # password_file_path = config.environment.etc."immich-secrets".path;
    systemd.services.postgresql.postStart = mkIf (cfg.immich.passwordFile != null) (let
      password_file_path = cfg.immich.passwordFile;
    in ''
      $PSQL -tA <<'EOF'
        DO $$
        DECLARE password TEXT;
        BEGIN
          password := trim(both from replace(pg_read_file('${password_file_path}'), E'\n', '''));
          EXECUTE format('ALTER ROLE "${cfg.immich.database}" WITH PASSWORD '''%s''';', password);
        END $$;
      EOF
    '');

    services.clubcotton.postgresql.postStartCommands = let
      sqlFile = pkgs.writeText "immich-pgvectors-setup.sql" ''
        CREATE EXTENSION IF NOT EXISTS unaccent;
        CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
        CREATE EXTENSION IF NOT EXISTS vchord;
        CREATE EXTENSION IF NOT EXISTS vector;
        CREATE EXTENSION IF NOT EXISTS cube;
        CREATE EXTENSION IF NOT EXISTS earthdistance;
        CREATE EXTENSION IF NOT EXISTS pg_trgm;

        ALTER SCHEMA public OWNER TO "${cfg.immich.user}";
        GRANT SELECT ON TABLE pg_vector_index_stat TO "${cfg.immich.user}";

        ALTER USER immich WITH CREATEDB;
        GRANT pg_read_all_data TO "${cfg.immich.user}";

        ALTER EXTENSION vchord UPDATE;
        ALTER EXTENSION vector UPDATE;
      '';
    in [
      ''
        ${lib.getExe' config.services.postgresql.package "psql"} -p ${toString cfg.port} -d "${cfg.immich.database}" -f "${sqlFile}"
      ''
    ];
  };
}
