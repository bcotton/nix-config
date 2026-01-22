{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.programs.zsh-profiling;
in {
  options.programs.zsh-profiling = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable zsh startup profiling";
    };
  };

  config = lib.mkIf cfg.enable {
    programs.zsh.initExtraFirst = ''
      # Enable zprof module for profiling
      zmodload zsh/zprof
    '';

    programs.zsh.initContent = ''
      # Show profiling results at the end
      zprof
    '';
  };
}
