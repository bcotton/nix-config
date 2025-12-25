{inputs, ...}: {
  perSystem = {
    pkgs,
    config,
    ...
  }: {
    packages = {
      primp = pkgs.python3Packages.callPackage ../pkgs/primp {};
      gwtmux = pkgs.callPackage ../pkgs/gwtmux {};
    };

    # Expose localPackages via legacyPackages for backward compatibility
    # This allows accessing packages via self.legacyPackages.${system}.localPackages
    legacyPackages.localPackages = {
      inherit (config.packages) primp gwtmux;
    };
  };
}
