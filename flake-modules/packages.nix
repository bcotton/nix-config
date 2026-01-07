{inputs, ...}: {
  perSystem = {
    pkgs,
    config,
    lib,
    ...
  }: {
    packages = {
      primp = pkgs.python3Packages.callPackage ../pkgs/primp {};
      gwtmux = pkgs.callPackage ../pkgs/gwtmux {};
      # browser-opener: Darwin-only TCP listener for opening URLs in local browser
      browser-opener = pkgs.callPackage ../pkgs/browser-opener {};
      # xdg-open-remote: Send URLs through SSH tunnel to open on remote desktop
      xdg-open-remote = pkgs.callPackage ../pkgs/xdg-open-remote {};
    };

    # Expose localPackages via legacyPackages for backward compatibility
    # This allows accessing packages via self.legacyPackages.${system}.localPackages
    legacyPackages.localPackages = {
      inherit (config.packages) primp gwtmux browser-opener xdg-open-remote;
    };
  };
}
