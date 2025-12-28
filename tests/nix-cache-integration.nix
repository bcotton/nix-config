# nix build '.#checks.x86_64-linux.nix-cache-integration'
# nix run '.#checks.x86_64-linux.nix-cache-integration.driverInteractive'
{
  nixpkgs,
  unstablePkgs,
  inputs,
}: {
  name = "nix-cache-integration";

  interactive.nodes = let
    testLib = import ./libtest.nix {};
  in {
    cache-server = {...}: testLib.mkSshConfig 2223;
    builder = {...}: testLib.mkSshConfig 2224;
    client = {...}: testLib.mkSshConfig 2225;
  };

  nodes = {
    # Cache server node (nas-01 equivalent)
    cache-server = {
      config,
      pkgs,
      lib,
      ...
    }: {
      imports = [
        ../clubcotton/services/harmonia
        ../modules/nix-builder
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

        # Generate SSH keys for builder access
        # Real ed25519 keypair generated with: ssh-keygen -t ed25519 -f /tmp/nix-test-key -N "" -C "nix-builder-test"
        environment.etc."nix-builder-key" = {
          mode = "0600";
          text = ''
            -----BEGIN OPENSSH PRIVATE KEY-----
            b3BlbnNzaC1rZXktdjEAAAAABG5vbmUAAAAEbm9uZQAAAAAAAAABAAAAMwAAAAtzc2gtZW
            QyNTUxOQAAACCx72Lb6CgNtRFOyGdj9GhjEz0+FWKvqzfYVDNlGSVY9wAAAJj/xwQo/8cE
            KAAAAAtzc2gtZWQyNTUxOQAAACCx72Lb6CgNtRFOyGdj9GhjEz0+FWKvqzfYVDNlGSVY9w
            AAAEC0M15I24a43gMZW/0670Ua3prZY53l7k6VFAanwmt4ArHvYtvoKA21EU7IZ2P0aGMT
            PT4VYq+rN9hUM2UZJVj3AAAAEG5peC1idWlsZGVyLXRlc3QBAgMEBQ==
            -----END OPENSSH PRIVATE KEY-----
          '';
        };

        environment.etc."nix-builder-key.pub".text = ''
          ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAILHvYtvoKA21EU7IZ2P0aGMTPT4VYq+rN9hUM2UZJVj3 nix-builder-test
        '';

        # Enable Harmonia
        services.clubcotton.harmonia = {
          enable = true;
          port = 5000;
          bindAddress = "0.0.0.0"; # Bind to all interfaces for test network access
          signKeyPath = "/etc/harmonia-test-key"; # Test uses explicit path
          tailnetHostname = null; # mkIf in harmonia module handles tsnsrv conditionally
        };

        # Enable build coordinator
        services.nix-builder.coordinator = {
          enable = true;
          sshKeyPath = "/etc/nix-builder-key";
          builders = [
            {
              hostname = "builder";
              maxJobs = 2;
              speedFactor = 1;
            }
          ];
        };

        systemd.tmpfiles.rules = [
          "d /ssdpool/local/nix-cache 0755 root root - -"
        ];
      };
    };

    # Builder node (nix-01 equivalent)
    builder = {
      config,
      pkgs,
      ...
    }: {
      imports = [
        ../modules/nix-builder/client.nix
      ];

      networking.hostName = "builder";
      networking.firewall.enable = false;

      # Set up builder user
      users.users.nix-builder = {
        isNormalUser = true;
        openssh.authorizedKeys.keys = [
          "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAILHvYtvoKA21EU7IZ2P0aGMTPT4VYq+rN9hUM2UZJVj3 nix-builder-test"
        ];
      };

      services.openssh = {
        enable = true;
        settings.PermitRootLogin = "yes";
      };

      nix.settings.trusted-users = ["nix-builder"];

      # Use cache server
      services.nix-builder.client = {
        enable = true;
        cacheUrl = "http://cache-server:5000";
        publicKey = "test-cache:rLBj8D+R1ij3AJqTfERIFgN/r5xfqK3UXbEpPj5fR8k=";
      };
    };

    # Client node (consumer of cache)
    client = {
      config,
      pkgs,
      ...
    }: {
      imports = [
        ../modules/nix-builder/client.nix
      ];

      networking.hostName = "client";
      networking.firewall.enable = false;

      # Use cache server
      services.nix-builder.client = {
        enable = true;
        cacheUrl = "http://cache-server:5000";
        publicKey = "test-cache:rLBj8D+R1ij3AJqTfERIFgN/r5xfqK3UXbEpPj5fR8k=";
      };
    };
  };

  testScript = ''
    start_all()

    with subtest("Cache server starts"):
        cache_server.wait_for_unit("harmonia.service")
        cache_server.wait_for_open_port(5000)
        cache_server.succeed("curl -f http://localhost:5000/nix-cache-info")

    with subtest("Builder SSH access"):
        # Wait for full network initialization on both machines
        builder.wait_for_unit("multi-user.target")
        cache_server.wait_for_unit("multi-user.target")
        builder.wait_for_unit("sshd.service")
        builder.wait_for_open_port(22)
        # Test SSH connection from cache-server to builder
        cache_server.succeed(
            "ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null "
            "-i /etc/nix-builder-key nix-builder@builder 'echo hello'"
        )

    with subtest("Client can query cache"):
        client.wait_for_unit("multi-user.target")
        client.succeed("curl -f http://cache-server:5000/nix-cache-info")

    with subtest("Cache serves nix-cache-info"):
        output = cache_server.succeed("curl http://localhost:5000/nix-cache-info")
        assert "StoreDir: /nix/store" in output
        print(f"Cache info: {output}")
  '';
}
