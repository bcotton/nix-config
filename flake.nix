{
  inputs = {
    agenix.url = "github:ryantm/agenix";
    nixinate.url = "github:matthewcroughan/nixinate";

    nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.11";
    nixpkgs-unstable.url = "github:nixos/nixpkgs/nixpkgs-unstable";

    nix-darwin = {
      url = "github:LnL7/nix-darwin/nix-darwin-24.11";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    disko.url = "github:nix-community/disko";
    disko.inputs.nixpkgs.follows = "nixpkgs";

    vscode-server.url = "github:zeyugao/nixos-vscode-server";
    home-manager.url = "github:nix-community/home-manager/release-24.11";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = inputs @ {
    self,
    agenix,
    nixinate,
    nixpkgs,
    nixpkgs-unstable,
    nix-darwin,
    home-manager,
    vscode-server,
    disko,
    ...
  }: let
    localPackages = system: let
      pkgs = import nixpkgs {
        inherit system;
        config.allowUnfree = true;
      };
    in {};

    inputs = {inherit agenix disko nixinate nix-darwin home-manager nixpkgs nixpkgs-unstable;};

    # creates correct package sets for specified arch
    genPkgs = system:
      import nixpkgs {
        inherit system;
        config.allowUnfree = true;
      };
    genDarwinPkgs = system:
      import nix-darwin {
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
    nixosSystem = system: hostName: usernames: let
      pkgs = genPkgs system;
      unstablePkgs = genUnstablePkgs system;
    in
      nixpkgs.lib.nixosSystem
      {
        inherit system;
        specialArgs = {inherit self system inputs localPackages;};
        modules =
          [
            # adds unstable to be available in top-level evals (like in common-packages)
            {
              _module.args = {
                unstablePkgs = unstablePkgs;
                system = system;
                inputs = inputs;
                localPackages = localPackages;
              };
            }
            ({config, ...}: {
              _module.args.nixinate = {
                host = hostName;
                sshUser = "root";
                buildOn = "remote";
                hermetic = false;
              };
            })

            ./overlays.nix

            disko.nixosModules.disko

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
    apps.nixinate = (nixinate.nixinate.x86_64-linux self).nixinate;

    packages.x86_64-linux = let
      pkgs = import nixpkgs {
        system = "x86_64-linux";
        config.allowUnfree = true;
      };
    in {
      test-vm = self.nixosConfigurations.test-vm.config.system.build.vm;
    };

    formatter.x86_64-linux = nixpkgs.legacyPackages.x86_64-linux.alejandra;
    formatter.aarch64-darwin = nixpkgs.legacyPackages.aarch64-darwin.alejandra;
    formatter.x86_64-darwin = nixpkgs.legacyPackages.x86_64-darwin.alejandra;

    darwinConfigurations = {
      bobs-laptop = darwinSystem "aarch64-darwin" "bobs-laptop" "bcotton";
    };

    nixosConfigurations = {
      nixhost = nixosSystem "x86_64-linux" "nixhost" ["bcotton"];
      test-vm = nixosSystem "x86_64-linux" "test-vm" ["bcotton"];
    };
  };
}
