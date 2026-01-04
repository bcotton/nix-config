{
  pkgs,
  lib,
  config,
  ...
}: let
  cfg = config.programs.tmux-popup-apps;

  # Build the menu entries as "name\tcommand" pairs
  # Add "Run Command..." as a special entry at the end
  menuEntries =
    lib.concatMapStringsSep "\\n" (app: "${app.name}\t${app.command}") cfg.apps
    + "\\n---\\t__SEPARATOR__"
    + "\\nRun Command...\\t__CUSTOM__";

  # Temp file for passing selection between popups
  tmpFile = "/tmp/tmux-popup-app-cmd";

  # Script that shows the fzf menu and writes selection to temp file
  menuScript = pkgs.writeShellScript "tmux-popup-menu" ''
    # Present menu via fzf and get selection
    selected=$(echo -e "${menuEntries}" | \
      ${pkgs.fzf}/bin/fzf \
        --delimiter='\t' \
        --with-nth=1 \
        --reverse \
        --no-border \
        --ansi \
        --prompt='Apps > ' \
        --color='list-border:6,input-border:3,preview-border:2,header-bg:-1,header-border:6' \
        --input-border \
        --header='Select an app to launch' \
        --header-border \
        --bind='tab:down,btab:up')

    # If user selected something, write command to temp file
    if [ -n "$selected" ]; then
      # Extract the command (second field)
      echo "$selected" | cut -f2 > "${tmpFile}"
    fi
  '';

  # Script to prompt for a custom command
  promptScript = pkgs.writeShellScript "tmux-popup-prompt" ''
    printf "Command: "
    read -r cmd
    if [ -n "$cmd" ]; then
      echo "$cmd" > "${tmpFile}"
    fi
  '';

  # Launcher script that runs the menu popup, then opens app popup
  launcherScript = pkgs.writeShellScript "tmux-popup-launcher" ''
    # Clear any previous selection
    rm -f "${tmpFile}"

    # Get the current pane's path before opening popup
    PANE_PATH="$(tmux display-message -p '#{pane_current_path}')"

    # Open the menu popup (this blocks until closed)
    tmux display-popup -E -w 50% -h 50% "${menuScript}"

    # Check if a command was selected
    if [ -f "${tmpFile}" ]; then
      cmd=$(cat "${tmpFile}")
      rm -f "${tmpFile}"

      # Handle special entries
      if [ "$cmd" = "__SEPARATOR__" ]; then
        # Separator selected, do nothing
        exit 0
      elif [ "$cmd" = "__CUSTOM__" ]; then
        # Prompt for custom command
        tmux display-popup -E -w 60% -h 3 "${promptScript}"
        if [ -f "${tmpFile}" ]; then
          cmd=$(cat "${tmpFile}")
          rm -f "${tmpFile}"
        else
          exit 0
        fi
      fi

      if [ -n "$cmd" ]; then
        # Open the selected app in a popup
        tmux display-popup -E -d "$PANE_PATH" -xC -yC -w 80% -h 75% "$cmd"
      fi
    fi
  '';
in {
  options.programs.tmux-popup-apps = {
    enable = lib.mkEnableOption "tmux popup apps menu";

    apps = lib.mkOption {
      type = lib.types.listOf (lib.types.submodule {
        options = {
          name = lib.mkOption {
            type = lib.types.str;
            description = "Display name for the app in the menu";
          };
          command = lib.mkOption {
            type = lib.types.str;
            description = "Command to run in the popup";
          };
        };
      });
      default = [];
      description = "List of apps to show in the popup menu";
      example = lib.literalExpression ''
        [
          { name = "LazyGit"; command = "lazygit"; }
          { name = "K9s"; command = "k9s"; }
        ]
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    programs.tmux.extraConfig = lib.mkAfter ''
      # Popup apps menu: <prefix> M-k
      bind-key M-k run-shell "${launcherScript}"
    '';
  };
}
