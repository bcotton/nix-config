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

    services.clubcotton.postgresql.postStartCommands = let
      psql = "${lib.getExe' config.services.postgresql.package "psql"} -p ${toString cfg.port}";
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
      passwordCmd = optionalString (cfg.immich.passwordFile != null) ''
        ${psql} -tA <<'EOF'
          DO $$
          DECLARE password TEXT;
          BEGIN
            password := trim(both from replace(pg_read_file('${cfg.immich.passwordFile}'), E'\n', '''));
            EXECUTE format('ALTER ROLE "${cfg.immich.database}" WITH PASSWORD '''%s''';', password);
          END $$;
        EOF
      '';
    in [
      passwordCmd
      ''
        ${psql} -d "${cfg.immich.database}" -f "${sqlFile}"
      ''
    ];
  };
}
