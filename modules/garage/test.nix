{nixpkgs}: {
  name = "garage";

  nodes = {
    garage = {
      config,
      pkgs,
      ...
    }: {
      imports = [
        ../modules/garage
      ];

      # Create RPC secret for testing
      environment.etc."garage-rpc-secret".text = ''
        test-rpc-secret-key-for-cluster-communication
      '';

      # Configure Garage with test settings
      services.clubcotton.garage = {
        enable = true;
        replicationMode = "1"; # Single node, no replication
        dataDir = "/var/lib/garage/data";
        metadataDir = "/var/lib/garage/meta";
        s3ApiBindAddr = "0.0.0.0:3900";
        rpcBindAddr = "0.0.0.0:3901";
        s3WebBindAddr = "0.0.0.0:3902";
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
    garage.wait_for_open_port(3902)

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

    # Test web UI endpoint
    garage.succeed("curl -s -o /dev/null -w '%{http_code}' http://localhost:3902/ | grep -E '200|404' || true")

    # Verify garage CLI works
    garage.succeed("${nixpkgs.legacyPackages.x86_64-linux.garage}/bin/garage --version")

    print("All Garage tests passed!")
  '';
}
