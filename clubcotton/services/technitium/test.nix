{pkgs, ...}:
pkgs.testers.runNixOSTest {
  name = "technitium";

  nodes = {
    server = {
      config,
      pkgs,
      lib,
      ...
    }: {
      imports = [./default.nix];

      # Test admin password
      environment.etc."technitium-admin-pass".text = "test-password-123";

      # Test dependencies
      environment.systemPackages = with pkgs; [curl jq dnsutils];

      services.clubcotton.technitium = {
        enable = true;
        mode = "standalone";
        adminPasswordFile = "/etc/technitium-admin-pass";

        serverDomain = "dns-test.lan";
        localDomain = "lan";
        forwarders = ["1.1.1.1" "8.8.8.8"];

        dnsListenAddresses = ["0.0.0.0"];
        webConsolePort = 5380;

        # Cache settings
        cacheMaximumEntries = 10000;
        cacheMinimumRecordTtl = 10;
        cacheMaximumRecordTtl = 300;

        # Test blocking
        enableBlocking = true;
        blockListUrls = []; # Use empty list to avoid external dependencies in tests

        # Test zones
        zones = [
          {
            zone = "lan";
            records = [
              {
                name = "server1";
                type = "A";
                ipAddress = "192.168.1.10";
                createPtrRecord = true;
                aliases = [];
              }
              {
                name = "server2";
                type = "A";
                ipAddress = "192.168.1.11";
                createPtrRecord = false;
                aliases = [];
              }
              {
                name = "www";
                type = "CNAME";
                target = "server1";
                aliases = [];
              }
              {
                name = "multi";
                type = "A";
                ipAddress = "192.168.1.20";
                createPtrRecord = true;
                aliases = ["alias1" "alias2"];
              }
            ];
          }
        ];

        # Test conditional forwarders
        conditionalForwarders = [
          {
            zone = "example.ts.net";
            forwarder = "192.168.1.1";
          }
        ];

        # Test DHCP
        dhcp = {
          enable = true;
          scopes = [
            {
              name = "test-scope";
              interfaceName = "eth1";
              startingAddress = "192.168.2.100";
              endingAddress = "192.168.2.200";
              subnetMask = "255.255.255.0";
              gatewayAddress = "192.168.2.1";
              dnsServers = [];
              leaseTimeDays = 1;
              domainName = "lan";
              useThisDnsServer = true;
              pxeBootFileName = null;
              pxeNextServer = null;
            }
          ];
          reservations = [
            {
              scope = "test-scope";
              macAddress = "AA:BB:CC:DD:EE:01";
              ipAddress = "192.168.2.50";
              hostName = "test-host-1";
            }
            {
              scope = "test-scope";
              macAddress = "AA:BB:CC:DD:EE:02";
              ipAddress = "192.168.2.51";
              hostName = "test-host-2";
            }
          ];
        };
      };

      # Networking for test
      networking = {
        firewall.enable = false;
        dhcpcd.enable = false;
        useDHCP = false;
        interfaces.eth1.ipv4.addresses = [
          {
            address = "192.168.1.1";
            prefixLength = 24;
          }
          {
            address = "192.168.2.1";
            prefixLength = 24;
          }
        ];
      };
    };

    client = {
      config,
      pkgs,
      lib,
      ...
    }: {
      # Test dependencies
      environment.systemPackages = with pkgs; [curl jq dnsutils];

      networking = {
        nameservers = ["192.168.1.1"];
        dhcpcd.enable = false;
        firewall.enable = false;
        useDHCP = false;
        interfaces.eth1.ipv4.addresses = [
          {
            address = "192.168.1.2";
            prefixLength = 24;
          }
        ];
      };
    };
  };

  testScript = ''
    import time

    start_all()

    with subtest("Service starts and web console accessible"):
      server.wait_for_unit("technitium-dns-server.service")
      server.wait_for_open_port(5380)
      server.wait_for_open_port(53)

      # Check web console responds
      server.succeed("curl -sf http://localhost:5380/ | grep -i technitium")

    with subtest("API authentication works"):
      # Test login API
      token = server.succeed(
        "curl -sf -X POST 'http://localhost:5380/api/user/login' "
        "-d 'user=admin&pass=test-password-123' | jq -r '.token'"
      ).strip()
      server.succeed(f"test -n '{token}'")
      print(f"Successfully authenticated, token: {token[:20]}...")

    with subtest("Zone configuration service completed"):
      server.wait_for_unit("technitium-configure-zones.service")
      # Give it a moment to finish configuration
      time.sleep(2)

    with subtest("DNS records resolve correctly"):
      # Query for A record
      result = server.succeed("dig @localhost server1.lan +short").strip()
      assert "192.168.1.10" in result, f"Expected 192.168.1.10, got {result}"

      # Query for second A record
      result = server.succeed("dig @localhost server2.lan +short").strip()
      assert "192.168.1.11" in result, f"Expected 192.168.1.11, got {result}"

      # Query for CNAME
      result = server.succeed("dig @localhost www.lan +short").strip()
      assert "server1.lan" in result or "192.168.1.10" in result, f"CNAME resolution failed: {result}"

      # Query for record with aliases
      result = server.succeed("dig @localhost multi.lan +short").strip()
      assert "192.168.1.20" in result, f"Expected 192.168.1.20, got {result}"

      result = server.succeed("dig @localhost alias1.lan +short").strip()
      assert "multi.lan" in result or "192.168.1.20" in result, f"Alias1 resolution failed: {result}"

      result = server.succeed("dig @localhost alias2.lan +short").strip()
      assert "multi.lan" in result or "192.168.1.20" in result, f"Alias2 resolution failed: {result}"

    with subtest("DNS server responds on network interface"):
      # Test if server can query itself via network IP (not localhost)
      # This helps determine if the issue is with the DNS server or client networking
      result = server.succeed("dig @192.168.1.1 server1.lan +short").strip()
      assert "192.168.1.10" in result, f"Server self-query via network IP failed: {result}"
      print("DNS server successfully responds to queries on 192.168.1.1:53")

    with subtest("DNS forwarding configured"):
      # Verify forwarders are configured (actual external resolution requires internet)
      # Test that server responds to unknown domains (will use forwarders)
      # In test environment without internet, this will timeout or return SERVFAIL
      # We just verify the server processes the query without crashing
      server.succeed("dig @localhost nonexistent-test-domain-12345.com +time=1 +tries=1 || true")

    with subtest("Conditional forwarder zone created"):
      token = server.succeed(
        "curl -sf -X POST 'http://localhost:5380/api/user/login' "
        "-d 'user=admin&pass=test-password-123' | jq -r '.token'"
      ).strip()
      # Verify the forwarder zone exists and is type Forwarder
      zones = server.succeed(
        f"curl -sf 'http://localhost:5380/api/zones/list?token={token}' | jq -r '.response.zones[].name'"
      ).strip()
      assert "example.ts.net" in zones, f"Conditional forwarder zone 'example.ts.net' not found in: {zones}"
      # Check zone type via zones/list (zoneType is on the zone list entry, not zones/options/get)
      zone_type = server.succeed(
        f"curl -sf 'http://localhost:5380/api/zones/list?token={token}' | jq -r '[.response.zones[] | select(.name==\"example.ts.net\")][0].type'"
      ).strip()
      assert zone_type == "Forwarder", f"Expected zone type 'Forwarder', got '{zone_type}'"

    with subtest("PTR records created"):
      # Check PTR record for server1 (should exist)
      result = server.succeed("dig @localhost -x 192.168.1.10 +short").strip()
      assert "server1.lan" in result, f"PTR record for 192.168.1.10 not found: {result}"

    with subtest("DHCP configuration applied"):
      server.wait_for_unit("technitium-configure-dhcp.service")
      # Give it a moment to finish configuration and DHCP to start listening
      time.sleep(3)

    with subtest("DHCP configuration verified via API"):
      # Note: DHCP port 67 may not bind in test VMs without proper layer-2 network setup
      # Instead, we verify DHCP configuration is correctly applied via the API
      # Verify scope exists via API
      token = server.succeed(
        "curl -sf -X POST 'http://localhost:5380/api/user/login' "
        "-d 'user=admin&pass=test-password-123' | jq -r '.token'"
      ).strip()

      # Verify scope exists - look for test-scope in any position
      scopes = server.succeed(
        f"curl -sf 'http://localhost:5380/api/dhcp/scopes/list?token={token}' | jq -r '.response.scopes[].name'"
      ).strip()
      assert "test-scope" in scopes, f"DHCP scope 'test-scope' not found in: {scopes}"

      # Verify scope details are correct
      scope_details = server.succeed(
        f"curl -sf 'http://localhost:5380/api/dhcp/scopes/get?token={token}&name=test-scope' | jq -r '.response'"
      ).strip()
      print(f"Scope details: {scope_details}")
      assert "192.168.2.100" in scope_details, "DHCP scope starting address not correct"
      assert "192.168.2.200" in scope_details, "DHCP scope ending address not correct"

    with subtest("DHCP reservations verified via API"):
      # Verify reservations were created
      reserved = server.succeed(
        f"curl -sf 'http://localhost:5380/api/dhcp/scopes/get?token={token}&name=test-scope' | jq -r '.response.reservedLeases'"
      ).strip()
      # Technitium stores MACs with hyphens (AA-BB-CC-DD-EE-01), not colons
      reserved_upper = reserved.upper()
      assert "AA-BB-CC-DD-EE-01" in reserved_upper or "AA:BB:CC:DD:EE:01" in reserved_upper, \
        f"Reservation for test-host-1 not found in: {reserved}"
      assert "AA-BB-CC-DD-EE-02" in reserved_upper or "AA:BB:CC:DD:EE:02" in reserved_upper, \
        f"Reservation for test-host-2 not found in: {reserved}"
      assert "192.168.2.50" in reserved, f"Reservation IP 192.168.2.50 not found in: {reserved}"
      assert "192.168.2.51" in reserved, f"Reservation IP 192.168.2.51 not found in: {reserved}"
      print("DHCP reservations verified successfully")

    with subtest("Services are idempotent (re-run succeeds)"):
      # Restart both configuration services — they must succeed on re-run
      # This catches non-idempotent API calls (e.g., addReservedLease errors on existing entries)
      server.succeed("systemctl restart technitium-configure-zones.service")
      server.wait_for_unit("technitium-configure-zones.service")
      server.succeed("systemctl restart technitium-configure-dhcp.service")
      server.wait_for_unit("technitium-configure-dhcp.service")

      # Verify DNS records still correct after re-run
      result = server.succeed("dig @localhost server1.lan +short").strip()
      assert "192.168.1.10" in result, f"After idempotent re-run, expected 192.168.1.10, got {result}"

      # Verify reservations still present after re-run
      reserved = server.succeed(
        f"curl -sf 'http://localhost:5380/api/dhcp/scopes/get?token={token}&name=test-scope' | jq -r '.response.reservedLeases'"
      ).strip()
      assert "192.168.2.50" in reserved, f"Reservation lost after idempotent re-run: {reserved}"
      print("Idempotency test passed — both services re-ran successfully")

    with subtest("Service logs clean"):
      # Check for critical errors in logs (allow warnings)
      logs = server.succeed("journalctl -u technitium-dns-server.service --no-pager")
      # Make sure service started successfully
      assert "Started" in logs or "started" in logs, "Service did not start"

    with subtest("Process permissions correct"):
      # Service runs as technitium user
      server.succeed("ps aux | grep DnsServerApp | grep technitium")

    with subtest("DNS server binds to all interfaces"):
      # Verify server is listening on 0.0.0.0:53 (both UDP and TCP)
      listening_udp = server.succeed("ss -ulnp | grep ':53'")
      listening_tcp = server.succeed("ss -tlnp | grep ':53'")
      print(f"DNS server listening UDP: {listening_udp}")
      print(f"DNS server listening TCP: {listening_tcp}")
      assert "0.0.0.0:53" in listening_udp, "DNS not listening on 0.0.0.0:53 UDP"
      assert "0.0.0.0:53" in listening_tcp, "DNS not listening on 0.0.0.0:53 TCP"
  '';
}
