{
  config,
  pkgs,
  lib,
  unstablePkgs,
  ...
}: {
  nixpkgs.overlays = [
    (final: prev:
      (import ./overlays/yq.nix {inherit config pkgs lib unstablePkgs;}) final prev)

    # Fix setproctitle tests failing in VMs (fork/segfault tests)
    (final: prev: {
      pythonPackagesExtensions =
        prev.pythonPackagesExtensions
        ++ [
          (python-final: python-prev: {
            setproctitle = python-prev.setproctitle.overridePythonAttrs (old: {
              doCheck = false;
            });
          })
        ];
    })
  ];
}
