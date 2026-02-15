{
  config,
  pkgs,
  lib,
  unstablePkgs,
  ...
}: final: prev: {
  # Use claude-code from nixpkgs-unstable which tracks recent versions
  claude-code = unstablePkgs.claude-code;
}
