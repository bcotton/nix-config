# Run interactively:  nix run '.#checks.x86_64-linux.postgresql.driverInteractive'
# Run:  nix run '.#checks.x86_64-linux.postgresql'
# SSH into test VM:  ssh -p 2223 root@localhost
{nixpkgs}: {
  name = "postgresql";

  interactive.nodes = let
    testLib = import ../../tests/libtest.nix {};
  in {
    machine = {...}: testLib.mkSshConfig 2223;
  };

  nodes = {
    machine = {
      config,
      pkgs,
      ...
    }: {
      imports = [
        ./default.nix
      ];

      # Basic PostgreSQL configuration
      services.clubcotton.postgresql = {
        enable = true;
        port = 5433; # Use non-default port to test port configuration
        enableTCPIP = true;
        authentication = ''
          local all all trust
          host  all all 127.0.0.1/32 trust
        '';
        package = pkgs.postgresql_16;
        dataDir = "/var/lib/postgresql/16";
      };

      # Test Immich configuration
      services.clubcotton.postgresql.immich = {
        enable = true;
        database = "test-immich"; # Match the database name with the user for ensureDBOwnership
        user = "test-immich";
      };

      # Test Open WebUI configuration
      services.clubcotton.postgresql.open-webui = {
        enable = true;
        database = "test-open-webui";
        user = "test-open-webui";
      };
    };
  };

  testScript = ''
    start_all()
    with subtest("PostgreSQL service starts"):
        machine.wait_for_unit("postgresql.service")
        machine.succeed("systemctl is-active postgresql.service")
    with subtest("PostgreSQL is listening on custom port"):
        machine.wait_until_succeeds("nc -z localhost 5433")
    with subtest("Data directory is created"):
        machine.succeed("test -d /var/lib/postgresql")
    with subtest("Immich database and user are created"):
        machine.succeed(
            "sudo -u postgres psql -p 5433 -c '\\l' | grep test-immich"
        )
        machine.succeed(
            "sudo -u postgres psql -p 5433 -c '\\du' | grep test-immich"
        )
    with subtest("Required extensions are installed"):
        machine.succeed(
            "sudo -u postgres psql -p 5433 -d test-immich -c '\\dx'"
        )
        machine.succeed(
            "sudo -u postgres psql -p 5433 -d test-immich -c '\\dx' | grep vector"
        )
        machine.succeed(
            "sudo -u postgres psql -p 5433 -d test-immich -c '\\dx' | grep unaccent"
        )
        machine.succeed(
            "sudo -u postgres psql -p 5433 -d test-immich -c '\\dx' | grep uuid-ossp"
        )
        machine.succeed(
            "sudo -u postgres psql -p 5433 -d test-immich -c '\\dx' | grep cube"
        )
        machine.succeed(
            "sudo -u postgres psql -p 5433 -d test-immich -c '\\dx' | grep earthdistance"
        )
        machine.succeed(
            "sudo -u postgres psql -p 5433 -d test-immich -c '\\dx' | grep pg_trgm"
        )
    with subtest("Schema ownership is correct"):
        machine.succeed(
            "sudo -u postgres psql -p 5433 -d test-immich -c \"SELECT schema_owner FROM information_schema.schemata WHERE schema_name = 'public';\" | grep test-immich"
        )
        machine.shell_interact()

        machine.succeed(
            "sudo -u postgres psql -p 5433 -d test-immich -c \"SELECT schema_owner FROM information_schema.schemata WHERE schema_name = 'vectors';\" | grep test-immich"
        )
    with subtest("Open WebUI database and user are created"):
        machine.succeed(
            "sudo -u postgres psql -p 5433 -c '\\l' | grep test-open-webui"
        )
        machine.succeed(
            "sudo -u postgres psql -p 5433 -c '\\du' | grep test-open-webui"
        )
    with subtest("Open WebUI schema ownership is correct"):
        machine.succeed(
            "sudo -u postgres psql -p 5433 -d test-open-webui -c \"SELECT schema_owner FROM information_schema.schemata WHERE schema_name = 'public';\" | grep test-open-webui"
        )
  '';
}
