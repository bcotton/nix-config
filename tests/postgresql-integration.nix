{nixpkgs}: {
  name = "postgresql-integration";

  interactive.nodes.immich = { ... }: {
  };
  nodes = {
    # PostgreSQL server node
    postgres = {
      config,
      pkgs,
      ...
    }: {
      imports = [
        ../modules/postgresql
      ];

      # Create secrets file
      environment.etc."immich-secrets".text = ''
        test-password
      '';

      # Configure PostgreSQL server
      services.clubcotton.postgresql = {
        enable = true;
        port = 5433;
        enableTCPIP = true;
        authentication = ''
          local all all trust
          host  all all 0.0.0.0/0 password
          host  all all ::0/0 password
        '';
        package = pkgs.postgresql_16;
        dataDir = "/var/lib/postgresql/16";

        # Enable Immich database support
        immich = {
          enable = true;
          database = "test-immich";
          user = "test-immich";
          passwordFile = "/etc/immich-secrets";
        };
      };

      # Open firewall for PostgreSQL
      networking.firewall.allowedTCPPorts = [5433];

      # SSH access configuration
      services.openssh = {
        enable = true;
        settings = {
          PermitRootLogin = "yes";
          PermitEmptyPasswords = "yes";
        };
      };
      security.pam.services.sshd.allowNullPassword = true;
      virtualisation.forwardPorts = [
        {
          from = "host";
          host.port = 2224;
          guest.port = 22;
        }
      ];
      
    };

    # Immich server node
    immich = {
      config,
      pkgs,
      ...
    }: {
      imports = [
        ../modules/immich
      ];

      # Create secrets file
      environment.etc."immich-secrets".text = ''
        DB_PASSWORD=test-password
      '';

      # Configure Immich service
      services.clubcotton.immich = {
        enable = true;
        secretsFile = "/etc/immich-secrets";
        database = {
          enable = false; # Don't enable local PostgreSQL
          name = "test-immich";
          user = "test-immich";
          host = "postgres"; # Reference PostgreSQL server node
          port = 5433;
        };
        serverConfig = {
          port = 2283;
          host = "0.0.0.0";
          mediaLocation = "/var/lib/immich";
        };
        redis.enable = true;
        machineLearning.enable = false; # Disable for testing
      };

      # Open firewall for Immich
      networking.firewall.allowedTCPPorts = [2283];

      # SSH access configuration
      services.openssh = {
        enable = true;
        settings = {
          PermitRootLogin = "yes";
          PermitEmptyPasswords = "yes";
        };
      };
      security.pam.services.sshd.allowNullPassword = true;
      virtualisation.forwardPorts = [
        {
          from = "host";
          host.port = 2223;
          guest.port = 22;
        }
      ];
    };
  };

  testScript = ''
    start_all()

    with subtest("PostgreSQL service starts"):
        postgres.wait_for_unit("postgresql.service")
        postgres.succeed("systemctl is-active postgresql.service")

    with subtest("PostgreSQL is listening on custom port"):
        postgres.wait_until_succeeds("nc -z localhost 5433")

    with subtest("Data directory is created"):
        postgres.succeed("test -d /var/lib/postgresql/16")

    with subtest("PostgreSQL accepts connections"):
        postgres.succeed(
            "sudo -u postgres psql -p 5433 -c '\\l' | grep template1"
        )

    with subtest("Immich database and user are created"):
        postgres.succeed(
            "sudo -u postgres psql -p 5433 -c '\\l' | grep test-immich"
        )
        postgres.succeed(
            "sudo -u postgres psql -p 5433 -c '\\du' | grep test-immich"
        )

    with subtest("Required extensions are installed"):
        postgres.succeed(
            "sudo -u postgres psql -p 5433 -d test-immich -c '\\dx' | grep vectors"
        )
        postgres.succeed(
            "sudo -u postgres psql -p 5433 -d test-immich -c '\\dx' | grep unaccent"
        )
        postgres.succeed(
            "sudo -u postgres psql -p 5433 -d test-immich -c '\\dx' | grep uuid-ossp"
        )
        postgres.succeed(
            "sudo -u postgres psql -p 5433 -d test-immich -c '\\dx' | grep cube"
        )
        postgres.succeed(
            "sudo -u postgres psql -p 5433 -d test-immich -c '\\dx' | grep earthdistance"
        )
        postgres.succeed(
            "sudo -u postgres psql -p 5433 -d test-immich -c '\\dx' | grep pg_trgm"
        )

    with subtest("Schema ownership is correct"):
        postgres.succeed(
            "sudo -u postgres psql -p 5433 -d test-immich -c \"SELECT schema_owner FROM information_schema.schemata WHERE schema_name = 'public';\" | grep test-immich"
        )
        postgres.succeed(
            "sudo -u postgres psql -p 5433 -d test-immich -c \"SELECT schema_owner FROM information_schema.schemata WHERE schema_name = 'vectors';\" | grep test-immich"
        )

    with subtest("Secrets file exists"):
        immich.succeed("test -f /etc/immich-secrets")


    with subtest("Immich service starts"):
        immich.shell_interact()
        immich.wait_for_unit("immich-server.service")
        immich.succeed("systemctl is-active immich-server.service")

    with subtest("Immich service is listening"):
        immich.wait_until_succeeds("nc -z localhost 2283")

    with subtest("Redis service is running"):
        immich.wait_for_unit("redis-immich.service")
        immich.succeed("systemctl is-active redis-immich.service")

    with subtest("Immich can connect to PostgreSQL"):
        immich.succeed("nc -z postgres 5433")
  '';
}
