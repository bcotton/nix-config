{
  config,
  lib,
  pkgs,
  localPackages,
  ...
}:
with lib; let
  cfg = config.programs.workmux;
  yamlFormat = pkgs.formats.yaml {};

  paneType = types.submodule {
    options = {
      command = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "Command to run in this pane";
      };
      focus = mkOption {
        type = types.bool;
        default = false;
        description = "Whether to focus this pane";
      };
      split = mkOption {
        type = types.nullOr (types.enum ["horizontal" "vertical"]);
        default = null;
        description = "Split direction for this pane";
      };
      size = mkOption {
        type = types.nullOr types.int;
        default = null;
        description = "Size in lines/columns for this pane";
      };
      percentage = mkOption {
        type = types.nullOr types.int;
        default = null;
        description = "Percentage of space for this pane";
      };
    };
  };

  filesType = types.submodule {
    options = {
      copy = mkOption {
        type = types.listOf types.str;
        default = [];
        description = "Glob patterns for files/directories to copy into new worktrees";
      };
      symlink = mkOption {
        type = types.listOf types.str;
        default = [];
        description = "Glob patterns for files/directories to symlink";
      };
    };
  };

  statusIconsType = types.submodule {
    options = {
      working = mkOption {
        type = types.str;
        default = "🤖";
        description = "Icon for working agent status";
      };
      waiting = mkOption {
        type = types.str;
        default = "⏳";
        description = "Icon for waiting agent status";
      };
      done = mkOption {
        type = types.str;
        default = "✅";
        description = "Icon for done agent status";
      };
    };
  };
in {
  options.programs.workmux = {
    enable = mkEnableOption "workmux - parallel development in tmux with git worktrees";

    package = mkOption {
      type = types.package;
      default = localPackages.workmux;
      defaultText = literalExpression "localPackages.workmux";
      description = "The workmux package to use";
    };

    windowPrefix = mkOption {
      type = types.str;
      default = "wm-";
      description = "Prefix for tmux window names";
    };

    worktreePrefix = mkOption {
      type = types.nullOr types.str;
      default = null;
      description = "Prefix prepended to worktree directory and window names";
    };

    panes = mkOption {
      type = types.listOf paneType;
      default = [];
      example = literalExpression ''
        [
          { command = "nvim ."; focus = true; }
          { split = "horizontal"; }
        ]
      '';
      description = "Pane layout configuration";
    };

    postCreate = mkOption {
      type = types.listOf types.str;
      default = [];
      example = ["mise install" "npm install"];
      description = "Commands executed after worktree creation";
    };

    files = mkOption {
      type = filesType;
      default = {};
      description = "File operations configuration";
    };

    agent = mkOption {
      type = types.nullOr types.str;
      default = null;
      example = "claude";
      description = "Default agent command (claude, codex, opencode, gemini)";
    };

    mergeStrategy = mkOption {
      type = types.nullOr (types.enum ["merge" "rebase" "squash"]);
      default = null;
      description = "Default merge strategy";
    };

    mainBranch = mkOption {
      type = types.nullOr types.str;
      default = null;
      example = "main";
      description = "Target branch for merging (auto-detected if omitted)";
    };

    statusFormat = mkOption {
      type = types.bool;
      default = true;
      description = "Auto-configure tmux status format";
    };

    statusIcons = mkOption {
      type = statusIconsType;
      default = {};
      description = "Custom emoji/icons for agent status";
    };

    extraConfig = mkOption {
      type = types.attrs;
      default = {};
      description = "Additional configuration options to merge into config.yaml";
    };
  };

  config = mkIf cfg.enable {
    home.packages = [cfg.package];

    xdg.configFile."workmux/config.yaml" = mkIf (
      cfg.windowPrefix != "wm-" ||
      cfg.worktreePrefix != null ||
      cfg.panes != [] ||
      cfg.postCreate != [] ||
      cfg.files.copy != [] ||
      cfg.files.symlink != [] ||
      cfg.agent != null ||
      cfg.mergeStrategy != null ||
      cfg.mainBranch != null ||
      cfg.statusFormat != true ||
      cfg.statusIcons != {} ||
      cfg.extraConfig != {}
    ) {
      source = let
        configData = filterAttrs (n: v: v != null && v != {} && v != []) {
          window_prefix = cfg.windowPrefix;
          worktree_prefix = cfg.worktreePrefix;
          panes = if cfg.panes != [] then
            map (pane: filterAttrs (n: v: v != null && v != false) pane) cfg.panes
          else null;
          post_create = if cfg.postCreate != [] then cfg.postCreate else null;
          files = if (cfg.files.copy != [] || cfg.files.symlink != []) then
            filterAttrs (n: v: v != []) cfg.files
          else null;
          agent = cfg.agent;
          merge_strategy = cfg.mergeStrategy;
          main_branch = cfg.mainBranch;
          status_format = cfg.statusFormat;
          status_icons = if cfg.statusIcons != {} then cfg.statusIcons else null;
        };
      in yamlFormat.generate "workmux-config" (configData // cfg.extraConfig);
    };

    programs.zsh.initContent = ''
      # Enable workmux shell completions
      if command -v workmux &> /dev/null; then
        eval "$(workmux completions zsh)"
      fi
    '';

    programs.bash.initExtra = ''
      # Enable workmux shell completions
      if command -v workmux &> /dev/null; then
        eval "$(workmux completions bash)"
      fi
    '';
  };
}
