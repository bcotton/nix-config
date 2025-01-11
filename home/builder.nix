{
  config,
  pkgs,
  lib,
  unstablePkgs,
  ...
}: {
  programs.zsh = {
    enable = true;
  };
  home.stateVersion = "23.05";
}
