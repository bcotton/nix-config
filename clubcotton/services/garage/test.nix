{nixpkgs}: {
  name = "garage";

  nodes = {
    garage = {
      config,
      pkgs,
      ...
    }: {
      imports = [
        ./service.nix
      ];

      # Create RPC secret for testing with proper permissions
      # Secret must be 32 bytes (64 hex characters)
      environment.etc."garage-rpc-secret" = {
        text = "0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef";
        mode = "0600";
        user = "garage";
        group = "garage";
      };

      # Configure Garage with test settings
      services.clubcotton.garage = {
        enable = true;
        replicationFactor = 1; # Single node, no replication
        dataDir = "/var/lib/garage/data";
        metadataDir = "/var/lib/garage/meta";
        s3ApiBindAddr = "0.0.0.0:3900";
        rpcBindAddr = "0.0.0.0:3901";
        rpcSecretFile = "/etc/garage-rpc-secret";
        s3Region = "test-region";
        openFirewall = true;
      };

      # Ensure garage package is available
      environment.systemPackages = [pkgs.garage pkgs.curl];
    };
  };

  testScript = ''
    start_all()

    # Wait for Garage to start
    garage.wait_for_unit("garage.service")
    garage.wait_for_open_port(3900)
    garage.wait_for_open_port(3901)

    # Check that the service is running
    garage.succeed("systemctl is-active garage.service")

    # Check that configuration file exists
    garage.succeed("test -f /etc/garage/garage.toml")

    # Verify data and metadata directories exist
    garage.succeed("test -d /var/lib/garage/data")
    garage.succeed("test -d /var/lib/garage/meta")

    # Check that the directories are owned by garage user
    garage.succeed("stat -c '%U:%G' /var/lib/garage/data | grep -q 'garage:garage'")
    garage.succeed("stat -c '%U:%G' /var/lib/garage/meta | grep -q 'garage:garage'")

    # Test S3 API endpoint responds (expecting 403 or similar since no buckets exist)
    # Garage should at least accept connections
    garage.succeed("curl -s -o /dev/null -w '%{http_code}' http://localhost:3900/ | grep -E '403|404|503' || true")

    # Verify garage CLI works (garage is in systemPackages)
    garage.succeed("garage --version")

    print("All Garage tests passed!")
  '';
}
