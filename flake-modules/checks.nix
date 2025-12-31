{inputs, ...}: {
  perSystem = {
    pkgs,
    system,
    lib,
    ...
  }: {
    checks = lib.optionalAttrs (system == "x86_64-linux") {
      # NixOS tests - only available on x86_64-linux
      # To run: nix build '.#checks.x86_64-linux.postgresql'
      # Interactive: nix run '.#checks.x86_64-linux.postgresql.driverInteractive'
      postgresql = pkgs.nixosTest (import ../modules/postgresql/test.nix {
        nixpkgs = inputs.nixpkgs;
      });

      webdav = pkgs.nixosTest (import ../clubcotton/services/webdav/test.nix {
        nixpkgs = inputs.nixpkgs;
      });

      kavita = pkgs.nixosTest (import ../clubcotton/services/kavita/test.nix {
        nixpkgs = inputs.nixpkgs;
      });

      harmonia = pkgs.nixosTest (import ../clubcotton/services/harmonia/test.nix {
        nixpkgs = inputs.nixpkgs;
      });

      nix-cache-proxy = pkgs.nixosTest (import ../clubcotton/services/nix-cache-proxy/test.nix {
        nixpkgs = inputs.nixpkgs;
      });

      forgejo = import ../clubcotton/services/forgejo/test.nix {
        inherit pkgs lib;
      };

      forgejo-runner = import ../clubcotton/services/forgejo/runner-test.nix {
        inherit pkgs lib;
      };

      nix-cache-integration = let
        unstablePkgs = import inputs.nixpkgs-unstable {
          inherit system;
          config.allowUnfree = true;
        };
      in
        pkgs.nixosTest (import ../tests/nix-cache-integration.nix {
          nixpkgs = inputs.nixpkgs;
          inherit unstablePkgs inputs;
        });

      postgresql-integration = let
        unstablePkgs = import inputs.nixpkgs-unstable {
          inherit system;
          config.allowUnfree = true;
        };
      in
        pkgs.nixosTest (import ../tests/postgresql-integration.nix {
          nixpkgs = inputs.nixpkgs;
          inherit unstablePkgs;
          inherit inputs;
        });

      # ZFS/disko tests - DISABLED BY DEFAULT
      # These tests require --impure flag due to disko's test infrastructure
      # using impure <nixpkgs> path lookups internally.
      # See: https://github.com/nix-community/disko/issues/881
      #
      # To run these tests, uncomment them and run: just check --impure
      #
      # zfs-single-root = import ../modules/zfs/zfs-single-root-test.nix {
      #   nixpkgs = inputs.nixpkgs;
      #   disko = inputs.disko;
      #   inherit pkgs;
      # };
      #
      # zfs-raidz1 = import ../modules/zfs/zfs-raidz1-test.nix {
      #   nixpkgs = inputs.nixpkgs;
      #   disko = inputs.disko;
      #   inherit pkgs;
      # };
      #
      # zfs-mirrored-root = import ../modules/zfs/zfs-mirrored-root-test.nix {
      #   nixpkgs = inputs.nixpkgs;
      #   disko = inputs.disko;
      #   inherit pkgs;
      # };
    };
  };
}
