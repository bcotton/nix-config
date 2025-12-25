{inputs, ...}: {
  perSystem = {pkgs, ...}: {
    packages = {
      primp = pkgs.python3Packages.callPackage ../pkgs/primp {};
      gwtmux = pkgs.callPackage ../pkgs/gwtmux {};
    };
  };
}
