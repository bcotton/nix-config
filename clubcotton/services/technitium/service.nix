{
  config,
  lib,
  pkgs,
  ...
}:
with lib; let
  service = "technitium";
  cfg = config.services.clubcotton.${service};
  clubcotton = config.clubcotton;

  # Helper to generate zone configuration script
  generateZoneScript = zones: let
    zoneCommands =
      concatMapStrings (
        zone: let
          recordCommands =
            concatMapStrings (
              record:
                if record.type == "A"
                then ''
                  add_a_record "${zone.zone}" "${record.name}" "${record.ipAddress}" ${
                    if record.createPtrRecord
                    then "true"
                    else "false"
                  }
                  ${concatMapStringsSep "\n" (alias: ''
                    add_cname_record "${zone.zone}" "${alias}" "${record.name}"
                  '') (record.aliases or [])}
                ''
                else if record.type == "CNAME"
                then ''
                  add_cname_record "${zone.zone}" "${record.name}" "${record.target}"
                ''
                else ""
            )
            zone.records;
        in ''
          create_zone "${zone.zone}"
          ${recordCommands}
        ''
      )
      zones;
  in
    zoneCommands;

  # Helper to generate DHCP configuration script
  generateDhcpScript = scopes: reservations: let
    scopeCommands =
      concatMapStringsSep "\n" (scope: ''
        create_scope "${scope.name}" "${scope.interfaceName}" "${scope.startingAddress}" "${scope.endingAddress}" \
          "${scope.subnetMask}" "${scope.gatewayAddress}" "${concatStringsSep "," scope.dnsServers}" \
          "${toString scope.leaseTimeDays}" "${scope.domainName}" ${
          if scope.useThisDnsServer
          then "true"
          else "false"
        } \
          ${
          if scope.pxeBootFileName != null
          then ''"${scope.pxeBootFileName}" "${scope.pxeNextServer}"''
          else ''""  ""''
        }
      '')
      scopes;

    reservationCommands =
      concatMapStringsSep "\n" (res: ''
        add_reservation "${res.scope}" "${res.macAddress}" "${res.ipAddress}" "${res.hostName}"
      '')
      reservations;
  in ''
    ${scopeCommands}
    ${reservationCommands}
  '';
