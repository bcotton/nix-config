{
  config,
  pkgs,
  ...
}: let
  hostsPath = "https://raw.githubusercontent.com/StevenBlack/hosts/3.15.8/alternates/fakenews/hosts";
  hostsFile = builtins.fetchurl {
    url = hostsPath;
    sha256 = "04i3mp2l6qr079pgxdjnkv0m4kaxks6aj34c8jy3dbsdb97sg1gh";
  };
in {
  config = {
    # Ensure dnsmasq waits for network interfaces to be configured
    systemd.services.dnsmasq = {
      after = ["network-online.target"];
      wants = ["network-online.target"];
    };

    services.prometheus.exporters.dnsmasq.enable = true;
    services.dnsmasq = {
      enable = true;
      settings.addn-hosts = [hostsFile "${./clubcotton.list}"];

      settings.bind-dynamic = true;
      settings.bogus-priv = true;
      settings.cache-size = 10000;
      settings.domain-needed = true;

      settings.dhcp-authoritative = true;
      settings.dhcp-range = [
        "192.168.5.10,192.168.5.199,24h"
        "vlan10,192.168.10.10,192.168.10.200,255.255.255.0,24h"
        "vlan20,192.168.20.10,192.168.20.200,255.255.255.0,24h"
      ];
      settings.dhcp-option = [
        "option:router,192.168.5.1"
        "vlan10,3,192.168.10.1"
        "vlan10,6,192.168.10.220"
        "vlan10,option:router,192.168.10.1"
        "vlan20.20,3,192.168.20.1"
        "vlan20.20,6,192.168.20.220"
        "vlan20,option:router,192.168.20.1"
      ];

      # enable-tftp
      # tftp-no-fail
      # tftp-unique-root
      # tftp-root=/var/lib/tftpboot

      # Send netboot to MaaS
      # pxe-service=x86PC,"Network Boot",pxelinux.0,192.168.5.169
      # dhcp-boot=pxelinux.0,192.168.5.196

      # This is for netbook.xyz
      #pxe-prompt="Choose:"
      settings.pxe-service = "x86PC,'Network Boot',netboot.xyz.efi,192.168.5.169";

      #pxe-service=x86-64_EFI,"Network Boot x86-64_EFI",netboot.xyz.efi,192.168.5.169
      #pxe-service=IA64_EFI,"Network Boot IA64_EFI",netboot.xyz.efi,192.168.5.169
      #pxe-service=Arc_x86,"Network Boot x86-64_EFI",netboot.xyz.kpxe,192.168.5.169
      #dhcp-boot=netboot.xyz.kpxe,192.168.5.169,192.168.5.169
      #dhcp-boot=netboot.xyz.efi,192.168.5.169

      settings.dhcp-name-match = ["set:hostname-ignore,wpad" "set:hostname-ignore,localhost"];
      settings.dhcp-ignore-names = "tag:hostname-ignore";
      settings.dhcp-hostsfile = "${./dhcp-hosts.list}";

      settings.domain = "lan";
      settings.local = "/lan/";

      settings.expand-hosts = true;
      settings.listen-address = ["::1" "127.0.0.1" "192.168.5.220" "192.168.10.220" "192.168.20.220"];
      settings.localise-queries = true;
      settings.local-service = true;
      settings.log-queries = true;
      # settings.log-facility = "/tmp/ad-block.log";
      settings.log-async = true;
      settings.local-ttl = 300;

      settings.no-hosts = true;
      settings.no-resolv = true;
      settings.server = ["1.1.1.1" "8.8.4.4"];
    };
  };
}
