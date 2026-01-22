# This is imported as module, from the top-level flake
{
  pkgs,
  unstablePkgs,
  lib,
  inputs,
  config,
  hostName,
  ...
}:
with lib; let
  inherit (inputs) nixpkgs nixpkgs-unstable;
  # Get merged variables (defaults + host overrides)
  commonLib = import ../../common/lib.nix;
  variables = commonLib.getHostVariables hostName;
  cfg = config.services.clubcotton.toms-darwin;
in {
  options.services.clubcotton.toms-darwin = {
    enable = mkEnableOption "Default configuration for toms darwin machines";

    # Enable or disable the p11-kit timeout overlay fix to prevent tests from timing out
    useP11KitOverlay = mkEnableOption {
      description = "Enables the p11-kit timeout overlay fix to prevent tests from timing out.";
      default = false;
    };
  };

  config = {
    # Apply Optional Configuration
    nixpkgs.overlays = let
      p11KitOverlay = final: prev: {
        p11-kit = prev.p11-kit.overrideAttrs (oldAttrs: {
          mesonCheckFlags = oldAttrs.mesonCheckFlags or [] ++ ["--timeout-multiplier" "0"];
        });
      };
    in
      if cfg.useP11KitOverlay
      then [p11KitOverlay]
      else [];

    # nixpkgs.config.overlays = [
    #   (final: prev:
    #     lib.optionalAttrs (prev.stdenv.system == "aarch64-darwin") {
    #       # Add access to x86 packages system is running Apple Silicon
    #       pkgs-x86 = import nixpkgs {
    #         system = "x86_64-darwin";
    #         config.allowUnfree = true;
    #       };
    #     })
    # ];

    # Common Configuration
    users.users.${variables.primaryUser}.home = "/Users/${variables.primaryUser}";

    system.primaryUser = variables.primaryUser;

    # These are packages are just for darwin systems
    environment.systemPackages = [
      pkgs.kind
      pkgs.xcode-install
    ];

    nixpkgs.config.allowUnfree = true;

    # Run the linux-builder as a background service
    # nix.linux-builder.enable = true;

    # Add needed system-features to the nix daemon
    # Starting with Nix 2.19, this will be automatic
    nix.settings.system-features = [
      "nixos-test"
      "apple-virt"
    ];
    nix.settings.trusted-users = [
      "root"
      "tomcotton"
    ];

    # Keyboard
    system.keyboard.enableKeyMapping = false;
    system.keyboard.remapCapsLockToEscape = false;
    system.keyboard.remapCapsLockToControl = false;

    # Add ability to used TouchID for sudo authentication
    security.pam.services.sudo_local.touchIdAuth = true;

    programs.zsh = {
      enable = true;
      enableCompletion = true;
      promptInit = builtins.readFile ./mac-dot-zshrc;
    };

    homebrew = {
      enable = true;
      # updates homebrew packages on activation,
      # can make darwin-rebuild much slower (otherwise i'd forget to do it ever though)
      onActivation.upgrade = true;

      taps = [
        #
      ];
      brews = [
        # "tailscale"
        "pandoc"
        "trash"
        "yt-dlp"
        "pkgconf"
        "openjdk"
        "docker-compose"
        "ghcup"
        "cabal-install"
      ];
      casks = [
        "claude-code"
        "hiddenbar"
        "plugdata"
        "font-hack-nerd-font"
        "libreoffice"
        "karabiner-elements"
        "mactex"
        "obs"
        "ollama"
        "bambu-studio"
        "fork"
        "alfred"
        "balenaetcher"
        "discord"
        "docker"
        "firefox"
        "istat-menus"
        "iterm2"
        "obsidian"
        "openscad"
        "nuage"
        "spotify"
        "visual-studio-code"
        "vlc"
        "zoom"
        # "unity-hub"
        # "epic-games"
        "steam"
        "tailscale"
        "qmk-toolbox"
        "ghostty"
        "sonic-visualiser"
        "blackhole-16ch"
        "arduino-ide"
        "utm" # Virtualization based on QEMU
        "wine-stable"
        # "xcodes-app" # Manages downloads enabling of xcode versions
        "cryptomator" # encrypts files, used to back up bitwarden
        "zen" # zen browser
        "nikitabobko/tap/aerospace"
      ];
      masApps = {
        # "Xcode" = 497799835;
        #   "Amphetamine" = 937984704;
        # "Bitwarden" = 1352778147;
        #   "Creator's Best Friend" = 1524172135;
        #   "Disk Speed Test" = 425264550;
        #   "iA Writer" = 775737590;
        #   "Microsoft Remote Desktop" = 1295203466;
        #   "Reeder" = 1529448980;
        #   "Resize Master" = 1025306797;
        #   # "Steam Link" = 123;
        # "Tailscale" = 1475387142;
        # "Adobe Photoshop" = 1457771281;
        "Flow - Focus & Pomodoro Timer" = 1423210932;
        # "iStat Menus 7" = 6499559693;
        # "BookPlayer" = 1138219998;

        #   "Telegram" = 747648890;
        #   "The Unarchiver" = 425424353;
        #   "Todoist" = 585829637;
        #   "UTM" = 1538878817;
        #   "Wireguard" = 1451685025;

        #   # these apps with uk apple id
        #   #"Final Cut Pro" = 424389933;
        #   #"Logic Pro" = 634148309;
        #   #"MainStage" = 634159523;
        #   #"Garageband" = 682658836;
        #   #"ShutterCount" = 720123827;
        #   #"Teleprompter" = 1533078079;

        #   "Keynote" = 409183694;
        #   "Numbers" = 409203825;
        #   "Pages" = 409201541;
      };
    };

    /*
       Nonmanaged Apps
    Wwise Launcher: https://www.audiokinetic.com/en/download/
    Epic Games Launcher: https://store.epicgames.com/en-US/download


    */

    # macOS configuration
    # Blocks mac from storing window presence and location. Results in only startup apps at startup.
    #   sudo chown root ~/Library/Preferences/ByHost/com.apple.loginwindow.*
    #   sudo chmod 000 ~/Library/Preferences/ByHost/com.apple.loginwindow.*
    #   echo 'blocking access to ~/Library/Preferences/ByHost/com.apple.loginwindow.*'
    # " "";
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
      NSGlobalDomain.InitialKeyRepeat = 20;
      NSGlobalDomain.KeyRepeat = 2;
      NSGlobalDomain."com.apple.mouse.tapBehavior" = 1;
      LaunchServices.LSQuarantine = false; # disables "Are you sure?" for new apps
      loginwindow.GuestEnabled = false;
      hitoolbox.AppleFnUsageType = null;
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
        DisableAllAnimations = false;
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
        orientation = "bottom";
        tilesize = 50;
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
      #   # Privacy: don???t send search queries to Apple
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
