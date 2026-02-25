{
  config,
  lib,
  pkgs,
  ...
}:
with lib; let
  service = "llama-swap";
  cfg = config.services.clubcotton.${service};
  clubcotton = config.clubcotton;
in {
  options.services.clubcotton.${service} = {
    enable = mkEnableOption "llama-swap proxy for automatic LLM model swapping";

    port = mkOption {
      type = types.port;
      default = 8080;
      description = "Which port the llama-swap server listens on.";
    };

    settings = mkOption {
      type = types.attrs;
      default = {};
      description = ''
        llama-swap configuration as a Nix attribute set.
        Converted to YAML and passed to llama-swap.
        See https://github.com/mostlygeek/llama-swap for configuration options.
      '';
      example = literalExpression ''
        {
          healthCheckTimeout = 120;
          models = {
            "llama-3.1-8b" = {
              cmd = "llama-server --port \''${PORT} -m /models/llama-3.1-8b.gguf -ngl 99 --no-webui";
              ttl = 300;
            };
          };
        }
      '';
    };

    openFirewall = mkOption {
      type = types.bool;
      default = true;
      description = "Whether to open the firewall port for llama-swap.";
    };

    tailnetHostname = mkOption {
      type = types.nullOr types.str;
      default = "${service}";
      description = "The tailnet hostname to expose the service as.";
    };

    homepage.name = mkOption {
      type = types.str;
      default = "llama-swap";
    };
    homepage.description = mkOption {
      type = types.str;
      default = "LLM model swapping proxy";
    };
    homepage.icon = mkOption {
      type = types.str;
      default = "llama.svg";
    };
    homepage.category = mkOption {
      type = types.str;
      default = "Infrastructure";
    };
  };

  config = mkIf cfg.enable {
    services.llama-swap = {
      enable = true;
      port = cfg.port;
      openFirewall = cfg.openFirewall;
      settings = cfg.settings;
    };

    services.tsnsrv = mkIf (cfg.tailnetHostname != null && cfg.tailnetHostname != "") {
      enable = true;
      defaults.authKeyPath = clubcotton.tailscaleAuthKeyPath;

      services."${cfg.tailnetHostname}" = {
        ephemeral = true;
        toURL = "http://127.0.0.1:${toString cfg.port}/";
      };
    };
  };
}
