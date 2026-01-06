{
  inputs,
  self,
  ...
}: {
  flake = let
    inherit (inputs) nixpkgs nixpkgs-unstable home-manager agenix nix-darwin disko tsnsrv vscode-server nixos-generators nix-builder-config;

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
        inherit inputs unstablePkgs hostName;
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
        ];

      # User modules
      userModules = map (username: ../users/${username}.nix) usernames;
    in
      nixpkgs.lib.nixosSystem {
        inherit system;
        specialArgs = {
          inherit self system inputs hostName;
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
              inherit inputs unstablePkgs hostName;
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

    # NixOS configurations
    nixosConfigurations = {
      admin = nixosSystem {
        system = "x86_64-linux";
        hostName = "admin";
        usernames = ["bcotton"];
      };
      condo-01 = nixosSystem {
        system = "x86_64-linux";
        hostName = "condo-01";
        usernames = ["bcotton"];
      };
      natalya-01 = nixosSystem {
        system = "x86_64-linux";
        hostName = "natalya-01";
        usernames = ["bcotton"];
      };
      nas-01 = nixosSystem {
        system = "x86_64-linux";
        hostName = "nas-01";
        usernames = ["bcotton" "tomcotton"];
      };
      nix-01 = nixosSystem {
        system = "x86_64-linux";
        hostName = "nix-01";
        usernames = ["bcotton" "tomcotton"];
      };
      nix-02 = nixosSystem {
        system = "x86_64-linux";
        hostName = "nix-02";
        usernames = ["bcotton" "tomcotton"];
      };
      nix-03 = nixosSystem {
        system = "x86_64-linux";
        hostName = "nix-03";
        usernames = ["bcotton" "tomcotton"];
      };
      nix-04 = nixosSystem {
        system = "x86_64-linux";
        hostName = "nix-04";
        usernames = ["bcotton" "tomcotton"];
      };
      imac-01 = nixosSystem {
        system = "x86_64-linux";
        hostName = "imac-01";
        usernames = ["bcotton" "tomcotton"];
      };
      imac-02 = nixosSystem {
        system = "x86_64-linux";
        hostName = "imac-02";
        usernames = ["bcotton" "tomcotton"];
      };
      dns-01 = nixosSystem {
        system = "x86_64-linux";
        hostName = "dns-01";
        usernames = ["bcotton"];
      };
      octoprint = nixosSystem {
        system = "x86_64-linux";
        hostName = "octoprint";
        usernames = ["bcotton" "tomcotton"];
      };
      frigate-host = nixosSystem {
        system = "x86_64-linux";
        hostName = "frigate-host";
        usernames = ["bcotton"];
      };
    };
  };
}
