{
  config,
  pkgs,
  lib,
  unstablePkgs,
  ...
}: final: prev: {
  python312 = prev.python312.override {
    packageOverrides = python-final: python-prev: {
      primp = python-final.callPackage ../pkgs/primp {};
      duckduckgo-search = python-final.callPackage unstablePkgs.python312Packages.duckduckgo-search.override {
        primp = python-final.primp;
      };
      gcp-storage-emulator = python-final.callPackage unstablePkgs.python312Packages.gcp-storage-emulator.override {
        inherit (python-final) buildPythonPackage;
      };
    };
  };
}
