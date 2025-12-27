{
  inputs,
  self,
  ...
}: {
  flake = let
    inherit (inputs) nixpkgs nixpkgs-unstable home-manager agenix nix-darwin disko tsnsrv vscode-server nixinate nixos-generators;

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

    genDarwinPkgs = system:
      import nixpkgs {
        inherit system;
        config.allowUnfree = true;
      };

    # NixOS system builder
    nixosSystem = system: hostName: usernames: let
      pkgs = genPkgs system;
      unstablePkgs = genUnstablePkgs system;
    in
      nixpkgs.lib.nixosSystem {
        inherit system;
        specialArgs = {
          inherit self system inputs hostName;
        };
        modules =
          [
            # Make packages available to modules
            ({config, ...}: {
              _module.args = {
                inherit unstablePkgs;
                localPackages = self.legacyPackages.${system}.localPackages;
              };
            })

            # Nixinate configuration
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

            # Import overlays
            ../overlays.nix

            # External modules
            inputs.disko.nixosModules.disko
            inputs.tsnsrv.nixosModules.default
            inputs.vscode-server.nixosModules.default
            inputs.home-manager.nixosModules.home-manager
            inputs.agenix.nixosModules.default

            # Internal modules
            ../clubcotton
            ../secrets
            ../modules/code-server
            ../modules/postgresql
            ../modules/tailscale
            ../modules/zfs

            # Host-specific configuration
            ../hosts/nixos/${hostName}

            # Home Manager configuration
            {
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
                inherit unstablePkgs hostName;
                localPackages = self.legacyPackages.${system}.localPackages;
                workmuxPackage = inputs.workmux.packages.${system}.default;
              };
            }

            # Common configurations
            ../hosts/common/common-packages.nix
            ../hosts/common/nixos-common.nix
          ]
          # User modules
          ++ (map (username: ../users/${username}.nix) usernames);
      };

    # Minimal NixOS system builder
    nixosMinimalSystem = system: hostName: usernames: let
      pkgs = genPkgs system;
      unstablePkgs = genUnstablePkgs system;
    in
      nixpkgs.lib.nixosSystem {
        inherit system;
        specialArgs = {
          inherit self system inputs hostName;
        };
        modules =
          [
            ({config, ...}: {
              _module.args = {
                inherit unstablePkgs;
                localPackages = self.legacyPackages.${system}.localPackages;
              };
            })
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
            ../overlays.nix
            inputs.disko.nixosModules.disko
            inputs.tsnsrv.nixosModules.default
            inputs.vscode-server.nixosModules.default
            inputs.home-manager.nixosModules.home-manager
            inputs.agenix.nixosModules.default
            ../clubcotton
            ../secrets
            ../hosts/nixos/${hostName}
            {
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
                inherit unstablePkgs hostName;
                localPackages = self.legacyPackages.${system}.localPackages;
                workmuxPackage = inputs.workmux.packages.${system}.default;
              };
            }
          ]
          ++ (map (username: ../users/${username}.nix) usernames);
      };

    # Darwin system builder
    darwinSystem = system: hostName: username: let
      pkgs = genDarwinPkgs system;
      unstablePkgs = genUnstablePkgs system;
    in
      nix-darwin.lib.darwinSystem {
        inherit system;
        specialArgs = {
          inherit self system inputs hostName;
        };
        modules = [
          ({config, ...}: {
            _module.args = {
              inherit unstablePkgs;
              localPackages = self.legacyPackages.${system}.localPackages;
            };
          })
          ../overlays.nix
          inputs.home-manager.darwinModules.home-manager
          ../hosts/darwin/${hostName}
          {
            networking.hostName = hostName;
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.users.${username}.imports = [
              ../home/${username}.nix
              inputs.workmux.homeManagerModules.default
            ];
            home-manager.extraSpecialArgs = {
              inherit unstablePkgs hostName;
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
      bobs-laptop = darwinSystem "aarch64-darwin" "bobs-laptop" "bcotton";
      toms-MBP = darwinSystem "x86_64-darwin" "toms-MBP" "tomcotton";
      toms-mini = darwinSystem "aarch64-darwin" "toms-mini" "tomcotton";
      bobs-imac = darwinSystem "x86_64-darwin" "bobs-imac" "bcotton";
    };

    # NixOS configurations
    nixosConfigurations = {
      admin = nixosSystem "x86_64-linux" "admin" ["bcotton"];
      condo-01 = nixosSystem "x86_64-linux" "condo-01" ["bcotton"];
      natalya-01 = nixosSystem "x86_64-linux" "natalya-01" ["bcotton"];
      nas-01 = nixosSystem "x86_64-linux" "nas-01" ["bcotton" "tomcotton"];
      nix-01 = nixosSystem "x86_64-linux" "nix-01" ["bcotton" "tomcotton"];
      nix-02 = nixosSystem "x86_64-linux" "nix-02" ["bcotton" "tomcotton"];
      nix-03 = nixosSystem "x86_64-linux" "nix-03" ["bcotton" "tomcotton"];
      nix-04 = nixosSystem "x86_64-linux" "nix-04" ["bcotton" "tomcotton"];
      imac-01 = nixosSystem "x86_64-linux" "imac-01" ["bcotton" "tomcotton"];
      imac-02 = nixosSystem "x86_64-linux" "imac-02" ["bcotton" "tomcotton"];
      dns-01 = nixosSystem "x86_64-linux" "dns-01" ["bcotton"];
      octoprint = nixosSystem "x86_64-linux" "octoprint" ["bcotton" "tomcotton"];
      frigate-host = nixosSystem "x86_64-linux" "frigate-host" ["bcotton"];
      nixos-utm = nixosSystem "aarch64-linux" "nixos-utm" ["bcotton"];
    };
  };
}