in {
  options.services.clubcotton.${service} = {
    enable = mkEnableOption "Technitium DNS Server";

    package = mkOption {
      type = types.package;
      default = pkgs.technitium-dns-server;
      description = "Technitium DNS Server package";
    };

    mode = mkOption {
      type = types.enum ["primary" "secondary" "standalone"];
      default = "standalone";
      description = "Cluster mode: primary, secondary, or standalone";
    };

    primaryNode = mkOption {
      type = types.nullOr types.str;
      default = null;
      description = "Primary node address for secondary mode (format: host:port)";
    };

    dnsListenAddresses = mkOption {
      type = types.listOf types.str;
      default = ["0.0.0.0"];
      description = "IP addresses for DNS server to listen on";
    };

    webConsolePort = mkOption {
      type = types.port;
      default = 5380;
      description = "HTTP port for web console";
    };

    enableHttps = mkOption {
      type = types.bool;
      default = false;
      description = "Enable HTTPS for web console";
    };

    serverDomain = mkOption {
      type = types.str;
      default = "dns-server.lan";
      description = "Primary domain name for this DNS server";
    };

    localDomain = mkOption {
      type = types.str;
      default = "lan";
      description = "Local domain suffix for internal names";
    };

    forwarders = mkOption {
      type = types.listOf types.str;
      default = ["1.1.1.1" "8.8.4.4"];
      description = "Upstream DNS forwarders";
    };

    forwarderProtocol = mkOption {
      type = types.enum ["Udp" "Tcp" "Tls" "Https" "HttpsJson"];
      default = "Udp";
      description = "Protocol for DNS forwarding";
    };

    cacheMaximumEntries = mkOption {
      type = types.int;
      default = 10000;
      description = "Maximum cache entries";
    };

    cacheMinimumRecordTtl = mkOption {
      type = types.int;
      default = 10;
      description = "Minimum TTL for cached records (seconds)";
    };

    cacheMaximumRecordTtl = mkOption {
      type = types.int;
      default = 300;
      description = "Maximum TTL for cached records (seconds)";
    };

    enableBlocking = mkOption {
      type = types.bool;
      default = true;
      description = "Enable domain blocking";
    };

    blockListUrls = mkOption {
      type = types.listOf types.str;
      default = [];
      description = "URLs for ad-blocking lists (Adblock Plus or hosts format)";
      example = [
        "https://big.oisd.nl/domainswild"
        "https://hagezi.github.io/dns-blocklists/wildcard/pro.txt"
      ];
    };

    recursionAllowedNetworks = mkOption {
      type = types.listOf types.str;
      default = ["127.0.0.0/8" "192.168.0.0/16" "10.0.0.0/8"];
      description = "Networks allowed to use recursive DNS";
    };

    dhcp = {
      enable = mkOption {
        type = types.bool;
        default = false;
        description = "Enable DHCP server";
      };

      scopes = mkOption {
        type = types.listOf (types.submodule {
          options = {
            name = mkOption {
              type = types.str;
              description = "Scope name";
            };
            interfaceName = mkOption {
              type = types.str;
              description = "Network interface name";
            };
            startingAddress = mkOption {
              type = types.str;
              description = "DHCP range starting IP";
            };
            endingAddress = mkOption {
              type = types.str;
              description = "DHCP range ending IP";
            };
            subnetMask = mkOption {
              type = types.str;
              default = "255.255.255.0";
              description = "Subnet mask";
            };
            leaseTimeDays = mkOption {
              type = types.int;
              default = 1;
              description = "Lease time in days";
            };
            gatewayAddress = mkOption {
              type = types.str;
              description = "Gateway/router IP address";
            };
            dnsServers = mkOption {
              type = types.listOf types.str;
              default = [];
              description = "DNS servers to advertise (empty to use this server)";
            };
            domainName = mkOption {
              type = types.str;
              default = "lan";
              description = "Domain name for DHCP clients";
            };
            useThisDnsServer = mkOption {
              type = types.bool;
              default = true;
              description = "Use this DNS server for DHCP clients";
            };
            pxeBootFileName = mkOption {
              type = types.nullOr types.str;
              default = null;
              description = "PXE boot filename";
            };
            pxeNextServer = mkOption {
              type = types.nullOr types.str;
              default = null;
              description = "PXE next server address";
            };
          };
        });
        default = [];
        description = "DHCP scopes configuration";
      };

      reservations = mkOption {
        type = types.listOf (types.submodule {
          options = {
            scope = mkOption {
              type = types.str;
              description = "Scope name";
            };
            macAddress = mkOption {
              type = types.str;
              description = "MAC address (format: 00:11:22:33:44:55)";
            };
            ipAddress = mkOption {
              type = types.str;
              description = "Reserved IP address";
            };
            hostName = mkOption {
              type = types.str;
              description = "Hostname for this reservation";
            };
          };
        });
        default = [];
        description = "DHCP MAC address reservations";
      };
    };

    zones = mkOption {
      type = types.listOf (types.submodule {
        options = {
          zone = mkOption {
            type = types.str;
            description = "Zone name (e.g., lan)";
          };
          records = mkOption {
            type = types.listOf (types.submodule {
              options = {
                name = mkOption {
                  type = types.str;
                  description = "Record name";
                };
                type = mkOption {
                  type = types.enum ["A" "AAAA" "CNAME" "PTR"];
                  description = "Record type";
                };
                ipAddress = mkOption {
                  type = types.nullOr types.str;
                  default = null;
                  description = "IP address (for A/AAAA records)";
                };
                target = mkOption {
                  type = types.nullOr types.str;
                  default = null;
                  description = "Target hostname (for CNAME records)";
                };
                aliases = mkOption {
                  type = types.listOf types.str;
                  default = [];
                  description = "Additional CNAME aliases for this record";
                };
                createPtrRecord = mkOption {
                  type = types.bool;
                  default = true;
                  description = "Automatically create PTR record";
                };
              };
            });
            description = "DNS records in this zone";
          };
        };
      });
      default = [];
      description = "Static DNS zones and records";
    };

    clustering = {
      enable = mkOption {
        type = types.bool;
        default = false;
        description = "Enable clustering support";
      };

      clusterName = mkOption {
        type = types.str;
        default = "cluster";
        description = "Name of the cluster";
      };

      sharedSecret = mkOption {
        type = types.nullOr types.path;
        default = null;
        description = "Path to file containing cluster shared secret";
      };
    };

    stateDir = mkOption {
      type = types.str;
      default = "/var/lib/technitium";
      description = "State directory for Technitium DNS Server";
    };

    adminPasswordFile = mkOption {
      type = types.path;
      description = "File containing admin password for web console";
    };

    user = mkOption {
      type = types.str;
      default = "technitium";
      description = "User account under which Technitium runs";
    };

    group = mkOption {
      type = types.str;
      default = "technitium";
      description = "Group under which Technitium runs";
    };
  };

  config = mkIf cfg.enable {
    # Ensure user and group exist
    users.users.${cfg.user} = {
      isSystemUser = true;
      group = cfg.group;
      home = cfg.stateDir;
      description = "Technitium DNS Server user";
    };

    users.groups.${cfg.group} = {};

    # Create state directory
    systemd.tmpfiles.rules = [
      "d '${cfg.stateDir}' 0750 ${cfg.user} ${cfg.group} - -"
      "d '${cfg.stateDir}/config' 0750 ${cfg.user} ${cfg.group} - -"
    ];

    # Main Technitium DNS Server service
    systemd.services.technitium-dns-server = {
      description = "Technitium DNS Server";
      after = ["network.target"];
      wantedBy = ["multi-user.target"];

      environment = {
        # Basic configuration
        DNS_SERVER_DOMAIN = cfg.serverDomain;
        DNS_SERVER_ADMIN_PASSWORD_FILE = cfg.adminPasswordFile;

        # Web console
        DNS_SERVER_WEB_SERVICE_LOCAL_ADDRESSES = concatStringsSep "," cfg.dnsListenAddresses;
        DNS_SERVER_WEB_SERVICE_HTTP_PORT = toString cfg.webConsolePort;
        DNS_SERVER_WEB_SERVICE_ENABLE_HTTPS = boolToString cfg.enableHttps;

        # DNS settings
        DNS_SERVER_RECURSION = "AllowOnlyForPrivateNetworks";
        DNS_SERVER_RECURSION_ALLOWED_NETWORKS = concatStringsSep "," cfg.recursionAllowedNetworks;
        DNS_SERVER_FORWARDERS = concatStringsSep "," cfg.forwarders;
        DNS_SERVER_FORWARDER_PROTOCOL = cfg.forwarderProtocol;

        # Blocking
        DNS_SERVER_ENABLE_BLOCKING = boolToString cfg.enableBlocking;
        DNS_SERVER_BLOCK_LIST_URLS = concatStringsSep "," cfg.blockListUrls;

        # Cache settings
        DNS_SERVER_CACHE_MAXIMUM_ENTRIES = toString cfg.cacheMaximumEntries;
        DNS_SERVER_CACHE_MINIMUM_RECORD_TTL = toString cfg.cacheMinimumRecordTtl;
        DNS_SERVER_CACHE_MAXIMUM_RECORD_TTL = toString cfg.cacheMaximumRecordTtl;

        # Local zone
        DNS_SERVER_LOCAL_END_POINTS = concatStringsSep "," (map (addr: "${addr}:53") cfg.dnsListenAddresses);
      };

      serviceConfig = {
        Type = "simple";
        User = cfg.user;
        Group = cfg.group;
        WorkingDirectory = cfg.stateDir;
        ExecStart = "${cfg.package}/bin/technitium-dns-server ${cfg.stateDir}";
        Restart = "on-failure";
        RestartSec = "5s";

        # Security hardening
        PrivateTmp = true;
        ProtectSystem = "strict";
        ProtectHome = true;
        ReadWritePaths = [cfg.stateDir];
        NoNewPrivileges = true;

        # Capabilities for DNS (port 53) and DHCP (ports 67/68)
        AmbientCapabilities = ["CAP_NET_BIND_SERVICE" "CAP_NET_RAW"];
        CapabilityBoundingSet = ["CAP_NET_BIND_SERVICE" "CAP_NET_RAW"];
      };
    };

    # Zone configuration service
    systemd.services.technitium-configure-zones = mkIf (cfg.zones != []) {
      description = "Configure Technitium DNS zones";
      after = ["technitium-dns-server.service"];
      wants = ["technitium-dns-server.service"];
      wantedBy = ["multi-user.target"];

      path = with pkgs; [curl jq coreutils];

      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        User = cfg.user;
      };

      script = ''
        set -euo pipefail

        API_BASE="http://localhost:${toString cfg.webConsolePort}/api"
        ADMIN_PASSWORD=$(cat ${cfg.adminPasswordFile})
        TOKEN=""

        # Wait for API to be ready
        echo "Waiting for Technitium API to be ready..."
        for i in {1..60}; do
          if curl -sf "''${API_BASE}/user/profile" > /dev/null 2>&1; then
            echo "API is ready"
            break
          fi
          if [ $i -eq 60 ]; then
            echo "API failed to become ready after 60 seconds"
            exit 1
          fi
          sleep 1
        done

        # Login and get token
        login() {
          TOKEN=$(curl -sf -X POST "''${API_BASE}/user/login" \
            -d "user=admin&pass=''${ADMIN_PASSWORD}" | jq -r '.token')

          if [ -z "$TOKEN" ] || [ "$TOKEN" = "null" ]; then
            echo "Failed to authenticate with API"
            exit 1
          fi
        }

        # Create zone
        create_zone() {
          local zone=$1
          echo "Creating zone: $zone"
          curl -sf -X POST "''${API_BASE}/zones/create?token=''${TOKEN}" \
            -d "zone=$zone&type=Primary" > /dev/null || echo "Zone $zone may already exist"
        }

        # Add A record with optional PTR
        add_a_record() {
          local zone=$1 name=$2 ip=$3 create_ptr=$4
          local fqdn="''${name}.''${zone}"
          echo "Adding A record: $fqdn -> $ip"
          curl -sf -X POST "''${API_BASE}/zones/records/add?token=''${TOKEN}" \
            -d "zone=$zone&type=A&domain=$fqdn&ipAddress=$ip&ptr=$create_ptr&createPtrZone=true" > /dev/null || \
            echo "Record $fqdn may already exist"
        }

        # Add CNAME record
        add_cname_record() {
          local zone=$1 name=$2 target=$3
          local fqdn="''${name}.''${zone}"
          local target_fqdn="''${target}.''${zone}"
          echo "Adding CNAME record: $fqdn -> $target_fqdn"
          curl -sf -X POST "''${API_BASE}/zones/records/add?token=''${TOKEN}" \
            -d "zone=$zone&type=CNAME&domain=$fqdn&cname=$target_fqdn" > /dev/null || \
            echo "CNAME $fqdn may already exist"
        }

        login

        # Generated zone configuration
        ${generateZoneScript cfg.zones}

        echo "Zone configuration complete"
      '';
    };

    # DHCP configuration service
    systemd.services.technitium-configure-dhcp = mkIf (cfg.dhcp.enable && (cfg.dhcp.scopes != [] || cfg.dhcp.reservations != [])) {
      description = "Configure Technitium DHCP";
      after = ["technitium-dns-server.service"];
      wants = ["technitium-dns-server.service"];
      wantedBy = ["multi-user.target"];

      path = with pkgs; [curl jq coreutils];

      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        User = cfg.user;
      };

      script = ''
        set -euo pipefail

        API_BASE="http://localhost:${toString cfg.webConsolePort}/api"
        ADMIN_PASSWORD=$(cat ${cfg.adminPasswordFile})
        TOKEN=""

        # Wait for API to be ready
        echo "Waiting for Technitium API to be ready..."
        for i in {1..60}; do
          if curl -sf "''${API_BASE}/user/profile" > /dev/null 2>&1; then
            echo "API is ready"
            break
          fi
          if [ $i -eq 60 ]; then
            echo "API failed to become ready after 60 seconds"
            exit 1
          fi
          sleep 1
        done

        # Login and get token
        login() {
          TOKEN=$(curl -sf -X POST "''${API_BASE}/user/login" \
            -d "user=admin&pass=''${ADMIN_PASSWORD}" | jq -r '.token')

          if [ -z "$TOKEN" ] || [ "$TOKEN" = "null" ]; then
            echo "Failed to authenticate with API"
            exit 1
          fi
        }

        # Create DHCP scope
        create_scope() {
          local name=$1 interface=$2 start=$3 end=$4 subnet=$5 gateway=$6 dns=$7 lease=$8 domain=$9 use_this_dns=''${10} pxe_file=''${11} pxe_server=''${12}
          echo "Creating DHCP scope: $name"

          local cmd="curl -sf -X POST \"''${API_BASE}/dhcp/scopes/set?token=''${TOKEN}\""
          cmd="$cmd -d \"name=$name\""
          cmd="$cmd -d \"startingAddress=$start\""
          cmd="$cmd -d \"endingAddress=$end\""
          cmd="$cmd -d \"subnetMask=$subnet\""
          cmd="$cmd -d \"leaseTimeDays=$lease\""
          cmd="$cmd -d \"routerAddress=$gateway\""
          cmd="$cmd -d \"domainName=$domain\""
          # Note: interfaceName is not supported by Technitium API - scope binds based on IP range

          if [ "$use_this_dns" = "true" ]; then
            cmd="$cmd -d \"useThisDnsServer=true\""
          elif [ -n "$dns" ]; then
            cmd="$cmd -d \"dnsServers=$dns\""
          fi

          if [ -n "$pxe_file" ] && [ -n "$pxe_server" ]; then
            cmd="$cmd -d \"bootFileName=$pxe_file\""
            cmd="$cmd -d \"serverAddress=$pxe_server\""
          fi

          response=$(eval "$cmd" 2>&1)
          echo "API response for scope $name: $response"
          if [ $? -ne 0 ]; then
            echo "Error creating scope $name: $response"
          else
            echo "Successfully created scope: $name"

            # Enable the scope after creation
            echo "Enabling scope: $name"
            curl -sf -X POST "''${API_BASE}/dhcp/scopes/enable?token=''${TOKEN}" \
              -d "name=$name" > /dev/null || echo "Note: Could not enable scope (may already be enabled)"
          fi
        }

        # Add DHCP reservation
        # Use /dhcp/scopes/addReservedLease to create reservations with specific IPs
        # Note: /dhcp/leases/reserve only reserves existing dynamic leases at their current IP
        add_reservation() {
          local scope=$1 mac=$2 ip=$3 hostname=$4
          echo "Adding DHCP reservation: $hostname ($mac) -> $ip to scope: $scope"

          response=$(curl -sf -X POST "''${API_BASE}/dhcp/scopes/addReservedLease?token=''${TOKEN}" \
            -d "name=$scope" \
            -d "hardwareAddress=$mac" \
            -d "ipAddress=$ip" \
            -d "hostName=$hostname" 2>&1)
          echo "API response for addReservedLease: $response"

          if ! echo "$response" | grep -q '"status":"ok"'; then
            echo "ERROR: Failed to add reservation for $hostname"
          fi
        }

        login

        echo "About to run DHCP configuration..."
        echo "Number of scopes: ${toString (length cfg.dhcp.scopes)}"
        echo "Number of reservations: ${toString (length cfg.dhcp.reservations)}"

        # Generated DHCP configuration
        ${generateDhcpScript cfg.dhcp.scopes cfg.dhcp.reservations}

        echo "DHCP configuration complete"
      '';
    };

    # Firewall configuration
    networking.firewall = {
      allowedTCPPorts = [53 cfg.webConsolePort];
      allowedUDPPorts = [53] ++ optional cfg.dhcp.enable 67 ++ optional cfg.dhcp.enable 68;
    };

    # Assertions
    assertions = [
      {
        assertion = cfg.mode == "secondary" -> cfg.primaryNode != null;
        message = "Primary node must be specified when mode is 'secondary'";
      }
      {
        assertion = cfg.clustering.enable -> cfg.clustering.sharedSecret != null;
        message = "Cluster shared secret must be specified when clustering is enabled";
      }
    ];
  };
}
