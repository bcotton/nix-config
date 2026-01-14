{inputs, ...}: let
  inherit (inputs) nixpkgs nixpkgs-unstable agenix disko vscode-server home-manager;

  mkNixosSystem = {
    system,
    hostName,
    usernames,
  }: let
    unstablePkgs = import nixpkgs-unstable {
      inherit system;
      config.allowUnfree = true;
    };
  in
    nixpkgs.lib.nixosSystem {
      inherit system;
      specialArgs = {inherit inputs;};
      modules =
        [
          {
            _module.args = {
              inherit unstablePkgs system inputs;
            };
          }
          ../overlays.nix
          disko.nixosModules.disko
          ../hosts/nixos/${hostName}
          vscode-server.nixosModules.default
          home-manager.nixosModules.home-manager
          {
            networking.hostName = hostName;
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.users = builtins.listToAttrs (map (username: {
                name = username;
                value.imports = [../home/${username}.nix];
              })
              usernames);
            home-manager.extraSpecialArgs = {inherit unstablePkgs;};
          }
          ../hosts/common/common-packages.nix
          ../hosts/common/nixos-common.nix
          agenix.nixosModules.default
        ]
        ++ (map (username: ../users/${username}.nix) usernames);
    };
in {
  flake.nixosConfigurations = {
    nixhost = mkNixosSystem {
      system = "x86_64-linux";
      hostName = "nixhost";
      usernames = ["bcotton"];
    };
    test-vm = mkNixosSystem {
      system = "x86_64-linux";
      hostName = "test-vm";
      usernames = ["bcotton"];
    };
    test-vm-arm = mkNixosSystem {
      system = "aarch64-linux";
      hostName = "test-vm";
      usernames = ["bcotton"];
    };
  };
}
