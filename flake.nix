{
  inputs = {
    agenix.url = "github:ryantm/agenix";
    nixinate.url = "github:matthewcroughan/nixinate";

    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.05";
    nixpkgs-unstable.url = "github:nixos/nixpkgs/nixpkgs-unstable";

    flake-parts.url = "github:hercules-ci/flake-parts";
    flake-parts.inputs.nixpkgs-lib.follows = "nixpkgs";

    nix-darwin = {
      url = "github:LnL7/nix-darwin/nix-darwin-25.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    isd.url = "github:isd-project/isd";

    disko.url = "github:nix-community/disko";
    disko.inputs.nixpkgs.follows = "nixpkgs";

    vscode-server.url = "github:zeyugao/nixos-vscode-server";
    home-manager.url = "github:nix-community/home-manager/release-25.05";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";

    nixos-shell.url = "github:Mic92/nixos-shell";

    ghostty.url = "github:ghostty-org/ghostty";

    tsnsrv = {
      url = "github:boinkor-net/tsnsrv";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nixos-generators = {
      url = "github:nix-community/nixos-generators";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    opencode = {
      url = "github:sst/opencode";
      inputs.nixpkgs.follows = "nixpkgs-unstable";
    };

    beads = {
      url = "github:steveyegge/beads";
      inputs.nixpkgs.follows = "nixpkgs-unstable";
    };

    workmux = {
      url = "github:bcotton/workmux/2d20d09";
      inputs.nixpkgs.follows = "nixpkgs-unstable";
    };

    nix-builder-config = {
      url = "git+http://nas-01.lan:3000/bcotton/nix-builder-config";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = inputs @ {flake-parts, ...}:
    flake-parts.lib.mkFlake {inherit inputs;} {
      systems = [
        "x86_64-linux"
        "aarch64-linux"
        "x86_64-darwin"
        "aarch64-darwin"
      ];

      imports = [
        ./flake-modules/formatter.nix
        ./flake-modules/packages.nix
        ./flake-modules/overlays.nix
        ./flake-modules/checks.nix
        ./flake-modules/hosts.nix
      ];
    };
}
