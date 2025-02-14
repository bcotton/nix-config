# This is a NixOS module file that defines a service configuration for Open WebUI
# NixOS modules are the building blocks of system configuration, allowing you to
# define reusable and composable pieces of configuration
# Module arguments are passed as an attribute set (similar to an object in other languages)
{
  # Standard module arguments:
  pkgs, # The nixpkgs package set, containing all standard packages
  unstablePkgs, # Access to newer package versions from nixpkgs-unstable
  lib, # The nixpkgs library of helper functions
  config, # The complete system configuration
  ... # Allows for additional arguments to be passed
}:
# 'with lib' brings library functions into scope so we can use them directly
# This is a common pattern in Nix modules to avoid prefixing everything with 'lib.'
with lib; let
  # 'let ... in' is a way to define local variables in Nix
  # This is a common pattern in NixOS modules to create a shorter name for accessing
  # the module's configuration options
  cfg = config.services.clubcotton.open-webui;
  clubcotton = config.clubcotton;
in {
  # Every NixOS module typically has two main sections:
  # 1. options - Declares the configuration interface
  # 2. config - Implements the actual configuration based on the options

  # The options section defines all configuration options for this module
  # These become available in your system configuration's services.clubcotton.open-webui.<option>
  options.services.clubcotton.open-webui = {
    # mkEnableOption is a helper function that creates a boolean option
    # This is the standard way to make a service enableable/disableable
    enable = mkEnableOption "Open WebUI database support";

    # mkOption is the general way to declare configuration options
    # Each option requires a type and can have defaults and description
    package = mkOption {
      # types.package indicates this option expects a Nix package
      type = types.package;
      # default value comes from unstable package set for newer features
      default = unstablePkgs.open-webui.override {
        python312 = pkgs.python312;
      };
      description = "Open WebUI package to use.";
    };

    # This option allows setting environment variables
    # types.attrsOf creates a type for an attribute set (like a dictionary)
    # where all values must match the given type (in this case, strings)
    environment = mkOption {
      type = types.attrsOf types.str;
      default = {};
      description = "Environment variables to set.";
    };

    # Option for specifying a file containing secret environment variables
    # types.nullOr allows the option to be either null or the specified type
    environmentFile = mkOption {
      type = types.nullOr types.path;
      # References another service's configuration (agenix secrets)
      default = config.age.secrets.open-webui.path;
      description = "Path to the age secret for the secret environment.";
    };

    # Directory for persistent storage
    stateDir = mkOption {
      type = types.path;
      default = "/var/lib/open-webui";
      description = "State directory for Open WebUI.";
    };

    tailnetHostname = mkOption {
      type = types.str;
      default = "";
      description = "The tailnet hostname to expose the code-server as.";
    };
  };

  # The config section defines the actual implementation
  # mkIf is a conditional configuration - it only applies if the condition is true
  # This is how we make the entire configuration dependent on enable = true
  config = mkIf cfg.enable {
    # Configure the base Open WebUI service
    # This references another NixOS module (services.open-webui)
    services.open-webui = {
      enable = true;
      package = cfg.package;
      host = "0.0.0.0"; # Listen on all interfaces for Tailscale access
      port = 3000; # Default port for open-webui
      inherit (cfg) stateDir environment environmentFile;
    };

    # Expose this code-server as a host on the tailnet if tsnsrv module is available
    services.tsnsrv = {
      enable = true;
      defaults.authKeyPath = clubcotton.tailscaleAuthKeyPath;

      services."${cfg.tailnetHostname}" = mkIf (cfg.tailnetHostname != "") {
        ephemeral = true;
        toURL = "http://${config.services.open-webui.host}:${toString config.services.open-webui.port}/";
      };
    };
  };
}
