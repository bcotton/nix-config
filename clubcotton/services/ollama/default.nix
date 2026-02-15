{
  config,
  lib,
  ...
}:
with lib; let
  service = "ollama";
  cfg = config.services.clubcotton.${service};
  clubcotton = config.clubcotton;
in {
  options.services.clubcotton.${service} = {
    enable = mkEnableOption "Ollama server for local large language models";

    host = mkOption {
      type = types.str;
      default = "0.0.0.0";
      description = "The host address which the ollama server listens to.";
    };

    port = mkOption {
      type = types.port;
      default = 11434;
      description = "Which port the ollama server listens to.";
    };

    acceleration = mkOption {
      type = types.nullOr (types.enum [false "rocm" "cuda"]);
      default = null;
      description = "What interface to use for hardware acceleration (null, false, rocm, cuda).";
    };

    models = mkOption {
      type = types.str;
      default = "${config.services.ollama.home}/models";
      defaultText = literalExpression ''"''${config.services.ollama.home}/models"'';
      description = "Directory for ollama model storage.";
    };

    loadModels = mkOption {
      type = types.listOf types.str;
      default = [];
      description = "Models to automatically pull on service start.";
    };

    environmentVariables = mkOption {
      type = types.attrsOf types.str;
      default = {};
      description = "Extra environment variables for the ollama service.";
    };

    openFirewall = mkOption {
      type = types.bool;
      default = true;
      description = "Whether to open the firewall port for ollama.";
    };

    tailnetHostname = mkOption {
      type = types.nullOr types.str;
      default = "${service}";
      description = "The tailnet hostname to expose the service as.";
    };

    homepage.name = mkOption {
      type = types.str;
      default = "Ollama";
    };
    homepage.description = mkOption {
      type = types.str;
      default = "Local large language model server";
    };
    homepage.icon = mkOption {
      type = types.str;
      default = "ollama.svg";
    };
    homepage.category = mkOption {
      type = types.str;
      default = "Infrastructure";
    };
  };

  config = mkIf cfg.enable {
    services.ollama = {
      enable = true;
      host = cfg.host;
      port = cfg.port;
      acceleration = cfg.acceleration;
      models = cfg.models;
      loadModels = cfg.loadModels;
      environmentVariables = cfg.environmentVariables;
      openFirewall = cfg.openFirewall;
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
