{
  inputs = {
    agenix.url = "github:ryantm/agenix";
    nixinate.url = "github:matthewcroughan/nixinate";
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.11";
    nixpkgs-unstable.url = "github:nixos/nixpkgs/nixpkgs-unstable";
    nixpkgs-darwin.url = "github:NixOS/nixpkgs/nixpkgs-24.11-darwin";

    disko.url = "github:nix-community/disko";
    disko.inputs.nixpkgs.follows = "nixpkgs";

    vscode-server.url = "github:nix-community/nixos-vscode-server";
    home-manager.url = "github:nix-community/home-manager/release-24.11";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";

    nix-darwin.url = "github:lnl7/nix-darwin";
    nix-darwin.inputs.nixpkgs.follows = "nixpkgs";

    nixos-shell.url = "github:Mic92/nixos-shell";

    tsnsrv = {
      url = "github:boinkor-net/tsnsrv";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nixos-generators = {
      url = "github:nix-community/nixos-generators";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = inputs @ {
    self,
    agenix,
    nixinate,
    nixpkgs,
    nixpkgs-unstable,
    nixpkgs-darwin,
    nixos-generators,
    nixos-shell,
    home-manager,
    nix-darwin,
    tsnsrv,
    vscode-server,
    disko,
    ...
  }: let
    inputs = {inherit agenix disko nixinate nixos-shell nix-darwin home-manager tsnsrv nixpkgs nixpkgs-unstable;};

    # creates correct package sets for specified arch
    genPkgs = system:
      import nixpkgs {
        inherit system;
        config.allowUnfree = true;
      };
    genDarwinPkgs = system:
      import nixpkgs-darwin {
        inherit system;
        config.allowUnfree = true;
      };

    # creates unstable package set for specified arch
    genUnstablePkgs = system:
      import nixpkgs-unstable {
        inherit system;
        config.allowUnfree = true;
      };

    # creates a nixos system config
    nixosVM = system: hostName: usernames: let
      pkgs = genPkgs system;
      unstablePkgs = genUnstablePkgs system;
    in
      nixos-generators.nixosGenerate
      {
        format = "lxc";
        specialArgs = {inherit self system inputs;};
        modules =
          [
            # adds unstable to be available in top-level evals (like in common-packages)
            {
              _module.args = {
                unstablePkgs = unstablePkgs;
                system = system;
                inputs = inputs;
              };
            }
            ./overlays.nix

            ./hosts/nixos/${hostName} # ip address, host specific stuff
            vscode-server.nixosModules.default
            home-manager.nixosModules.home-manager
            {
              networking.hostName = hostName;
              home-manager.useGlobalPkgs = true;
              home-manager.useUserPackages = true;
              home-manager.users = builtins.listToAttrs (map (username: {
                  name = username;
                  value = {
                    imports = [./home/${username}.nix];
                  };
                })
                usernames);
              home-manager.extraSpecialArgs = {inherit unstablePkgs;};
            }
            ./hosts/common/common-packages.nix
            ./hosts/common/nixos-common.nix
            agenix.nixosModules.default
          ]
          ++ (map (username: ./users/${username}.nix) usernames);
      };

    # creates a nixos system config
    nixosSystem = system: hostName: usernames: let
      pkgs = genPkgs system;
      unstablePkgs = genUnstablePkgs system;
    in
      nixpkgs.lib.nixosSystem
      {
        inherit system;
        specialArgs = {inherit self system inputs;};
        modules =
          [
            # adds unstable to be available in top-level evals (like in common-packages)
            {
              _module.args = {
                unstablePkgs = unstablePkgs;
                system = system;
                inputs = inputs;
              };
            }
            # Nixinate configuration with conditional host setting. There is a potentation that
            # tailscale is down, and the host is not accessible. In that case, we can use the
            # local hostname.
            ({config, ...}: {
              _module.args.nixinate = {
                host =
                  if config.services.tailscale.enable
                  then "${hostName}.lan"
                  else hostName;
                sshUser = "root";
                buildOn = "remote";
                hermetic = false;
              };
            })

            ./overlays.nix
            nixos-generators.nixosModules.all-formats

            disko.nixosModules.disko
            tsnsrv.nixosModules.default
            ./clubcotton
            ./secrets
            ./modules/code-server
            ./modules/tailscale
            ./modules/zfs

            ./hosts/nixos/${hostName} # ip address, host specific stuff
            vscode-server.nixosModules.default
            home-manager.nixosModules.home-manager
            {
              networking.hostName = hostName;
              home-manager.useGlobalPkgs = true;
              home-manager.useUserPackages = true;
              home-manager.users = builtins.listToAttrs (map (username: {
                  name = username;
                  value = {
                    imports = [./home/${username}.nix];
                  };
                })
                usernames);
              home-manager.extraSpecialArgs = {inherit unstablePkgs;};
            }
            ./hosts/common/common-packages.nix
            ./hosts/common/nixos-common.nix
            agenix.nixosModules.default
          ]
          ++ (map (username: ./users/${username}.nix) usernames);
      };

    # creates a nixos system config
    nixosMinimalSystem = system: hostName: usernames: let
      pkgs = genPkgs system;
      nixinateConfig = {
        host = hostName;
        sshUser = "root";
        buildOn = "remote";
        hermetic = false;
      };
      unstablePkgs = genUnstablePkgs system;
    in
      nixpkgs.lib.nixosSystem
      {
        inherit system;
        specialArgs = {inherit self system inputs;};
        modules =
          [
            # adds unstable to be available in top-level evals (like in common-packages)
            {
              _module.args = {
                unstablePkgs = unstablePkgs;
                system = system;
                inputs = inputs;
                nixinate = nixinateConfig;
              };
            }

            disko.nixosModules.disko
            ./modules/zfs
            ./hosts/nixos/${hostName} # ip address, host specific stuff
          ]
          ++ (map (username: ./users/${username}.nix) usernames);
      };

    # creates a macos system config
    darwinSystem = system: hostName: username: let
      pkgs = genDarwinPkgs system;
      unstablePkgs = genUnstablePkgs system;
    in
      nix-darwin.lib.darwinSystem
      {
        inherit system inputs;

        modules = [
          # adds unstable to be available in top-level evals (like in common-packages)
          {
            _module.args = {
              unstablePkgs = genUnstablePkgs system;
              system = system;
            };
          }

          ./overlays.nix
          ./hosts/darwin/${hostName} # ip address, host specific stuff
          home-manager.darwinModules.home-manager
          {
            networking.hostName = hostName;
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.users.${username} = {
              imports = [./home/${username}.nix];
            };
            home-manager.extraSpecialArgs = {inherit unstablePkgs;};
          }
          ./hosts/common/common-packages.nix
          ./hosts/common/darwin-common.nix
          agenix.nixosModules.default
        ];
      };
  in {
    checks.x86_64-linux = let
      system = "x86_64-linux";
      unstablePkgs = genUnstablePkgs system;
    in {
      # to run the checks, use the following pattern of commands:
      # nix build '.#checks.x86_64-linux.postgresql-integration'
      # nix run '.#checks.x86_64-linux.postgresql-integration.driverInteractive'
      postgresql = nixpkgs.legacyPackages.${system}.nixosTest (import ./modules/postgresql/test.nix {inherit nixpkgs;});
      webdav = nixpkgs.legacyPackages.${system}.nixosTest (import ./clubcotton/services/webdav/test.nix {inherit nixpkgs;});
      kavita = nixpkgs.legacyPackages.${system}.nixosTest (import ./clubcotton/services/kavita/test.nix {inherit nixpkgs;});
      postgresql-integration = nixpkgs.legacyPackages.${system}.nixosTest (import ./tests/postgresql-integration.nix {inherit nixpkgs unstablePkgs inputs;});
      zfs-single-root = let
        system = "x86_64-linux";
        pkgs = genPkgs system;
      in
        import ./modules/zfs/zfs-single-root-test.nix {
          inherit nixpkgs pkgs disko;
        };
      zfs-raidz1 = let
        system = "x86_64-linux";
        pkgs = genPkgs system;
      in
        import ./modules/zfs/zfs-raidz1-test.nix {
          inherit nixpkgs pkgs disko;
        };
      zfs-mirrored-root = let
        system = "x86_64-linux";
        pkgs = genPkgs system;
      in
        import ./modules/zfs/zfs-mirrored-root-test.nix {
          inherit nixpkgs pkgs disko;
        };
    };

    apps.nixinate = (nixinate.nixinate.x86_64-linux self).nixinate;

    formatter.x86_64-linux = nixpkgs.legacyPackages.x86_64-linux.alejandra;
    formatter.aarch64-darwin = nixpkgs.legacyPackages.aarch64-darwin.alejandra;
    formatter.x86_64-darwin = nixpkgs.legacyPackages.x86_64-darwin.alejandra;

    darwinConfigurations = {
      bobs-laptop = darwinSystem "aarch64-darwin" "bobs-laptop" "bcotton";
      toms-MBP = darwinSystem "x86_64-darwin" "toms-MBP" "tomcotton";
      toms-mini = darwinSystem "aarch64-darwin" "toms-mini" "tomcotton";
      bobs-imac = darwinSystem "x86_64-darwin" "bobs-imac" "bcotton";
    };

    nixosConfigurations = {
      admin = nixosSystem "x86_64-linux" "admin" ["bcotton"];
      nas-01 = nixosSystem "x86_64-linux" "nas-01" ["bcotton" "tomcotton"];
      nix-01 = nixosSystem "x86_64-linux" "nix-01" ["bcotton" "tomcotton"];
      nix-02 = nixosSystem "x86_64-linux" "nix-02" ["bcotton" "tomcotton"];
      nix-03 = nixosSystem "x86_64-linux" "nix-03" ["bcotton" "tomcotton"];
      nix-04 = nixosSystem "x86_64-linux" "nix-04" ["bcotton" "tomcotton"];
      dns-01 = nixosSystem "x86_64-linux" "dns-01" ["bcotton"];
      octoprint = nixosSystem "x86_64-linux" "octoprint" ["bcotton" "tomcotton"];
      frigate-host = nixosSystem "x86_64-linux" "frigate-host" ["bcotton"];
      # nixos = nixosSystem "x86_64-linux" "nixos" ["bcotton" "tomcotton"];
      k3s-01 = nixosSystem "x86_64-linux" "k3s-01" ["bcotton"];
      k3s-02 = nixosSystem "x86_64-linux" "k3s-02" ["bcotton"];
      k3s-03 = nixosSystem "x86_64-linux" "k3s-03" ["bcotton"];
      # nixbox = nixosSystem "x86_64-linux" "nixbox" ["bcotton" "tomcotton"];
      # incus = nixosMinimalSystem "x86_64-linux" "incus" ["bcotton"];
      # nas-test = nixosMinimalSystem "x86_64-linux" "nas-test" ["bcotton"];
    };
  };
}
