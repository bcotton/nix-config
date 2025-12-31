{
  config,
  lib,
  pkgs,
  ...
}:
with lib; let
  cfg = config.clubcotton.systemd-network;

  # VLAN configuration
  vlans = [
    {
      id = 10;
      subnet = "192.168.10";
    }
    {
      id = 20;
      subnet = "192.168.20";
    }
  ];
in {
  options.clubcotton.systemd-network = {
    enable = mkEnableOption "systemd-networkd with VLAN and bonding support";

    mode = mkOption {
      type = types.enum ["single-nic" "bonded"];
      description = "Network configuration mode: single-nic for simple setups, bonded for dual-NIC bonding";
    };

    interfaces = mkOption {
      type = types.listOf types.str;
      description = "List of physical network interfaces to use";
      example = ["enp2s0" "enp3s0"];
    };

    bondName = mkOption {
      type = types.str;
      default = "bond0";
      description = "Name of the bond device (for bonded mode)";
    };

    bridgeName = mkOption {
      type = types.str;
      default = "br0";
      description = "Name of the bridge device for Incus VMs";
    };

    nativeVlan = mkOption {
      type = types.submodule {
        options = {
          id = mkOption {
            type = types.int;
            default = 5;
            description = "VLAN ID for the native/untagged traffic";
          };

          address = mkOption {
            type = types.str;
            description = "Static IP address for the native VLAN";
            example = "192.168.5.210/24";
          };

          gateway = mkOption {
            type = types.str;
            description = "Default gateway for the native VLAN";
            example = "192.168.5.1";
          };

          dns = mkOption {
            type = types.listOf types.str;
            default = ["192.168.5.220"];
            description = "DNS servers";
          };
        };
      };
      description = "Native/untagged VLAN configuration";
    };

    enableVlans = mkOption {
      type = types.bool;
      default = true;
      description = "Enable additional VLANs (10, 20)";
    };

    enableIncusBridge = mkOption {
      type = types.bool;
      default = false;
      description = "Enable bridge for Incus VMs";
    };
  };

  config = mkIf cfg.enable {
    # Ensure systemd-networkd is enabled
    networking.useNetworkd = true;
    networking.useDHCP = false;

    # Disable traditional networking to avoid conflicts
    networking.interfaces = {};
    networking.bridges = {};
    networking.vlans = {};
    networking.bonds = {};

    systemd.network.enable = true;

    systemd.network.netdevs =
      # Bond configuration (only for bonded mode)
      (optionalAttrs (cfg.mode == "bonded") {
        "10-${cfg.bondName}" = {
          netdevConfig = {
            Kind = "bond";
            Name = cfg.bondName;
          };
          bondConfig = {
            Mode = "802.3ad";
            TransmitHashPolicy = "layer3+4";
            LACPTransmitRate = "fast";
            MIIMonitorSec = "0.1s";
          };
        };
      })
      //
      # Bridge configuration
      (optionalAttrs cfg.enableIncusBridge {
        "20-${cfg.bridgeName}" = {
          netdevConfig = {
            Kind = "bridge";
            Name = cfg.bridgeName;
          };
          bridgeConfig = {
            STP = false;
          };
        };
      })
      //
      # VLAN netdevs on bridge (if bridge enabled)
      (optionalAttrs (cfg.enableIncusBridge && cfg.enableVlans) (
        listToAttrs (map (vlan: {
            name = "30-${cfg.bridgeName}.${toString vlan.id}";
            value = {
              netdevConfig = {
                Kind = "vlan";
                Name = "${cfg.bridgeName}.${toString vlan.id}";
              };
              vlanConfig = {
                Id = vlan.id;
              };
            };
          })
          vlans)
      ))
      //
      # VLAN netdevs directly on interface (if bridge not enabled, for single-nic mode)
      (optionalAttrs (!cfg.enableIncusBridge && cfg.enableVlans && cfg.mode == "single-nic") (
        let
          baseIface = elemAt cfg.interfaces 0;
        in
          listToAttrs (map (vlan: {
              name = "30-${baseIface}.${toString vlan.id}";
              value = {
                netdevConfig = {
                  Kind = "vlan";
                  Name = "${baseIface}.${toString vlan.id}";
                };
                vlanConfig = {
                  Id = vlan.id;
                };
              };
            })
            vlans)
      ))
      //
      # VLAN netdevs on bond (if bridge not enabled, for bonded mode)
      (optionalAttrs (!cfg.enableIncusBridge && cfg.enableVlans && cfg.mode == "bonded") (
        listToAttrs (map (vlan: {
            name = "30-${cfg.bondName}.${toString vlan.id}";
            value = {
              netdevConfig = {
                Kind = "vlan";
                Name = "${cfg.bondName}.${toString vlan.id}";
              };
              vlanConfig = {
                Id = vlan.id;
              };
            };
          })
          vlans)
      ));

    systemd.network.networks =
      # Physical interface configuration
      (listToAttrs (map (iface: {
          name = "10-${iface}";
          value =
            if cfg.mode == "bonded"
            then {
              # Bonded mode: enslave interfaces to bond
              matchConfig.Name = iface;
              networkConfig.Bond = cfg.bondName;
              linkConfig.RequiredForOnline = "enslaved";
            }
            else {
              # Single NIC mode: configure interface directly
              matchConfig.Name = iface;
              networkConfig = mkMerge [
                (mkIf cfg.enableIncusBridge {Bridge = cfg.bridgeName;})
                (mkIf (!cfg.enableIncusBridge) {
                  Address = cfg.nativeVlan.address;
                  Gateway = cfg.nativeVlan.gateway;
                  DNS = cfg.nativeVlan.dns;
                  DHCP = "no";
                })
              ];
              # Create VLANs directly on interface if no bridge
              vlan = mkIf (!cfg.enableIncusBridge && cfg.enableVlans) (map (v: "${iface}.${toString v.id}") vlans);
              linkConfig.RequiredForOnline = mkIf cfg.enableIncusBridge "enslaved";
            };
        })
        cfg.interfaces))
      //
      # Bond configuration (only for bonded mode)
      (optionalAttrs (cfg.mode == "bonded") {
        "20-${cfg.bondName}" = mkMerge [
          {
            matchConfig.Name = cfg.bondName;
            linkConfig.RequiredForOnline = "carrier";
          }
          # If bridge enabled, enslave bond to bridge
          (mkIf cfg.enableIncusBridge {
            networkConfig.Bridge = cfg.bridgeName;
          })
          # If no bridge, configure bond with native IP and VLANs
          (mkIf (!cfg.enableIncusBridge) {
            networkConfig = {
              Address = cfg.nativeVlan.address;
              Gateway = cfg.nativeVlan.gateway;
              DNS = cfg.nativeVlan.dns;
              DHCP = "no";
            };
            vlan = mkIf cfg.enableVlans (map (v: "${cfg.bondName}.${toString v.id}") vlans);
          })
        ];
      })
      //
      # Bridge configuration with native VLAN IP
      (optionalAttrs cfg.enableIncusBridge {
        "30-${cfg.bridgeName}" = {
          matchConfig.Name = cfg.bridgeName;
          networkConfig = {
            Address = cfg.nativeVlan.address;
            Gateway = cfg.nativeVlan.gateway;
            DNS = cfg.nativeVlan.dns;
            DHCP = "no";
          };
          # Create VLANs on bridge
          vlan = mkIf cfg.enableVlans (map (v: "${cfg.bridgeName}.${toString v.id}") vlans);
          linkConfig.RequiredForOnline = "routable";
        };
      })
      //
      # VLAN network configurations on bridge
      (optionalAttrs (cfg.enableIncusBridge && cfg.enableVlans) (
        listToAttrs (map (vlan: {
            name = "40-${cfg.bridgeName}.${toString vlan.id}";
            value = {
              matchConfig.Name = "${cfg.bridgeName}.${toString vlan.id}";
              networkConfig = {
                DHCP = "yes";
                # Keep VLANs as secondary interfaces
                KeepConfiguration = "dhcp";
              };
              dhcpV4Config = {
                RouteMetric = 1024; # Higher metric so native VLAN is preferred
                UseDNS = false; # Don't override DNS from native VLAN
                UseRoutes = false; # Don't add default routes
              };
              linkConfig.RequiredForOnline = "no";
            };
          })
          vlans)
      ))
      //
      # VLAN network configurations on interface (single-nic, no bridge)
      (optionalAttrs (!cfg.enableIncusBridge && cfg.enableVlans && cfg.mode == "single-nic") (
        let
          baseIface = elemAt cfg.interfaces 0;
        in
          listToAttrs (map (vlan: {
              name = "40-${baseIface}.${toString vlan.id}";
              value = {
                matchConfig.Name = "${baseIface}.${toString vlan.id}";
                networkConfig = {
                  DHCP = "yes";
                  KeepConfiguration = "dhcp";
                };
                dhcpV4Config = {
                  RouteMetric = 1024;
                  UseDNS = false;
                  UseRoutes = false;
                };
                linkConfig.RequiredForOnline = "no";
              };
            })
            vlans)
      ))
      //
      # VLAN network configurations on bond (bonded, no bridge)
      (optionalAttrs (!cfg.enableIncusBridge && cfg.enableVlans && cfg.mode == "bonded") (
        listToAttrs (map (vlan: {
            name = "40-${cfg.bondName}.${toString vlan.id}";
            value = {
              matchConfig.Name = "${cfg.bondName}.${toString vlan.id}";
              networkConfig = {
                DHCP = "yes";
                KeepConfiguration = "dhcp";
              };
              dhcpV4Config = {
                RouteMetric = 1024;
                UseDNS = false;
                UseRoutes = false;
              };
              linkConfig.RequiredForOnline = "no";
            };
          })
          vlans)
      ));

    # Set proper network settings
    networking.defaultGateway = mkIf cfg.enable {
      address = cfg.nativeVlan.gateway;
      interface =
        if cfg.enableIncusBridge
        then cfg.bridgeName
        else if cfg.mode == "bonded"
        then cfg.bondName
        else elemAt cfg.interfaces 0;
    };

    networking.nameservers = mkIf cfg.enable cfg.nativeVlan.dns;

    # Wait for network to be online
    systemd.services.systemd-networkd-wait-online.serviceConfig.ExecStart = [
      "" # Clear the default
      "${pkgs.systemd}/lib/systemd/systemd-networkd-wait-online --any"
    ];
  };
}
