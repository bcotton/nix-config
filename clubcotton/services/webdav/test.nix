# nix build '.#checks.x86_64-linux.webdav'
# nix run '.#checks.x86_64-linux.webdav.driverInteractive'
{nixpkgs}: {
  name = "webdav";
  interactive.nodes = let
    testLib = import ../../../tests/libtest.nix {};
    lib = nixpkgs.lib;
  in {
    machine = {...}:
      lib.recursiveUpdate
      (testLib.mkSshConfig 2223)
      (testLib.portForward 6065 6065);
  };

  nodes.machine = {
    config,
    pkgs,
    ...
  }: {
    imports = [
      ./default.nix
    ];

    services.clubcotton.webdav = {
      enable = true;
      users = {
        # Full access user
        admin-0 = {
          password = "adminpass0";
          directory = "/var/lib/webdav/admin-0";
          permissions = "CRUD";
        };
        # Other full access user
        admin-1 = {
          password = "adminpass1";
          directory = "/var/lib/webdav/admin-1";
          permissions = "CRUD";
        };
        # Read-only user
        reader = {
          password = "readerpass";
          directory = "/var/lib/webdav/reader";
          permissions = "R";
        };
        # Test user with environment variable password
        env-user = {
          password = "{env}WEBDAV_TEST_PASSWORD";
          directory = "/var/lib/webdav/env-user";
          permissions = "CRUD";
        };
      };
    };

    # Configure webdav service to use environment file
    systemd.services.webdav.serviceConfig = {
      StateDirectory = "webdav";
      EnvironmentFile = "/var/lib/webdav/test-env";
    };

    # Create test directories and files
    systemd.tmpfiles.rules = [
      "d /var/lib/webdav 0755 webdav webdav"
      "d /var/lib/webdav/admin-0 0755 webdav webdav"
      "d /var/lib/webdav/admin-1 0755 webdav webdav"
      "d /var/lib/webdav/reader 0755 webdav webdav"
      "d /var/lib/webdav/env-user 0755 webdav webdav"
      "f /var/lib/webdav/admin-0/test.txt 0644 webdav webdav - hello-admin-0"
      "f /var/lib/webdav/admin-1/test.txt 0644 webdav webdav - hello-admin-1"
      "f /var/lib/webdav/reader/test.txt 0644 webdav webdav - hello-reader"
      "f /var/lib/webdav/env-user/test.txt 0644 webdav webdav - hello-env-user"
      "f /var/lib/webdav/test-env 0600 webdav webdav - WEBDAV_TEST_PASSWORD=testpass123"
    ];
  };

  testScript = ''
    start_all()

    # Wait for webdav service to start
    machine.wait_for_unit("webdav.service")
    machine.wait_for_open_port(6065)

    machine.shell_interact()

    # Test authentication failures
    machine.fail(
      "curl -f -u wronguser:wrongpass http://localhost:6065/test.txt"
    )

    # Test admin-0 user (CRUD permissions)
    machine.succeed(
      # Read own file
      "curl -f -u admin-0:adminpass0 http://localhost:6065/test.txt | grep hello-admin-0",
      # Create/Update in own directory
      "echo 'new content' > upload.txt",
      "curl -f -u admin-0:adminpass0 -T upload.txt http://localhost:6065/upload.txt",
      "curl -f -u admin-0:adminpass0 http://localhost:6065/upload.txt | grep 'new content'",
      # Delete from own directory
      "curl -f -u admin-0:adminpass0 -X DELETE http://localhost:6065/upload.txt"
    )

    # Test admin-1 user (CRUD permissions)
    machine.succeed(
      # Read own file
      "curl -f -u admin-1:adminpass1 http://localhost:6065/test.txt | grep hello-admin-1",
      # Create/Update in own directory
      "echo 'admin-1 content' > upload.txt",
      "curl -f -u admin-1:adminpass1 -T upload.txt http://localhost:6065/upload.txt",
      "curl -f -u admin-1:adminpass1 http://localhost:6065/upload.txt | grep 'admin-1 content'",
      # Delete from own directory
      "curl -f -u admin-1:adminpass1 -X DELETE http://localhost:6065/upload.txt"
    )

    # Test read-only user
    machine.succeed(
      # Read should work
      "curl -f -u reader:readerpass http://localhost:6065/test.txt | grep hello-reader"
    )
    machine.fail(
      # Write should fail
      "echo 'new content' > upload.txt && curl -f -u reader:readerpass -T upload.txt http://localhost:6065/upload.txt",
    );

    # Test environment variable password user
    machine.succeed(
      # Read own file
      "curl -f -u env-user:testpass123 http://localhost:6065/test.txt | grep hello-env-user",
      # Create/Update in own directory
      "echo 'env-user content' > upload.txt",
      "curl -f -u env-user:testpass123 -T upload.txt http://localhost:6065/upload.txt",
      "curl -f -u env-user:testpass123 http://localhost:6065/upload.txt | grep 'env-user content'",
      # Delete from own directory
      "curl -f -u env-user:testpass123 -X DELETE http://localhost:6065/upload.txt"
    )

    # Test that wrong password fails for env user
    machine.fail(
      "curl -f -u env-user:wrongpass http://localhost:6065/test.txt"
    )

    # Test directory isolation and path traversal prevention
    machine.fail(
      # admin-0 should not be able to access admin-1's directory
      "curl -f -u admin-0:adminpass0 http://localhost:6065/admin-1/test.txt",
      # admin-0 should not be able to access reader's directory
      "curl -f -u admin-0:adminpass0 http://localhost:6065/reader/test.txt",
      # admin-1 should not be able to access admin-0's directory
      "curl -f -u admin-1:adminpass1 http://localhost:6065/admin-0/test.txt",
      # reader should not be able to access admin-0's directory
      "curl -f -u reader:readerpass http://localhost:6065/admin-0/test.txt",
      # Prevent absolute path access attempts
      "curl -f -u admin-0:adminpass0 'http://localhost:6065//etc/passwd'",
      "curl -f -u admin-0:adminpass0 'http://localhost:6065//var/lib/webdav/admin-1/test.txt'",
      # Prevent path traversal attempts
      "curl -f -u admin-0:adminpass0 'http://localhost:6065/../etc/passwd'",
      "curl -f -u admin-0:adminpass0 'http://localhost:6065/..%2F..%2Fetc%2Fpasswd'",
      "curl -f -u admin-0:adminpass0 'http://localhost:6065/%2E%2E%2F%2E%2E%2Fetc%2Fpasswd'",
      # Prevent encoded traversal attempts
      "curl -f -u admin-0:adminpass0 'http://localhost:6065/%2e%2e/%2e%2e/etc/passwd'",
      # Prevent double slash directory confusion
      "curl -f -u admin-0:adminpass0 'http://localhost:6065//admin-1/test.txt'",
      # Prevent access via alternate path representations
      "curl -f -u admin-0:adminpass0 'http://localhost:6065/./admin-1/test.txt'",
      "curl -f -u admin-0:adminpass0 'http://localhost:6065/admin-0/../admin-1/test.txt'"
    );
  '';
}
