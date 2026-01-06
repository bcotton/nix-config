# Edit this configuration file to define what should be installed on
# your system. Help is available in the configuration.nix(5) man page, on
# https://search.nixos.org/options and in the NixOS manual (`nixos-help`).
{
  config,
  pkgs,
  unstablePkgs,
  hostName,
  ...
}: let
  # Get merged variables (defaults + host overrides)
  commonLib = import ../../common/lib.nix;
  variables = commonLib.getHostVariables hostName;
  keys = import ../../common/keys.nix;
in {
  imports = [
    # Include the results of the hardware scan.
    ./hardware-configuration.nix
    ../../../modules/node-exporter
    ../../../modules/systemd-network
  ];

  # Agenix secrets
  age.secrets.technitium-admin-password = {
    file = ../../../secrets/technitium-admin-password.age;
    owner = "technitium";
    group = "technitium";
  };

  # Ensure that nix can get to the cache server
  networking.extraHosts = ''
    192.168.5.42 nas-01
  '';

  services.clubcotton = {
    nut-client.enable = true;

    # Technitium DNS Server
    technitium = {
      enable = true;
      serverDomain = "dns-01.lan";
      localDomain = "lan";
      adminPasswordFile = config.age.secrets.technitium-admin-password.path;

      dnsListenAddresses = ["0.0.0.0"];
      forwarders = ["1.1.1.1" "8.8.4.4"];

      # Enable ad blocking
      enableBlocking = true;
      blockListUrls = [
        "https://raw.githubusercontent.com/StevenBlack/hosts/master/alternates/fakenews/hosts"
      ];

      # DHCP configuration
      dhcp = {
        enable = true;
        scopes = [
          {
            name = "main";
            interfaceName = "eno1";
            startingAddress = "192.168.5.10";
            endingAddress = "192.168.5.199";
            subnetMask = "255.255.255.0";
            gatewayAddress = "192.168.5.1";
            dnsServers = ["192.168.5.220"];
            domainName = "lan";
            leaseTimeDays = 1;
            useThisDnsServer = true;
            pxeBootFileName = "netboot.xyz.efi";
            pxeNextServer = "192.168.5.169";
          }
          {
            name = "vlan10";
            interfaceName = "eno1.10";
            startingAddress = "192.168.10.10";
            endingAddress = "192.168.10.200";
            subnetMask = "255.255.255.0";
            gatewayAddress = "192.168.10.1";
            dnsServers = ["192.168.10.220"];
            domainName = "lan";
            leaseTimeDays = 1;
            useThisDnsServer = true;
          }
          {
            name = "vlan20";
            interfaceName = "eno1.20";
            startingAddress = "192.168.20.10";
            endingAddress = "192.168.20.200";
            subnetMask = "255.255.255.0";
            gatewayAddress = "192.168.20.1";
            dnsServers = ["192.168.20.220"];
            domainName = "lan";
            leaseTimeDays = 1;
            useThisDnsServer = true;
          }
        ];

        reservations = [
          # Main VLAN (192.168.5.x)
          {
            scope = "main";
            macAddress = "00:08:9B:C2:D7:5F";
            ipAddress = "192.168.5.7";
            hostName = "qnap1";
          }
          {
            scope = "main";
            macAddress = "00:50:56:01:32:22";
            ipAddress = "192.168.5.20";
            hostName = "homeassistant-new";
          }
          {
            scope = "main";
            macAddress = "da:54:a9:ad:cf:10";
            ipAddress = "192.168.5.22";
            hostName = "toms-mini";
          }
          {
            scope = "main";
            macAddress = "98:b7:85:1f:fa:8d";
            ipAddress = "192.168.5.42";
            hostName = "nas-01";
          }
          {
            scope = "main";
            macAddress = "b8:8a:60:cb:2d:39";
            ipAddress = "192.168.5.49";
            hostName = "octoprint";
          }
          {
            scope = "main";
            macAddress = "b8:27:eb:4d:e6:cd";
            ipAddress = "192.168.5.47";
            hostName = "audio-01";
          }
          {
            scope = "main";
            macAddress = "08:66:98:8B:20:84";
            ipAddress = "192.168.5.51";
            hostName = "Apple-TV";
          }
          {
            scope = "main";
            macAddress = "12:00:5f:b5:a4:2a";
            ipAddress = "192.168.5.62";
            hostName = "kvm";
          }
          {
            scope = "main";
            macAddress = "00:23:24:c2:17:5b";
            ipAddress = "192.168.5.54";
            hostName = "nix-04";
          }
          {
            scope = "main";
            macAddress = "40:5b:d6:a8:5b:cb";
            ipAddress = "192.168.5.68";
            hostName = "incus";
          }
          {
            scope = "main";
            macAddress = "00:E0:4C:BA:91:FC";
            ipAddress = "192.168.5.83";
            hostName = "bobs-laptop";
          }
          {
            scope = "main";
            macAddress = "6C:4B:90:62:7A:01";
            ipAddress = "192.168.5.98";
            hostName = "admin";
          }
          {
            scope = "main";
            macAddress = "24:5A:4C:18:55:9D";
            ipAddress = "192.168.5.130";
            hostName = "OfficeSwitch";
          }
          {
            scope = "main";
            macAddress = "3c:ec:ef:a4:23:00";
            ipAddress = "192.168.5.143";
            hostName = "nas-01-kvm";
          }
          {
            scope = "main";
            macAddress = "8C:3B:AD:BC:42:BF";
            ipAddress = "192.168.5.119";
            hostName = "bens-desktop";
          }
          {
            scope = "main";
            macAddress = "1E:F8:D1:DC:91:37";
            ipAddress = "192.168.5.168";
            hostName = "bens-iphone";
          }
          {
            scope = "main";
            macAddress = "88:63:df:c6:ed:17";
            ipAddress = "192.168.5.153";
            hostName = "imac-02";
          }
          {
            scope = "main";
            macAddress = "c8:c9:a3:f9:cc:68";
            ipAddress = "192.168.5.192";
            hostName = "fireplace-led";
          }
          {
            scope = "main";
            macAddress = "6c:4b:90:31:73:72";
            ipAddress = "192.168.5.200";
            hostName = "k3s-01";
          }
          {
            scope = "main";
            macAddress = "6c:4b:90:2E:9E:7F";
            ipAddress = "192.168.5.201";
            hostName = "k3s-02";
          }
          {
            scope = "main";
            macAddress = "6c:4b:90:31:66:D2";
            ipAddress = "192.168.5.202";
            hostName = "k3s-03";
          }
          {
            scope = "main";
            macAddress = "58:47:ca:74:27:2a";
            ipAddress = "192.168.5.210";
            hostName = "nix-01";
          }
          {
            scope = "main";
            macAddress = "58:47:ca:74:27:2b";
            ipAddress = "192.168.5.211";
            hostName = "nix-01b";
          }
          {
            scope = "main";
            macAddress = "58:47:CA:74:2c:76";
            ipAddress = "192.168.5.212";
            hostName = "nix-02";
          }
          {
            scope = "main";
            macAddress = "58:47:CA:74:2c:77";
            ipAddress = "192.168.5.213";
            hostName = "nix-02b";
          }

          # VLAN 20 (192.168.20.x)
          {
            scope = "vlan20";
            macAddress = "90:5A:E6:27:84:3C";
            ipAddress = "192.168.20.11";
            hostName = "esp-mmw-motion-01";
          }
          {
            scope = "vlan20";
            macAddress = "E4:5F:01:40:8D:61";
            ipAddress = "192.168.20.20";
            hostName = "homeassistant";
          }
          {
            scope = "vlan20";
            macAddress = "d0:3f:27:4e:fd:6a";
            ipAddress = "192.168.20.40";
            hostName = "frontporch-camera";
          }
          {
            scope = "vlan20";
            macAddress = "c2:30:bc:16:17:ef";
            ipAddress = "192.168.20.52";
            hostName = "master-bath-tablet";
          }
          {
            scope = "vlan20";
            macAddress = "C8:C9:A3:1B:B4:5E";
            ipAddress = "192.168.20.78";
            hostName = "ratgdo";
          }
          {
            scope = "vlan20";
            macAddress = "7C:87:CE:55:81:54";
            ipAddress = "192.168.20.83";
            hostName = "shelly-codetecter";
          }
          {
            scope = "vlan20";
            macAddress = "3C:61:05:73:0D:4C";
            ipAddress = "192.168.20.125";
            hostName = "shelly-smokedetector";
          }
          {
            scope = "vlan20";
            macAddress = "ec:71:db:7d:70:f3";
            ipAddress = "192.168.20.129";
            hostName = "camera-reolink-outside-north";
          }
          {
            scope = "vlan20";
            macAddress = "68:9E:19:AE:DF:1E";
            ipAddress = "192.168.20.130";
            hostName = "lutron-controller";
          }
          {
            scope = "vlan20";
            macAddress = "C8:C9:A3:FC:EC:24";
            ipAddress = "192.168.20.137";
            hostName = "esp-ble-broadcast-1";
          }
          {
            scope = "vlan20";
            macAddress = "68:f6:3b:d8:cb:7d";
            ipAddress = "192.168.20.168";
            hostName = "kitchen-tablet";
          }
          {
            scope = "vlan20";
            macAddress = "6c:4b:90:90:31:73";
            ipAddress = "192.168.20.174";
            hostName = "frigate";
          }
          {
            scope = "vlan20";
            macAddress = "8C:CE:4E:95:9C:D3";
            ipAddress = "192.168.20.180";
            hostName = "zigbee-controller";
          }
          {
            scope = "vlan20";
            macAddress = "d2:21:f9:29:f6:b5";
            ipAddress = "192.168.20.188";
            hostName = "plant-monitor";
          }
          {
            scope = "vlan20";
            macAddress = "D0:21:F9:49:F6:B5";
            ipAddress = "192.168.20.187";
            hostName = "plant-cam";
          }
          {
            scope = "vlan20";
            macAddress = "b4:23:30:26:3d:b1";
            ipAddress = "192.168.20.195";
            hostName = "iton-meter";
          }
          {
            scope = "vlan20";
            macAddress = "D2:21:F9:29:F6:B5";
            ipAddress = "192.168.20.199";
            hostName = "esp-keyboard-wake";
          }
        ];
      };

      # DNS zones
      zones = [
        {
          zone = "lan";
          records = [
            # Main VLAN hosts
            {
              name = "toms-mini";
              type = "A";
              ipAddress = "192.168.5.22";
              createPtrRecord = true;
            }
            {
              name = "nix-04";
              type = "A";
              ipAddress = "192.168.5.54";
              createPtrRecord = true;
            }
            {
              name = "nas-01";
              type = "A";
              ipAddress = "192.168.5.42";
              createPtrRecord = true;
            }
            {
              name = "audio-01";
              type = "A";
              ipAddress = "192.168.5.47";
              createPtrRecord = true;
            }
            {
              name = "octoprint";
              type = "A";
              ipAddress = "192.168.5.49";
              createPtrRecord = true;
            }
            {
              name = "kvm";
              type = "A";
              ipAddress = "192.168.5.62";
              createPtrRecord = true;
            }
            {
              name = "imac-01";
              type = "A";
              ipAddress = "192.168.5.125";
              createPtrRecord = true;
            }
            {
              name = "imac-02";
              type = "A";
              ipAddress = "192.168.5.153";
              createPtrRecord = true;
            }
            {
              name = "nas-01-kvm";
              type = "A";
              ipAddress = "192.168.5.143";
              createPtrRecord = true;
            }
            {
              name = "fireplace-led";
              type = "A";
              ipAddress = "192.168.5.192";
              createPtrRecord = true;
            }
            {
              name = "nix-01";
              type = "A";
              ipAddress = "192.168.5.210";
              createPtrRecord = true;
            }
            {
              name = "nix-03";
              type = "A";
              ipAddress = "192.168.5.214";
              createPtrRecord = true;
            }
            {
              name = "nix-02";
              type = "A";
              ipAddress = "192.168.5.212";
              createPtrRecord = true;
            }
            {
              name = "music-01";
              type = "A";
              ipAddress = "192.168.5.219";
              createPtrRecord = true;
            }
            {
              name = "dns-01";
              type = "A";
              ipAddress = "192.168.5.220";
              createPtrRecord = true;
            }

            # VLAN 20 hosts
            {
              name = "homeassistant";
              type = "A";
              ipAddress = "192.168.20.20";
              createPtrRecord = true;
            }
            {
              name = "shelly-codetecter";
              type = "A";
              ipAddress = "192.168.20.83";
              createPtrRecord = true;
            }
            {
              name = "wyze-cam-01";
              type = "A";
              ipAddress = "192.168.20.140";
              createPtrRecord = true;
              aliases = ["cam-01" "frontporch-cam"];
            }
            {
              name = "camera-reolink-outside-north";
              type = "A";
              ipAddress = "192.168.20.129";
              createPtrRecord = true;
              aliases = ["camera-outside-north"];
            }
            {
              name = "shelly-smokedetector";
              type = "A";
              ipAddress = "192.168.20.125";
              createPtrRecord = true;
            }
            {
              name = "frigate-host";
              type = "A";
              ipAddress = "192.168.20.174";
              createPtrRecord = true;
              aliases = ["frigate"];
            }
          ];
        }
      ];
    };
  };

  # Use the systemd-boot EFI boot loader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  networking.hostName = "dns-01";

  # Use systemd-networkd for network configuration
  clubcotton.systemd-network = {
    enable = true;
    mode = "single-nic";
    interfaces = ["eno1"];
    enableVlans = true;
    enableIncusBridge = false;
    nativeVlan = {
      address = "192.168.5.220/24";
      gateway = "192.168.5.1";
      dns = ["192.168.5.220"];
    };
    vlanConfigs = [
      {
        id = 10;
        address = "192.168.10.220/24";
      }
      {
        id = 20;
        address = "192.168.20.220/24";
      }
    ];
  };

  # Pick only one of the below networking options.
  # networking.wireless.enable = true;  # Enables wireless support via wpa_supplicant.
  # networking.networkmanager.enable = true;  # Easiest to use and most distros use this bzy default.

  # Set your time zone.
  time.timeZone = variables.timeZone;

  # Configure network proxy if necessary
  # networking.proxy.default = "http://user:password@proxy:port/";
  # networking.proxy.noProxy = "127.0.0.1,localhost,internal.domain";

  # Select internationalisation properties.
  # i18n.defaultLocale = "en_US.UTF-8";
  # console = {
  #   font = "Lat2-Terminus16";
  #   keyMap = "us";
  #   useXkbConfig = true; # use xkb.options in tty.
  # };

  # Enable the X11 windowing system.
  # services.xserver.enable = true;

  # Configure keymap in X11
  # services.xserver.xkb.layout = "us";
  # services.xserver.xkb.options = "eurosign:e,caps:escape";

  # Enable CUPS to print documents.
  # services.printing.enable = true;

  # Enable sound.
  # sound.enable = true;
  # hardware.pulseaudio.enable = true;

  # Enable touchpad support (enabled default in most desktopManager).
  # services.xserver.libinput.enable = true;

  programs.zsh.enable = variables.zshEnable;

  users.users.root = {
    openssh.authorizedKeys.keys = keys.rootAuthorizedKeys;
  };

  # Define a user account. Don't forget to set a password with ‘passwd’.
  # users.users.alice = {
  #   isNormalUser = true;
  #   extraGroups = [ "wheel" ]; # Enable ‘sudo’ for the user.
  #   packages = with pkgs; [
  #     firefox
  #     tree
  #   ];
  # };

  # List packages installed in system profile. To search, run:
  # $ nix search wget
  # environment.systemPackages = with pkgs; [
  #   vim # Do not forget to add an editor to edit configuration.nix! The Nano editor is also installed by default.
  #   wget
  # ];

  # Some programs need SUID wrappers, can be configured further or are
  # started in user sessions.
  # programs.mtr.enable = true;
  # programs.gnupg.agent = {
  #   enable = true;
  #   enableSSHSupport = true;
  # };

  # List services that you want to enable:

  # Enable the OpenSSH daemon.
  services.openssh.enable = variables.opensshEnable;

  # Open ports in the firewall.
  # networking.firewall.allowedTCPPorts = [ ... ];
  # networking.firewall.allowedUDPPorts = [ ... ];
  # Or disable the firewall altogether.
  networking.firewall.enable = variables.firewallEnable;

  # Copy the NixOS configuration file and link it from the resulting system
  # (/run/current-system/configuration.nix). This is useful in case you
  # accidentally delete configuration.nix.
  # system.copySystemConfiguration = true;

  # This option defines the first version of NixOS you have installed on this particular machine,
  # and is used to maintain compatibility with application data (e.g. databases) created on older NixOS versions.
  #
  # Most users should NEVER change this value after the initial install, for any reason,
  # even if you've upgraded your system to a new NixOS release.
  #
  # This value does NOT affect the Nixpkgs version your packages and OS are pulled from,
  # so changing it will NOT upgrade your system.
  #
  # This value being lower than the current NixOS release does NOT mean your system is
  # out of date, out of support, or vulnerable.
  #
  # Do NOT change this value unless you have manually inspected all the changes it would make to your configuration,
  # and migrated your data accordingly.
  #
  # For more information, see `man configuration.nix` or https://nixos.org/manual/nixos/stable/options#opt-system.stateVersion .
  system.stateVersion = "23.11"; # Did you read the comment?
}
