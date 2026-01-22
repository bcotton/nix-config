# nix build '.#checks.x86_64-linux.harmonia'
# nix run '.#checks.x86_64-linux.harmonia.driverInteractive'
{nixpkgs}: {
  name = "harmonia";

  interactive.nodes = let
    testLib = import ../../../tests/libtest.nix {};
    lib = nixpkgs.lib;
  in {
    machine = {...}:
      lib.recursiveUpdate
      (testLib.mkSshConfig 2223)
      (testLib.portForward 5000 5000);
  };

  nodes.machine = {
    config,
    pkgs,
    lib,
    ...
  }: {
    imports = [
      ./default.nix
    ];

    # Define minimal clubcotton options for test
    options.clubcotton = {
      tailscaleAuthKeyPath = lib.mkOption {
        type = lib.types.str;
        default = "/dev/null";
      };
      user = lib.mkOption {
        type = lib.types.str;
        default = "root";
      };
      group = lib.mkOption {
        type = lib.types.str;
        default = "root";
      };
    };

    config = {
      # Generate test signing key
      environment.etc."harmonia-test-key".text = ''
        test-cache:rLBj8D+R1ij3AJqTfERIFgN/r5xfqK3UXbEpPj5fR8k=
      '';

      services.clubcotton.harmonia = {
        enable = true;
        port = 5000;
        bindAddress = "0.0.0.0"; # Bind to all interfaces for test access
        signKeyPath = "/etc/harmonia-test-key"; # Test uses explicit path
        tailnetHostname = null; # Disable Tailscale in test (mkIf handles this)
      };

      # Create test dataset
      systemd.tmpfiles.rules = [
        "d /ssdpool/local/nix-cache 0755 root root - -"
      ];
    };
  };

  testScript = ''
    start_all()

    with subtest("Service starts and listens"):
        # Wait for Harmonia service
        machine.wait_for_unit("harmonia.service")
        machine.wait_for_open_port(5000)

    with subtest("Basic HTTP connectivity"):
        # Test basic HTTP connectivity
        machine.succeed("curl -f http://localhost:5000/")

    with subtest("nix-cache-info endpoint"):
        # Verify nix-cache-info endpoint
        machine.succeed(
          "curl -f http://localhost:5000/nix-cache-info | grep -q 'StoreDir: /nix/store'"
        )
        # Check that WantMassQuery is present
        machine.succeed(
          "curl -f http://localhost:5000/nix-cache-info | grep -q 'WantMassQuery:'"
        )

    with subtest("Harmonia process running"):
        # Verify Harmonia process is running
        machine.succeed("pgrep -f harmonia")

        # Verify the service is active
        machine.succeed("systemctl is-active harmonia.service")

    with subtest("Service logs"):
        # Check logs for startup messages
        machine.succeed("journalctl -u harmonia.service --no-pager | grep -qi 'harmonia\\|started\\|listening'")

    with subtest("Permissions"):
        # Verify cache directory permissions
        machine.succeed(
          "stat -c '%a' /ssdpool/local/nix-cache | grep -q '^755$'"
        )
  '';
}
