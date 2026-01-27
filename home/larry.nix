{
  config,
  pkgs,
  lib,
  unstablePkgs,
  ...
}: {
  home.stateVersion = "24.05";

  programs.home-manager.enable = true;

  programs.zsh = {
    enable = true;
    autosuggestion.enable = true;
    enableCompletion = true;
  };

  programs.git = {
    enable = true;
  };
}
