{
  config,
  pkgs,
  lib,
  unstablePkgs,
  ...
}: final: prev: {
  qmk = prev.qmk.overridePythonAttrs (oldAttrs: {
    propagatedBuildInputs =
      (oldAttrs.propagatedBuildInputs or [])
      ++ [
        final.python3Packages.appdirs
      ];
  });
}
