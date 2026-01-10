{inputs, ...}: {
  perSystem = {
    pkgs,
    config,
    lib,
    ...
  }: {
    packages =
      {
        # Cross-platform packages
        primp = pkgs.python3Packages.callPackage ../pkgs/primp {};
        gwtmux = pkgs.callPackage ../pkgs/gwtmux {};
      }
      # Darwin-only packages
      // lib.optionalAttrs pkgs.stdenv.isDarwin {
        # browser-opener: TCP listener for opening URLs in local browser
        browser-opener = pkgs.callPackage ../pkgs/browser-opener {};
        # clipboard-receiver: TCP listener for copying text to local clipboard
        clipboard-receiver = pkgs.callPackage ../pkgs/clipboard-receiver {};
        # arc-tab-archiver: Capture auto-archived Arc browser tabs to Obsidian
        arc-tab-archiver = pkgs.callPackage ../pkgs/arc-tab-archiver {};
      }
      # Linux-only packages
      // lib.optionalAttrs pkgs.stdenv.isLinux {
        # xdg-open-remote: Send URLs through SSH tunnel to open on remote desktop
        xdg-open-remote = pkgs.callPackage ../pkgs/xdg-open-remote {};
        # remote-copy: Send text through SSH tunnel to copy on remote desktop
        remote-copy = pkgs.callPackage ../pkgs/remote-copy {};
      };

    # Expose localPackages via legacyPackages for backward compatibility
    # This allows accessing packages via self.legacyPackages.${system}.localPackages
    legacyPackages.localPackages =
      {
        inherit (config.packages) primp gwtmux;
      }
      // lib.optionalAttrs pkgs.stdenv.isDarwin {
        inherit (config.packages) browser-opener clipboard-receiver arc-tab-archiver;
      }
      // lib.optionalAttrs pkgs.stdenv.isLinux {
        inherit (config.packages) xdg-open-remote remote-copy;
      };
  };
}
