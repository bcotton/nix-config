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

    # Homepage service specifications - single source of truth for dashboard services
    # Adding a service here automatically includes it on the homepage dashboard
    # Services with tailnetHostname get URLs constructed from tailnetDomain
    # Services with href use the explicit URL (for local/non-tailnet services)
    #
    # Fields:
    #   name            - Display name on homepage
    #   description     - Service description
    #   icon            - Icon file (e.g., "radarr.svg")
    #   category        - Category for grouping (Arr, Media, Downloads, Content, Infrastructure, Monitoring)
    #   tailnetHostname - Hostname on tailnet (constructs https://<hostname>.<tailnetDomain>)
    #   href            - Explicit URL (overrides tailnetHostname, use for local services)
    homepageServices = {
      # Arr Suite
      radarr = {
        name = "Radarr";
        category = "Arr";
        icon = "radarr.svg";
        description = "Movie collection manager";
        tailnetHostname = "radarr";
      };
      sonarr = {
        name = "Sonarr";
        category = "Arr";
        icon = "sonarr.svg";
        description = "TV series collection manager";
        tailnetHostname = "sonarr";
      };
      lidarr = {
        name = "Lidarr";
        category = "Arr";
        icon = "lidarr.svg";
        description = "Music collection manager";
        tailnetHostname = "lidarr";
      };
      prowlarr = {
        name = "Prowlarr";
        category = "Arr";
        icon = "prowlarr.svg";
        description = "Indexer manager for *arr apps";
        tailnetHostname = "prowlarr";
      };
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
      jellyseerr = {
        name = "Jellyseerr";
        category = "Arr";
        icon = "jellyseerr.svg";
        description = "Media request management";
        tailnetHostname = "jellyseerr";
      };

      # Media
      jellyfin = {
        name = "Jellyfin";
        category = "Media";
        icon = "jellyfin.svg";
        description = "Media streaming server";
        tailnetHostname = "jellyfin";
      };
      navidrome = {
        name = "Navidrome";
        category = "Media";
        icon = "navidrome.svg";
        description = "Music streaming server";
        tailnetHostname = "navidrome";
      };
      immich = {
        name = "Immich";
        category = "Media";
        icon = "immich.svg";
        description = "Photo and video backup";
        tailnetHostname = "immich";
      };
      calibre-web = {
        name = "Calibre-Web";
        category = "Media";
        icon = "calibre-web.svg";
        description = "E-book library browser";
        tailnetHostname = "calibre-web";
      };

      # Downloads
      sabnzbd = {
        name = "SABnzbd";
        category = "Downloads";
        icon = "sabnzbd.svg";
        description = "Usenet download client";
        tailnetHostname = "sabnzbd";
      };
      pinchflat = {
        name = "Pinchflat";
        category = "Downloads";
        icon = "pinchflat.svg";
        description = "YouTube media archiver";
        tailnetHostname = "pinchflat";
      };

      # Content
      paperless = {
        name = "Paperless-ngx";
        category = "Content";
        icon = "paperless-ngx.svg";
        description = "Document management system";
        tailnetHostname = "paperless";
      };
      freshrss = {
        name = "FreshRSS";
        category = "Content";
        icon = "freshrss.svg";
        description = "RSS feed aggregator";
        tailnetHostname = "freshrss";
      };
      wallabag = {
        name = "Wallabag";
        category = "Content";
        icon = "wallabag.svg";
        description = "Read-it-later service";
        tailnetHostname = "wallabag";
      };
      filebrowser = {
        name = "File Browser";
        category = "Content";
        icon = "filebrowser.svg";
        description = "Web-based file manager";
        tailnetHostname = "filebrowser";
      };

      # Infrastructure
      forgejo = {
        name = "Forgejo";
        category = "Infrastructure";
        icon = "forgejo.svg";
        description = "Self-hosted Git forge";
        tailnetHostname = "forgejo";
      };
      atuin = {
        name = "Atuin";
        category = "Infrastructure";
        icon = "atuin.png";
        description = "Shell history sync server";
        tailnetHostname = "atuin";
      };
      open-webui = {
        name = "Open WebUI";
        category = "Infrastructure";
        icon = "open-webui.svg";
        description = "LLM chat interface";
        tailnetHostname = "llm";
      };
      harmonia = {
        name = "Harmonia";
        category = "Infrastructure";
        icon = "nix.svg";
        description = "Nix binary cache server";
        tailnetHostname = "nix-cache";
      };

      # Monitoring (local to admin host)
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
          inherit self system inputs hostName nixosHostSpecs homepageServices;
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
