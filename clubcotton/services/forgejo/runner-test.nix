# NixOS test for Forgejo Actions runners
# Run: nix build '.#checks.x86_64-linux.forgejo-runner'
# Run interactive: nix run '.#checks.x86_64-linux.forgejo-runner.driverInteractive'
{
  pkgs,
  lib,
  ...
}: let
  # Test database and runner token
  testDbPassword = "test-forgejo-password-12345";
  # This is a dummy token for testing - in real deployment this comes from Forgejo admin panel
  testRunnerToken = "test-runner-token-dummy-for-testing";
in
  pkgs.testers.runNixOSTest {
    name = "forgejo-runner";

    nodes = {
      # Forgejo server node
      server = {
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
              packages = false;
              lfs = false;
              federation = false;
            };
          };

          # Ensure PostgreSQL is fully started before Forgejo
          systemd.services.forgejo = {
            after = ["postgresql.service"];
            requires = ["postgresql.service"];
          };

          networking.firewall.allowedTCPPorts = [3000];
        };
      };

      # Runner node
      runner = {
        config,
        pkgs,
        ...
      }: {
        imports = [./runner.nix];

        # Create test token file (will be chowned after gitea-runner user is created)
        systemd.tmpfiles.rules = [
          "f /run/secrets/forgejo-runner-token 0444 root root - ${testRunnerToken}"
        ];

        services.clubcotton.forgejo-runner = {
          enable = true;
          instances = {
            test-runner = {
              enable = true;
              name = "test-runner-1";
              url = "http://server:3000";
              tokenFile = "/run/secrets/forgejo-runner-token";
              labels = [
                "nixos:docker://nixos/nix:latest"
                "ubuntu-latest:docker://node:20-bookworm"
              ];
              capacity = 1;
            };
          };
        };
      };
    };

    testScript = ''
      start_all()

      # Wait for server PostgreSQL and Forgejo
      print("Starting Forgejo server...")
      server.wait_for_unit("postgresql.service")
      server.wait_for_unit("forgejo.service")
      server.wait_for_open_port(3000)
      server.sleep(5)

      # Verify Forgejo is accessible from runner node
      print("Testing network connectivity from runner to server...")
      runner.wait_until_succeeds("curl -f -s http://server:3000/ | grep -i forgejo")

      # Wait for Docker on runner
      print("Starting Docker on runner node...")
      runner.wait_for_unit("docker.service")
      runner.succeed("docker info")

      # Note: gitea-actions-runner uses DynamicUser, so gitea-runner user only exists at runtime

      # Verify the gitea-runner service unit was created
      print("Verifying runner service unit was created...")
      runner.succeed("systemctl cat gitea-runner-test\\\\x2drunner.service")

      # Verify runner service has the correct configuration
      print("Verifying runner service configuration...")
      # Check that DynamicUser is set
      runner.succeed("systemctl show gitea-runner-test\\\\x2drunner.service -p DynamicUser | grep -q 'DynamicUser=yes'")
      # Check that it depends on docker
      runner.succeed("systemctl show gitea-runner-test\\\\x2drunner.service -p After | grep -q docker")

      # Verify runner's working directory will be created at runtime
      print("Verifying runner state directory configuration...")
      runner.succeed("systemctl show gitea-runner-test\\\\x2drunner.service -p StateDirectory | grep -q gitea-runner")

      # Verify runner can reach Forgejo
      print("Verifying runner can reach Forgejo server...")
      runner.succeed("curl -f -s http://server:3000/api/v1/version")

      # Check that Docker is properly configured
      print("Verifying Docker integration...")
      runner.succeed("docker ps")
      runner.succeed("docker info")

      # Note: Skipping Docker image pull test as VM doesn't have external network access

      # Verify tokenFile exists and is world-readable (DynamicUser will read it at runtime)
      print("Verifying runner token file...")
      runner.succeed("test -f /run/secrets/forgejo-runner-token")
      runner.succeed("test -r /run/secrets/forgejo-runner-token")

      # Give runner service time to attempt registration (will fail with dummy token)
      runner.sleep(3)

      # Verify the service attempted to start (it will be failed due to dummy token)
      print("Verifying runner service attempted registration...")
      result = runner.succeed("systemctl status gitea-runner-test\\\\x2drunner.service || true")
      # Service should show that it attempted to register
      assert "act_runner" in result or "gitea-register-runner" in result, "Runner service didn't attempt to start"

      # Verify registration attempted to create runtime directory
      print("Verifying runtime directory was created...")
      runner.succeed("test -d /var/lib/gitea-runner/test-runner")

      print("All Forgejo runner tests passed!")
      print("Note: Runner service is expected to fail registration with dummy token - this is normal")
      print("The gitea-actions-runner module uses DynamicUser, so the user only exists when service runs")
      print("In production, use a valid registration token from Forgejo admin panel")
    '';
  }
