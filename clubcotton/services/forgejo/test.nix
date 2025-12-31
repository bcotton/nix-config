# NixOS test for Forgejo service
# Run: nix build '.#checks.x86_64-linux.forgejo'
# Run interactive: nix run '.#checks.x86_64-linux.forgejo.driverInteractive'
{
  pkgs,
  lib,
  ...
}: let
  # Test database password
  testDbPassword = "test-forgejo-password-12345";
in
  pkgs.testers.runNixOSTest {
    name = "forgejo";

    nodes.machine = {
      config,
      pkgs,
      ...
    }: {
      imports = [
        ./service.nix
      ];

      # Define minimal clubcotton options needed for testing
      options.clubcotton = {
        user = lib.mkOption {
          default = "share";
          type = lib.types.str;
        };
        group = lib.mkOption {
          default = "share";
          type = lib.types.str;
        };
        tailscaleAuthKeyPath = lib.mkOption {
          default = "";
          type = lib.types.str;
        };
      };

      # Mock tsnsrv service options to avoid Tailscale
      options.services.tsnsrv = lib.mkOption {
        default = {};
        type = lib.types.attrs;
      };

      config = {
        # Required for clubcotton services
        users.groups.share = {};

        # Mock tsnsrv service to avoid Tailscale dependencies in tests
        services.tsnsrv.enable = lib.mkForce false;

        # Create test password file
        systemd.tmpfiles.rules = [
          "f /run/secrets/forgejo-db-password 0440 forgejo postgres - ${testDbPassword}"
        ];

        services.clubcotton.forgejo = {
          enable = true;
          port = 3000;
          sshPort = 2222;
          domain = "forgejo.test";
          customPath = "/var/lib/forgejo-data";
          # Disable Tailscale for testing
          tailnetHostname = null;
          database = {
            enable = true;
            createDB = true;
            passwordFile = "/run/secrets/forgejo-db-password";
          };
          features = {
            actions = true;
            packages = true;
            lfs = true;
            federation = false;
          };
        };

        # Ensure PostgreSQL is fully started before Forgejo
        systemd.services.forgejo = {
          after = ["postgresql.service"];
          requires = ["postgresql.service"];
        };
      };
    };

    testScript = ''
      start_all()

      # Wait for PostgreSQL to be ready
      machine.wait_for_unit("postgresql.service")
      machine.wait_for_open_port(5432)

      # Wait for Forgejo to start
      machine.wait_for_unit("forgejo.service")
      machine.wait_for_open_port(3000)
      machine.wait_for_open_port(2222)

      # Give Forgejo a moment to fully initialize
      machine.sleep(5)

      # Test HTTP endpoint is accessible
      print("Testing HTTP endpoint...")
      machine.succeed("curl -f -s http://localhost:3000/ | grep -i 'forgejo'")

      # Test that we can reach the installation page or login page
      print("Testing web interface accessibility...")
      response = machine.succeed("curl -f -s http://localhost:3000/")
      assert "forgejo" in response.lower() or "gitea" in response.lower(), "Forgejo web interface not accessible"

      # Test SSH server is listening
      print("Testing SSH server...")
      machine.succeed("nc -z localhost 2222")

      # Verify database was created
      print("Verifying PostgreSQL database...")
      machine.succeed(
          "sudo -u postgres psql -lqt | cut -d \\| -f 1 | grep -qw forgejo"
      )

      # Verify forgejo user exists in database
      machine.succeed(
          "sudo -u postgres psql -c '\\du' | grep -q forgejo"
      )

      # Verify storage directories were created
      print("Verifying storage directories...")
      machine.succeed("test -d /var/lib/forgejo-data/repositories")
      machine.succeed("test -d /var/lib/forgejo-data/lfs")
      machine.succeed("test -d /var/lib/forgejo-data/data")
      machine.succeed("test -d /var/lib/forgejo-data/packages")

      # Verify ownership
      machine.succeed("stat -c '%U:%G' /var/lib/forgejo-data | grep -q 'forgejo:forgejo'")

      # Test API endpoint (should return 404 or valid JSON, not 500)
      print("Testing API endpoint...")
      machine.succeed("curl -f -s http://localhost:3000/api/v1/version")

      # Verify forgejo service is stable (check it hasn't restarted)
      print("Verifying service stability...")
      restart_count = machine.succeed(
          "systemctl show forgejo.service -p NRestarts --value"
      ).strip()
      assert restart_count == "0", f"Forgejo service restarted {restart_count} times"

      print("All Forgejo service tests passed!")
    '';
  }
