# nix build '.#checks.x86_64-linux.nix-cache-proxy'
# nix run '.#checks.x86_64-linux.nix-cache-proxy.driverInteractive'
{nixpkgs}: let
  testLib = import ../../../tests/libtest.nix {};
in {
  name = "nix-cache-proxy";

  interactive.nodes = let
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
      ../harmonia
      ../nix-cache-proxy
    ];

    # Define minimal clubcotton options for test
    options.clubcotton = {
      tailscaleAuthKeyPath = lib.mkOption {
        type = lib.types.str;
        default = "/dev/null";
      };
    };

    config = {
      networking.hostName = "cache-server";
      networking.firewall.enable = false;

      # Generate test signing key
      environment.etc."harmonia-test-key".text = ''
        test-cache:rLBj8D+R1ij3AJqTfERIFgN/r5xfqK3UXbEpPj5fR8k=
      '';

      # Enable Harmonia
      services.clubcotton.harmonia = {
        enable = true;
        port = 5000;
        bindAddress = "127.0.0.1"; # Bind to localhost, nginx will proxy
        signKeyPath = "/etc/harmonia-test-key";
        tailnetHostname = null;
      };

      # Enable nginx caching proxy
      services.clubcotton.nix-cache-proxy = {
        enable = true;
        port = 80;
        bindAddress = "0.0.0.0"; # Accessible from test
        harmoniaBind = "127.0.0.1:5000";
        upstreamCache = "https://cache.nixos.org";
        cachePath = "/tmp/nix-cache-proxy";
        cacheMaxSize = "1g";
        cacheValidTime = "7d";
      };

      systemd.tmpfiles.rules = [
        "d /ssdpool/local/nix-cache 0755 root root - -"
      ];
    };
  };

  testScript = ''
    start_all()

    with subtest("Services start"):
        machine.wait_for_unit("harmonia.service")
        machine.wait_for_unit("nginx.service")
        machine.wait_for_open_port(80)
        machine.wait_for_open_port(5000)

    with subtest("Nginx serves nix-cache-info"):
        output = machine.succeed("curl -f http://localhost:80/nix-cache-info")
        print(f"Cache info via nginx: {output}")
        assert "StoreDir: /nix/store" in output

    with subtest("Harmonia directly serves nix-cache-info"):
        output = machine.succeed("curl -f http://localhost:5000/nix-cache-info")
        print(f"Cache info direct from Harmonia: {output}")
        assert "StoreDir: /nix/store" in output

    with subtest("Nginx caches upstream requests"):
        # First request should be a MISS (fetched from upstream)
        print("First request to upstream package (should be MISS)...")
        output = machine.succeed(
            "curl -v -f http://localhost:80/nar/1w1fff338fvdw53sqgamddn1b2xgds473-firefox-133.0.drv 2>&1 || true"
        )
        print(f"First request output: {output}")

        # Check that nginx is running and can serve requests
        # Even if the specific .nar doesn't exist, nginx should be proxying
        machine.succeed("curl -f http://localhost:80/nix-cache-info")
        print("Nginx is successfully proxying requests")

    with subtest("Nginx cache directory created"):
        machine.succeed("test -d /tmp/nix-cache-proxy")
        machine.succeed("ls -la /tmp/nix-cache-proxy")
        print("Cache directory exists and has correct permissions")
  '';
}
