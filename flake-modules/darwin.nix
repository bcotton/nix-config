{inputs, ...}: let
  inherit (inputs) nixpkgs-unstable nix-darwin agenix home-manager;

  mkDarwinSystem = {
    system,
    hostName,
    username,
  }: let
    unstablePkgs = import nixpkgs-unstable {
      inherit system;
      config.allowUnfree = true;
    };
  in
    nix-darwin.lib.darwinSystem {
      inherit system;
      specialArgs = {inherit inputs;};
      modules = [
        {
          _module.args = {
            inherit unstablePkgs system;
          };
        }
        ../overlays.nix
        ../hosts/darwin/${hostName}
        home-manager.darwinModules.home-manager
        ({lib, ...}: {
          networking.hostName = hostName;
          home-manager.useGlobalPkgs = true;
          home-manager.useUserPackages = true;
          home-manager.users.${username} = {
            imports = [../home/${username}.nix];
            home.homeDirectory = lib.mkForce "/Users/${username}";
          };
          home-manager.extraSpecialArgs = {inherit unstablePkgs;};
        })
        ../hosts/common/common-packages.nix
        ../hosts/common/darwin-common.nix
        agenix.nixosModules.default
      ];
    };
in {
  flake.darwinConfigurations = {
    bobs-laptop = mkDarwinSystem {
      system = "aarch64-darwin";
      hostName = "bobs-laptop";
      username = "bcotton";
    };
  };
}
