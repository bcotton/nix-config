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

      # ZFS/disko tests
      zfs-single-root = import ../modules/zfs/zfs-single-root-test.nix {
        nixpkgs = inputs.nixpkgs;
        inherit pkgs;
        disko = inputs.disko;
      };

      zfs-raidz1 = import ../modules/zfs/zfs-raidz1-test.nix {
        nixpkgs = inputs.nixpkgs;
        inherit pkgs;
        disko = inputs.disko;
      };

      zfs-mirrored-root = import ../modules/zfs/zfs-mirrored-root-test.nix {
        nixpkgs = inputs.nixpkgs;
        inherit pkgs;
        disko = inputs.disko;
      };
    };
  };
}
