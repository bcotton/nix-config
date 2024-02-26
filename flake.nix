{
  inputs = {
    agenix.url = "github:ryantm/agenix";
    nixinate.url = "github:matthewcroughan/nixinate";
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-23.11-darwin";
    nixpkgs-unstable.url = "github:nixos/nixpkgs/nixpkgs-unstable";
    nixpkgs-darwin.url = "github:NixOS/nixpkgs/nixpkgs-23.11-darwin";

    disko.url = "github:nix-community/disko";
    disko.inputs.nixpkgs.follows = "nixpkgs";

    vscode-server.url = "github:bcotton/nixos-vscode-server/support-for-new-dir-structure-of-vscode-server";

    home-manager.url = "github:nix-community/home-manager/release-23.11";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";

    nix-darwin.url = "github:lnl7/nix-darwin";
    nix-darwin.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = inputs @ {
    self,
    agenix,
    nixinate,
    nixpkgs,
    nixpkgs-unstable,
    nixpkgs-darwin,
    home-manager,
    nix-darwin,
    vscode-server,
    disko,
    ...
  }: let
    inputs = {inherit agenix nixinate nix-darwin home-manager nixpkgs nixpkgs-unstable;};
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

    # creates a nixos system config
    nixosSystem = system: hostName: username: let
      pkgs = genPkgs system;
      nixinateConfig = {
        host = hostName;
        sshUser = "root";
        buildOn = "remote";
      };
    in
      nixpkgs.lib.nixosSystem
      {
        inherit system;
        specialArgs = {inherit self system inputs;};
        modules = [
          # adds unstable to be available in top-level evals (like in common-packages)
          {
            _module.args = {
              unstablePkgs = inputs.nixpkgs-unstable.legacyPackages.${system};
              system = system;
              inputs = inputs;
              nixinate = nixinateConfig;
            };
          }

          # To repl the flake
          # > nix repl
          # > :lf .
          # > e.g. admin.[tab]
          # add the following inline module definition
          #   here, all parameters of modules are passed to overlays
          # (args: { nixpkgs.overlays = import ./overlays args; })
          ## or
          ./overlays.nix

          disko.nixosModules.disko
          ./hosts/nixos/${hostName} # ip address, host specific stuff
          vscode-server.nixosModules.default
          home-manager.nixosModules.home-manager
          {
            networking.hostName = hostName;
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.users.${username} = {imports = [./home/${username}.nix];};
          }
          ./hosts/common/common-packages.nix
          ./hosts/common/nixos-common.nix
          agenix.nixosModules.default
        ];
      };

    # creates a macos system config
    darwinSystem = system: hostName: username: let
      pkgs = genDarwinPkgs system;
    in
      nix-darwin.lib.darwinSystem
      {
        inherit system inputs;

        modules = [
          # adds unstable to be available in top-level evals (like in common-packages)
          {
            _module.args = {
              unstablePkgs = inputs.nixpkgs-unstable.legacyPackages.${system};
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
            home-manager.users.${username} = {imports = [./home/${username}.nix];};
          }
          ./hosts/common/common-packages.nix
          ./hosts/common/darwin-common.nix
          agenix.nixosModules.default
        ];
      };
  in {
    apps = nixinate.nixinate.x86_64-linux self;
    formatter.x86_64-linux = nixpkgs.legacyPackages.x86_64-linux.alejandra;
    formatter.aarch64-darwin = nixpkgs.legacyPackages.aarch64-darwin.alejandra;

    darwinConfigurations = {
      bobs-laptop = darwinSystem "aarch64-darwin" "bobs-laptop" "bcotton";
    };

    nixosConfigurations = {
      admin = nixosSystem "x86_64-linux" "admin" "bcotton";
      nix-01 = nixosSystem "x86_64-linux" "nix-01" "bcotton";
      nix-02 = nixosSystem "x86_64-linux" "nix-02" "bcotton";
      nix-03 = nixosSystem "x86_64-linux" "nix-03" "bcotton";
      dns-01 = nixosSystem "x86_64-linux" "dns-01" "bcotton";
    };
  };
}
