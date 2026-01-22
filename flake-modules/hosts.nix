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
    # Adding a host here automatically includes it in nixosConfigurations and SSH RemoteForward
    nixosHostSpecs = {
      admin = {
        system = "x86_64-linux";
        usernames = ["bcotton"];
      };
      condo-01 = {
        system = "x86_64-linux";
        usernames = ["bcotton"];
      };
      natalya-01 = {
        system = "x86_64-linux";
        usernames = ["bcotton"];
      };
      nas-01 = {
        system = "x86_64-linux";
        usernames = ["bcotton" "tomcotton"];
      };
      nix-01 = {
        system = "x86_64-linux";
        usernames = ["bcotton" "tomcotton"];
      };
      nix-02 = {
        system = "x86_64-linux";
        usernames = ["bcotton" "tomcotton"];
      };
      nix-03 = {
        system = "x86_64-linux";
        usernames = ["bcotton" "tomcotton"];
      };
      nix-04 = {
        system = "x86_64-linux";
        usernames = ["bcotton" "tomcotton"];
      };
      imac-01 = {
        system = "x86_64-linux";
        usernames = ["bcotton" "tomcotton"];
      };
      imac-02 = {
        system = "x86_64-linux";
        usernames = ["bcotton" "tomcotton"];
      };
      dns-01 = {
        system = "x86_64-linux";
        usernames = ["bcotton"];
      };
      octoprint = {
        system = "x86_64-linux";
        usernames = ["bcotton" "tomcotton"];
      };
      frigate-host = {
        system = "x86_64-linux";
        usernames = ["bcotton"];
      };
      nixbook-test = {
        system = "x86_64-linux";
        usernames = ["tomcotton"];
      };
    };

    # Derive host list from specs - used for SSH RemoteForward configuration
    nixosHosts = builtins.attrNames nixosHostSpecs;

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
