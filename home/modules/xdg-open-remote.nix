{
  config,
  lib,
  pkgs,
  localPackages,
  ...
}:
with lib; let
  cfg = config.programs.xdg-open-remote;
in {
  options.programs.xdg-open-remote = {
    enable = mkEnableOption "xdg-open-remote - open URLs in remote browser via SSH tunnel";

    port = mkOption {
      type = types.port;
      default = 7890;
      description = "Port where browser-opener listens (via SSH RemoteForward)";
    };

    setAsDefault = mkOption {
      type = types.bool;
      default = true;
      description = "Whether to set xdg-open-remote as the default browser opener";
    };
  };

  config = mkIf (cfg.enable && pkgs.stdenv.isLinux) {
    home.packages = [
      localPackages.xdg-open-remote
      # Create xdg-open wrapper so programs using Process.find_executable can find it
      # (shell aliases don't work for programs that search PATH directly)
      (pkgs.writeShellScriptBin "xdg-open" ''
        exec ${localPackages.xdg-open-remote}/bin/xdg-open-remote "$@"
      '')
    ];

    # Set environment variables
    home.sessionVariables = {
      REMOTE_BROWSER_PORT = toString cfg.port;
      # Set BROWSER so CLI tools like gh, glab, etc. use xdg-open-remote
      BROWSER = "${localPackages.xdg-open-remote}/bin/xdg-open-remote";
    };

    # Create a desktop entry to make xdg-open-remote available as a browser option
    xdg.desktopEntries = mkIf cfg.setAsDefault {
      xdg-open-remote = {
        name = "Remote Browser";
        genericName = "Web Browser";
        exec = "${localPackages.xdg-open-remote}/bin/xdg-open-remote %u";
        terminal = false;
        categories = ["Network" "WebBrowser"];
        mimeType = [
          "text/html"
          "text/xml"
          "application/xhtml+xml"
          "x-scheme-handler/http"
          "x-scheme-handler/https"
        ];
      };
    };

    # Set xdg-open-remote as the default handler for web URLs
    xdg.mimeApps = mkIf cfg.setAsDefault {
      enable = true;
      defaultApplications = {
        "text/html" = "xdg-open-remote.desktop";
        "x-scheme-handler/http" = "xdg-open-remote.desktop";
        "x-scheme-handler/https" = "xdg-open-remote.desktop";
      };
    };
  };
}
