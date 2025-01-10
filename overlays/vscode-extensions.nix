{
  config,
  pkgs,
  lib,
  unstablePkgs,
  ...
}: final: prev: {
  vscode-extensions = import ../pkgs/applications/editors/vscode/extensions {
    inherit (final) lib pkgs;
  };
}
