{
  inputs,
  self,
  ...
}: {
  flake = let
    inherit (inputs) nixpkgs nixpkgs-unstable home-manager agenix nix-darwin disko tsnsrv vscode-server nixos-generators nix-builder-config musnix;

    # Package set generators
    genPkgs = system:
      import nixpkgs {
        inherit system;
        config.allowUnfree = true;
      };

    genUnstablePkgs = system:
      import nixpkgs-unstable {
        inherit system;
        config.allowUnfree = true;
      };

    # Common module builders
    mkModuleArgs = unstablePkgs: system: {
      _module.args = {
        inherit unstablePkgs;
        localPackages = self.legacyPackages.${system}.localPackages;
      };
    };

    mkHomeManagerConfig = unstablePkgs: system: hostName: usernames: {
      networking.hostName = hostName;
      home-manager.useGlobalPkgs = true;
      home-manager.useUserPackages = true;
      home-manager.users = builtins.listToAttrs (
        map (username: {
          name = username;
          value.imports = [
            ../home/${username}.nix
            inputs.workmux.homeManagerModules.default
          ];
        })
        usernames
      );
      home-manager.extraSpecialArgs = {
        inherit inputs unstablePkgs hostName nixosHosts;
        localPackages = self.legacyPackages.${system}.localPackages;
        workmuxPackage = inputs.workmux.packages.${system}.default;
      };
    };

    # External modules used across NixOS systems
    externalNixOSModules = [
      inputs.disko.nixosModules.disko
      inputs.tsnsrv.nixosModules.default
      inputs.vscode-server.nixosModules.default
      inputs.home-manager.nixosModules.home-manager
      inputs.agenix.nixosModules.default
      inputs.musnix.nixosModules.musnix
    ];

    # Internal modules
    internalModules = [
      ../clubcotton
      ../secrets
      nix-builder-config.nixosModules.client
    ];

    # Service modules for full NixOS systems
    serviceModules = [
      ../modules/code-server
      ../modules/postgresql
      ../modules/tailscale
      ../modules/zfs
    ];

    # NixOS host specifications - single source of truth for all NixOS hosts
    # Adding a host here automatically includes it in nixosConfigurations, SSH RemoteForward,
    # and the homepage dashboard (if ip is specified)
    #
    # Homepage/Glances fields (optional):
    #   ip          - IP address for Glances monitoring (enables Glances and adds to homepage)
    #   displayName - Name shown on homepage (defaults to hostname)
    #   glancesPort - Port for Glances (defaults to 61208)
    #   icon        - Icon for homepage (defaults to "mdi-server")
    nixosHostSpecs = {
      admin = {
        system = "x86_64-linux";
        usernames = ["bcotton"];
        ip = "192.168.5.98";
        displayName = "Admin";
      };
      condo-01 = {
        system = "x86_64-linux";
        usernames = ["bcotton"];
        # No IP - different network, not on homepage
      };
      natalya-01 = {
        system = "x86_64-linux";
        usernames = ["bcotton"];
        # No IP - different network, not on homepage
      };
      nas-01 = {
        system = "x86_64-linux";
        usernames = ["bcotton" "tomcotton"];
        ip = "192.168.5.42";
        displayName = "NAS-01";
      };
      nix-01 = {
        system = "x86_64-linux";
        usernames = ["bcotton" "tomcotton" "larry"];
        ip = "192.168.5.210";
        displayName = "Nix-01";
      };
      nix-02 = {
        system = "x86_64-linux";
        usernames = ["bcotton" "tomcotton" "larry"];
        ip = "192.168.5.212";
        displayName = "Nix-02";
      };
      nix-03 = {
        system = "x86_64-linux";
        usernames = ["bcotton" "tomcotton" "larry"];
        ip = "192.168.5.214";
        displayName = "Nix-03";
      };
      nix-04 = {
        system = "x86_64-linux";
        usernames = ["bcotton" "tomcotton"];
        ip = "192.168.5.54";
        displayName = "Nix-04";
      };
      imac-01 = {
        system = "x86_64-linux";
        usernames = ["bcotton" "tomcotton"];
        ip = "192.168.5.125";
        displayName = "iMac-01";
      };
      imac-02 = {
        system = "x86_64-linux";
        usernames = ["bcotton" "tomcotton"];
        ip = "192.168.5.153";
        displayName = "iMac-02";
      };
      dns-01 = {
        system = "x86_64-linux";
        usernames = ["bcotton"];
        ip = "192.168.5.220";
        displayName = "DNS-01";
      };
      octoprint = {
        system = "x86_64-linux";
        usernames = ["bcotton" "tomcotton"];
        ip = "192.168.5.49";
        displayName = "OctoPrint";
      };
      frigate-host = {
        system = "x86_64-linux";
        usernames = ["bcotton"];
        ip = "192.168.20.174";
        displayName = "Frigate";
      };
      nixbook-test = {
        system = "x86_64-linux";
        usernames = ["tomcotton"];
        # No IP - laptop with DHCP, not on homepage
      };
    };

    # Derive host list from specs - used for SSH RemoteForward configuration
    nixosHosts = builtins.attrNames nixosHostSpecs;

    # List of clubcotton service names to show on homepage
    # Homepage metadata is read from each service's homepage.* options
    # Adding a service here just requires it to have homepage.* options defined
    homepageServiceList = [
      # Arr Suite
      "radarr"
      "sonarr"
      "lidarr"
      "prowlarr"
      "jellyseerr"
      # Media
      "jellyfin"
      "navidrome"
      "immich"
      "calibre-web"
      # Downloads
      "sabnzbd"
      "pinchflat"
      # Content
      "paperless"
      "freshrss"
      "wallabag"
      "filebrowser"
      # Infrastructure
      "forgejo"
      "atuin"
      "open-webui"
      "harmonia"
    ];

    # Services without standard clubcotton modules (need manual config)
    # Includes: monitoring services, multi-instance services
    homepageManualServices = {
      # Monitoring (standard nixpkgs services, not clubcotton)
      grafana = {
        name = "Grafana";
        category = "Monitoring";
        icon = "grafana.svg";
        description = "Metrics dashboards";
        href = "http://admin:3000";
      };
      prometheus = {
        name = "Prometheus";
        category = "Monitoring";
        icon = "prometheus.svg";
        description = "Metrics collection";
        href = "http://admin:9001";
      };
      # Multi-instance services (readarr uses instances, not standard options)
      readarr-epub = {
        name = "Readarr (Books)";
        category = "Arr";
        icon = "readarr.svg";
        description = "E-book collection manager";
        tailnetHostname = "readarr-epub";
      };
      readarr-audio = {
        name = "Readarr (Audio)";
        category = "Arr";
        icon = "readarr.svg";
        description = "Audiobook collection manager";
        tailnetHostname = "readarr-audio";
      };
    };

    # NixOS system builder (consolidated from nixosSystem and nixosMinimalSystem)
    nixosSystem = {
      system,
      hostName,
      usernames,
      minimal ? false, # Toggle for minimal vs full
    }: let
      pkgs = genPkgs system;
      unstablePkgs = genUnstablePkgs system;

      # Common modules for all NixOS systems
      commonModules =
        [
          (mkModuleArgs unstablePkgs system)
          ../overlays.nix
        ]
        ++ externalNixOSModules
        ++ internalModules
        ++ [
          # Enable nix cache client on all NixOS systems
          # Settings come from nix-builder-config flake defaults
          {services.nix-builder.client.enable = true;}
          ../hosts/nixos/${hostName}
          (mkHomeManagerConfig unstablePkgs system hostName usernames)
        ];

      # Additional modules for full (non-minimal) systems
      fullModules =
        serviceModules
        ++ [
          ../hosts/common/common-packages.nix
          ../hosts/common/nixos-common.nix
          # Enable tailscale from variables
          ({hostName, ...}: let
            commonLib = import ../hosts/common/lib.nix;
            variables = commonLib.getHostVariables hostName;
          in {
            services.clubcotton.tailscale.enable = variables.tailscaleEnable;
          })
          # Auto-enable Glances on hosts with an IP in nixosHostSpecs
          ({hostName, ...}: let
            hostSpec = nixosHostSpecs.${hostName} or {};
            hasIp = hostSpec.ip or null != null;
          in {
            services.glances.enable = hasIp;
          })
        ];

      # User modules
      userModules = [../users/groups.nix] ++ map (username: ../users/${username}.nix) usernames;
    in
      nixpkgs.lib.nixosSystem {
        inherit system;
        specialArgs = {
          inherit self system inputs hostName nixosHostSpecs homepageServiceList homepageManualServices;
        };
        modules =
          commonModules
          ++ (
            if minimal
            then []
            else fullModules
          )
          ++ userModules;
      };

    # Darwin system builder
    darwinSystem = {
      system,
      hostName,
      username,
    }: let
      pkgs = genPkgs system;
      unstablePkgs = genUnstablePkgs system;
    in
      nix-darwin.lib.darwinSystem {
        inherit system;
        specialArgs = {
          inherit self system inputs hostName;
        };
        modules = [
          (mkModuleArgs unstablePkgs system)
          ../overlays.nix
          inputs.home-manager.darwinModules.home-manager
          nix-builder-config.darwinModules.client
          ../hosts/darwin/${hostName}
          {
            networking.hostName = hostName;

            # Enable nix cache client on all Darwin systems
            # Settings come from nix-builder-config flake defaults
            services.nix-builder.client.enable = true;

            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.users.${username}.imports = [
              ../home/${username}.nix
              inputs.workmux.homeManagerModules.default
            ];
            home-manager.extraSpecialArgs = {
              inherit inputs unstablePkgs hostName nixosHosts;
              localPackages = self.legacyPackages.${system}.localPackages;
              workmuxPackage = inputs.workmux.packages.${system}.default;
            };
          }
          ../hosts/common/common-packages.nix
          ../hosts/common/darwin-common.nix
          ../users/${username}.nix
        ];
      };
  in {
    # Darwin configurations
    darwinConfigurations = {
      bobs-laptop = darwinSystem {
        system = "aarch64-darwin";
        hostName = "bobs-laptop";
        username = "bcotton";
      };
      toms-MBP = darwinSystem {
        system = "x86_64-darwin";
        hostName = "toms-MBP";
        username = "tomcotton";
      };
      toms-mini = darwinSystem {
        system = "aarch64-darwin";
        hostName = "toms-mini";
        username = "tomcotton";
      };
      bobs-imac = darwinSystem {
        system = "x86_64-darwin";
        hostName = "bobs-imac";
        username = "bcotton";
      };
    };

    # NixOS configurations - generated from nixosHostSpecs
    nixosConfigurations =
      builtins.mapAttrs (
        hostName: spec:
          nixosSystem {
            inherit hostName;
            inherit (spec) system usernames;
          }
      )
      nixosHostSpecs;
  };
}
