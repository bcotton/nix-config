{
  config,
  pkgs,
  lib,
  unstablePkgs,
}: final: prev: {
  tmuxai = final.callPackage ../pkgs/tmuxai {};
}
