{nixpkgs}: {
  name = "firewall-integration";

  nodes = {
    # Server node with firewall enabled
    server = {
      config,
      pkgs,
      lib,
      ...
    }: {
      # Enable OpenSSH
      services.openssh = {
        enable = true;
        settings.PermitRootLogin = "yes";
      };
      users.users.root = {
        initialPassword = "test";
        hashedPasswordFile = lib.mkForce null;
      };

      # Simple web server on port 8080
      services.nginx = {
        enable = true;
        virtualHosts."test" = {
          listen = [
            {
              addr = "0.0.0.0";
              port = 8080;
            }
          ];
          locations."/".return = "200 'OK'";
        };
      };

      # Enable firewall with specific ports open
      networking.firewall = {
        enable = true;
        allowedTCPPorts = [22 8080 9100];
      };
    };

    # Client node to test connectivity
    client = {...}: {
      # Just a basic client node
    };
  };

  testScript = ''
    start_all()

    with subtest("Server firewall is enabled"):
        server.wait_for_unit("firewall.service")
        server.succeed("systemctl is-active firewall.service")

    with subtest("SSH service is listening"):
        server.wait_for_unit("sshd.service")
        server.wait_for_open_port(22)

    with subtest("Nginx service is listening"):
        server.wait_for_unit("nginx.service")
        server.wait_for_open_port(8080)

    with subtest("Client can reach allowed SSH port"):
        client.wait_until_succeeds("nc -z server 22", timeout=30)

    with subtest("Client can reach allowed HTTP port"):
        client.wait_until_succeeds("nc -z server 8080", timeout=30)

    with subtest("Client cannot reach blocked port"):
        # Port 12345 is not in allowedTCPPorts - should timeout/fail
        client.fail("nc -z -w 2 server 12345")
  '';
}
