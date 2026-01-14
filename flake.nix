{
  inputs = {
    flake-parts.url = "github:hercules-ci/flake-parts";

    agenix.url = "github:ryantm/agenix";
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11";
    nixpkgs-unstable.url = "github:nixos/nixpkgs/nixpkgs-unstable";

    nix-darwin = {
      url = "github:LnL7/nix-darwin/nix-darwin-25.11";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    disko.url = "github:nix-community/disko";
    disko.inputs.nixpkgs.follows = "nixpkgs";

    vscode-server.url = "github:zeyugao/nixos-vscode-server";
    home-manager.url = "github:nix-community/home-manager/release-25.11";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = inputs @ {flake-parts, ...}:
    flake-parts.lib.mkFlake {inherit inputs;} {
      systems = ["x86_64-linux" "aarch64-darwin" "x86_64-darwin"];

      imports = [
        ./flake-modules/nixos.nix
        ./flake-modules/darwin.nix
      ];

      perSystem = {
        pkgs,
        system,
        ...
      }: {
        formatter = pkgs.alejandra;

        packages = {
          # Select the appropriate VM architecture based on host system
          test-vm =
            if system == "aarch64-darwin" || system == "aarch64-linux"
            then inputs.self.nixosConfigurations.test-vm-arm.config.system.build.vm
            else inputs.self.nixosConfigurations.test-vm.config.system.build.vm;
        };
      };
    };
}
