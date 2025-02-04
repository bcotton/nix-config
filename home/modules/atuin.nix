{
  pkgs,
  lib,
  config,
  ...
}: let
  cfg = config.programs.atuin-config;
in {
  options.programs.atuin-config = {
    nixosKeyPath = lib.mkOption {
      type = lib.types.str;
      default = "/run/agenix/bcotton-atuin-key";
      description = "Path to the atuin key file on NixOS systems";
    };

    darwinKeyPath = lib.mkOption {
      type = lib.types.str;
      default = "~/.local/share/atuin/key";
      description = "Path to the atuin key file on Darwin systems";
    };
  };

  config = {
    xdg.configFile."atuin/config.toml" = {
      text = let
        keyPath =
          if pkgs.stdenv.isDarwin
          then cfg.darwinKeyPath
          else cfg.nixosKeyPath;
      in ''
        ## where to store your database, default is your system data directory
        ## linux/mac: ~/.local/share/atuin/history.db
        ## windows: %USERPROFILE%/.local/share/atuin/history.db
        # db_path = "~/.history.db"

        ## where to store your encryption key, default is your system data directory
        ## linux/mac: ~/.local/share/atuin/key
        ## windows: %USERPROFILE%/.local/share/atuin/key
        key_path = "${keyPath}"

        ## where to store your auth session token, default is your system data directory
        ## linux/mac: ~/.local/share/atuin/session
        ## windows: %USERPROFILE%/.local/share/atuin/session
        # session_path = "~/.session"

        ## date format used, either "us" or "uk"
        # dialect = "us"

        ## default timezone to use when displaying time
        ## either "l", "local" to use the system's current local timezone, or an offset
        ## from UTC in the format of "<+|->H[H][:M[M][:S[S]]]"
        ## for example: "+9", "-05", "+03:30", "-01:23:45", etc.
        # timezone = "local"

        ## enable or disable automatic sync
        # auto_sync = true

        ## enable or disable automatic update checks
        # update_check = true

        ## address of the sync server
        sync_address = "https://atuin.bobtail-clownfish.ts.net"

        ## how often to sync history. note that this is only triggered when a command
        ## is ran, so sync intervals may well be longer
        ## set it to 0 to sync after every command
        sync_frequency = "10s"

        ## which search mode to use
        ## possible values: prefix, fulltext, fuzzy, skim
        # search_mode = "fuzzy"

        ## which filter mode to use
        ## possible values: global, host, session, directory
        # filter_mode = "global"

        ## With workspace filtering enabled, Atuin will filter for commands executed
        ## in any directory within a git repository tree (default: false)
        # workspaces = false

        ## which filter mode to use when atuin is invoked from a shell up-key binding
        ## the accepted values are identical to those of "filter_mode"
        ## leave unspecified to use same mode set in "filter_mode"
        # filter_mode_shell_up_key_binding = "global"

        ## which search mode to use when atuin is invoked from a shell up-key binding
        ## the accepted values are identical to those of "search_mode"
        ## leave unspecified to use same mode set in "search_mode"
        # search_mode_shell_up_key_binding = "fuzzy"

        ## which style to use
        ## possible values: auto, full, compact
        # style = "auto"

        ## the maximum number of lines the interface should take up
        ## set it to 0 to always go full screen
        # inline_height = 0

        ## Invert the UI - put the search bar at the top , Default to `false`
        # invert = false

        ## enable or disable showing a preview of the selected command
        ## useful when the command is longer than the terminal width and is cut off
        # show_preview = true

        ## what to do when the escape key is pressed when searching
        ## possible values: return-original, return-query
        # exit_mode = "return-original"

        ## possible values: emacs, subl
        word_jump_mode = "emacs"

        ## characters that count as a part of a word
        # word_chars = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"

        ## number of context lines to show when scrolling by pages
        # scroll_context_lines = 1

        ## use ctrl instead of alt as the shortcut modifier key for numerical UI shortcuts
        ## alt-0 .. alt-9
        # ctrl_n_shortcuts = false

        ## default history list format - can also be specified with the --format arg
        # history_format = "{time}\t{command}\t{duration}"

        ## prevent commands matching any of these regexes from being written to history.
        ## Note that these regular expressions are unanchored, i.e. if they don't start
        ## with ^ or end with $, they'll match anywhere in the command.
        ## For details on the supported regular expression syntax, see
        ## https://docs.rs/regex/latest/regex/#syntax
        # history_filter = [
        #   "^secret-cmd",
        #   "^innocuous-cmd .*--secret=.+",
        # ]

        ## prevent commands run with cwd matching any of these regexes from being written
        ## to history. Note that these regular expressions are unanchored, i.e. if they don't
        ## start with ^ or end with $, they'll match anywhere in CWD.
        ## For details on the supported regular expression syntax, see
        ## https://docs.rs/regex/latest/regex/#syntax
        # cwd_filter = [
        #   "^/very/secret/area",
        # ]

        ## Configure the maximum height of the preview to show.
        ## Useful when you have long scripts in your history that you want to distinguish
        ## by more than the first few lines.
        # max_preview_height = 4

        ## Configure whether or not to show the help row, which includes the current Atuin
        ## version (and whether an update is available), a keymap hint, and the total
        ## amount of commands in your history.
        # show_help = true

        ## Configure whether or not to show tabs for search and inspect
        # show_tabs = true

        ## Defaults to true. This matches history against a set of default regex, and will not save it if we get a match. Defaults include
        ## 1. AWS key id
        ## 2. Github pat (old and new)
        ## 3. Slack oauth tokens (bot, user)
        ## 4. Slack webhooks
        ## 5. Stripe live/test keys
        # secrets_filter = true

        ## Defaults to true. If enabled, upon hitting enter Atuin will immediately execute the command. Press tab to return to the shell and edit.
        # This applies for new installs. Old installs will keep the old behaviour unless configured otherwise.
        enter_accept = true

        ## Defaults to "emacs".  This specifies the keymap on the startup of `atuin
        ## search`.  If this is set to "auto", the startup keymap mode in the Atuin
        ## search is automatically selected based on the shell's keymap where the
        ## keybinding is defined.  If this is set to "emacs", "vim-insert", or
        ## "vim-normal", the startup keymap mode in the Atuin search is forced to be
        ## the specified one.
        keymap_mode = "emacs"

        ## Cursor style in each keymap mode.  If specified, the cursor style is changed
        ## in entering the cursor shape.  Available values are "default" and
        ## "{blink,steady}-{block,underline,bar}".
        # keymap_cursor = { emacs = "blink-block", vim_insert = "blink-block", vim_normal = "steady-block" }

        # network_connect_timeout = 5
        # network_timeout = 5

        ## Timeout (in seconds) for acquiring a local database connection (sqlite)
        # local_timeout = 5

        ## Set this to true and Atuin will minimize motion in the UI - timers will not update live, etc.
        ## Alternatively, set env NO_MOTION=true
        # prefers_reduced_motion = false

        [stats]
        ## Set commands where we should consider the subcommand for statistics. Eg, kubectl get vs just kubectl
        # common_subcommands = [
        #   "apt",
        #   "cargo",
        #   "composer",
        #   "dnf",
        #   "docker",
        #   "git",
        #   "go",
        #   "ip",
        #   "kubectl",
        #   "nix",
        #   "nmcli",
        #   "npm",
        #   "pecl",
        #   "pnpm",
        #   "podman",
        #   "port",
        #   "systemctl",
        #   "tmux",
        #   "yarn",
        # ]

        ## Set commands that should be totally stripped and ignored from stats
        common_prefix = ["sudo"]

        ## Set commands that will be completely ignored from stats
        # ignored_commands = [
        #   "cd",
        #   "ls",
        #   "vi"
        # ]

        [keys]
        # Defaults to true. If disabled, using the up/down key won't exit the TUI when scrolled past the first/last entry.
        # scroll_exits = false

        [sync]
        # Enable sync v2 by default
        # This ensures that sync v2 is enabled for new installs only
        # In a later release it will become the default across the board
        records = true

        [preview]
        ## which preview strategy to use to calculate the preview height (respects max_preview_height).
        ## possible values: auto, static
        ## auto: length of the selected command.
        ## static: length of the longest command stored in the history.
        # strategy = "auto"

        [daemon]
        ## Enables using the daemon to sync. Requires the daemon to be running in the background. Start it with `atuin daemon`
        # enabled = false

        ## How often the daemon should sync in seconds
        # sync_frequency = 300

        ## The path to the unix socket used by the daemon (on unix systems)
        ## linux/mac: ~/.local/share/atuin/atuin.sock
        ## windows: Not Supported
        # socket_path = "~/.local/share/atuin/atuin.sock"

        ## Use systemd socket activation rather than opening the given path (the path must still be correct for the client)
        ## linux: false
        ## mac/windows: Not Supported
        # systemd_socket = false

        ## The port that should be used for TCP on non unix systems
        # tcp_port = 8889
      '';
    };
  };
}
