# This is imported as module, from the top-level flake
{
  pkgs,
  unstablePkgs,
  lib,
  inputs,
  ...
}: let
  inherit (inputs) nixpkgs nixpkgs-unstable;
in {
  config = {
    system.primaryUser = "bcotton";
    users.users.bcotton.home = "/Users/bcotton";
    ids.gids.nixbld = 30000;

    # These are packages are just for darwin systems
    environment.systemPackages = with pkgs; [
      kind
      esphome
      esptool
      # Node and friends
      nodejs_22
      yarn-berry
      webpack-cli
      pnpm_10
    ];

    nixpkgs.config.allowUnfree = true;
    nixpkgs.config.overlays = [
      (final: prev:
        lib.optionalAttrs (prev.stdenv.system == "aarch64-darwin") {
          # Add access to x86 packages system is running Apple Silicon
          pkgs-x86 = import nixpkgs {
            system = "x86_64-darwin";
            config.allowUnfree = true;
          };
        })
    ];

    # Keyboard
    system.keyboard.enableKeyMapping = true;
    system.keyboard.remapCapsLockToEscape = false;

    # Add ability to used TouchID for sudo authentication
    security.pam.services.sudo_local = {
      touchIdAuth = true;
      watchIdAuth = true;
      reattach = true;
    };

    programs.zsh = {
      enable = true;
      enableCompletion = true;
      promptInit = builtins.readFile ./mac-dot-zshrc;
      #interactiveShellInit = "/Users/alex/go/bin/figurine -f \"Rammstein.flf\" magrathea";
    };

    homebrew = {
      enable = true;
      # updates homebrew packages on activation,
      # can make darwin-rebuild much slower (otherwise i'd forget to do it ever though)
      # onActivation.upgrade = true;

      taps = [
        #
      ];
      brews = [
        "azure-cli"
        "bash"
        "borders"
        "colordiff"
        "duf"
        "etcd"
        "fswatch"
        "fzf"
        "gh"
        "git-absorb"
        "git-delta"
        "glances"
        "glow"
        "go"
        "golangci-lint"
        "gron"
        "helm"
        "hwatch"
        "jd"
        "jnv"
        "jq"
        "jsonnet"
        "jsonnet-bundler"
        "k9s"
        "kube-fzf"
        "kubectx"
        "kubernetes-cli"
        "kustomize"
        "lastpass-cli"
        "lazydocker"
        "lazygit"
        "mage"
        "mas"
        "minikube"
        "mkdocs"
        "mods"
        "node"
        "node_exporter"
        "npm"
        "oh-my-posh"
        "prometheus"
        "reattach-to-user-namespace"
        "ripgrep"
        "shellcheck"
        "skhd"
        "stern"
        "tailscale"
        "tanka"
        "telnet"
        "terminal-notifier"
        "terraform"
        "the_silver_searcher"
        "thefuck"
        "tilt"
        "tmux"
        "tree"
        "trufflehog"
        "watch"
        "wget"
        "yarn"
        "yq"
        "zizmor"
      ];
      casks = [
        "1password"
        "1password-cli"
        "aerospace"
        "alfred"
        "amethyst"
        "balenaetcher"
        "barrier"
        "bartender"
        "calibre"
        "companion"
        "discord"
        "docker-desktop"
        "dropbox"
        "element"
        "flirc"
        "gcloud-cli"
        "ghostty"
        "google-chrome"
        "gcloud-cli"
        "istat-menus"
        "iterm2"
        "karabiner-elements"
        "little-snitch"
        "macwhisper"
        "monitorcontrol"
        "mqtt-explorer"
        "netnewswire"
        "obs"
        "obsidian"
        "omnidisksweeper"
        "onyx"
        "openscad"
        "openttd"
        "orbstack"
        "prusaslicer"
        "rectangle"
        "shortcat"
        "signal"
        "slack"
        "spotify"
        "swinsian"
        "telegram"
        "visual-studio-code"
        "vlc"
        "wezterm"
        "wireshark-app"
        "xquartz"
        "zoom"
      ];
      masApps = {
        "Amphetamine" = 937984704;
        "Blackmagic Disk Speed Test" = 425264550;
        "CleanMyMac" = 1339170533;
        "GarageBand" = 682658836;
        "iMovie" = 408981434;
        "Keynote" = 409183694;
        "MultiVNC" = 6738012997;
        "Numbers" = 409203825;
        "Pages" = 409201541;
        "Tailscale" = 1475387142;
        "WiFi Explorer Lite" = 1408727408;
        "Windows App" = 1295203466;
        "Xcode" = 497799835;
      };
    };

    # macOS configuration
    system.defaults = {
      NSGlobalDomain.AppleShowAllExtensions = true;
      NSGlobalDomain.AppleShowScrollBars = "Always";
      NSGlobalDomain.NSUseAnimatedFocusRing = false;
      NSGlobalDomain.NSNavPanelExpandedStateForSaveMode = true;
      NSGlobalDomain.NSNavPanelExpandedStateForSaveMode2 = true;
      NSGlobalDomain.PMPrintingExpandedStateForPrint = true;
      NSGlobalDomain.PMPrintingExpandedStateForPrint2 = true;
      NSGlobalDomain.NSDocumentSaveNewDocumentsToCloud = false;
      NSGlobalDomain.ApplePressAndHoldEnabled = false;
      NSGlobalDomain.InitialKeyRepeat = 25;
      NSGlobalDomain.KeyRepeat = 4;
      NSGlobalDomain."com.apple.mouse.tapBehavior" = 1;
      LaunchServices.LSQuarantine = false; # disables "Are you sure?" for new apps
      loginwindow.GuestEnabled = false;
    };
    system.defaults.CustomUserPreferences = {
      "com.apple.finder" = {
        ShowExternalHardDrivesOnDesktop = true;
        ShowHardDrivesOnDesktop = false;
        ShowMountedServersOnDesktop = false;
        ShowRemovableMediaOnDesktop = true;
        _FXSortFoldersFirst = true;
        # When performing a search, search the current folder by default
        FXDefaultSearchScope = "SCcf";
        DisableAllAnimations = true;
        NewWindowTarget = "PfDe";
        NewWindowTargetPath = "file://$\{HOME\}/Desktop/";
        AppleShowAllExtensions = true;
        FXEnableExtensionChangeWarning = false;
        ShowStatusBar = true;
        ShowPathbar = true;
        WarnOnEmptyTrash = false;
      };
      "com.apple.desktopservices" = {
        # Avoid creating .DS_Store files on network or USB volumes
        DSDontWriteNetworkStores = true;
        DSDontWriteUSBStores = true;
      };
      "com.apple.dock" = {
        autohide = true;
        launchanim = false;
        static-only = false;
        show-recents = false;
        show-process-indicators = true;
        orientation = "right";
        tilesize = 36;
        minimize-to-application = true;
        mineffect = "scale";
      };
      "com.apple.ActivityMonitor" = {
        OpenMainWindow = true;
        IconType = 5;
        SortColumn = "CPUUsage";
        SortDirection = 0;
      };
      # "com.apple.Safari" = {
      #   # Privacy: don’t send search queries to Apple
      #   UniversalSearchEnabled = false;
      #   SuppressSearchSuggestions = true;
      # };
      "com.apple.AdLib" = {
        allowApplePersonalizedAdvertising = false;
      };
      "com.apple.SoftwareUpdate" = {
        AutomaticCheckEnabled = true;
        # Check for software updates daily, not just once per week
        ScheduleFrequency = 1;
        # Download newly available updates in background
        AutomaticDownload = 1;
        # Install System data files & security updates
        CriticalUpdateInstall = 1;
      };
      "com.apple.TimeMachine".DoNotOfferNewDisksForBackup = true;
      # Prevent Photos from opening automatically when devices are plugged in
      "com.apple.ImageCapture".disableHotPlug = true;
      # Turn on app auto-update
      "com.apple.commerce".AutoUpdate = true;
      "com.googlecode.iterm2".PromptOnQuit = false;
      "com.google.Chrome" = {
        AppleEnableSwipeNavigateWithScrolls = true;
        DisablePrintPreview = true;
        PMPrintingExpandedStateForPrint2 = true;
      };
    };
  };
}
