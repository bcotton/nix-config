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

  settingsFormat = pkgs.formats.yaml {};
  staticConfigFile = settingsFormat.generate "llama-swap-static.yaml" cfg.settings;

  llama-cpp-pkg =
    if cfg.llamaCppPackage != null
    then cfg.llamaCppPackage
    else pkgs.llama-cpp;
  llama-server = lib.getExe' llama-cpp-pkg "llama-server";

  discoveryScript = pkgs.writeShellScript "llama-swap-discover-models" ''
    set -euo pipefail

    MODELS_DIR="${cfg.modelsDir}"
    CONFIG="/run/llama-swap/config.yaml"
    YQ="${pkgs.yq-go}/bin/yq"

    # Start from the static nix-generated config (install with writable perms since nix store is 444)
    install -m 644 ${staticConfigFile} "$CONFIG"

    if [ ! -d "$MODELS_DIR" ]; then
      echo "Models directory $MODELS_DIR does not exist, using static config only"
      exit 0
    fi

    shopt -s nullglob
    gguf_files=("$MODELS_DIR"/*.gguf)
    shopt -u nullglob

    if [ ''${#gguf_files[@]} -eq 0 ]; then
      echo "No .gguf files found in $MODELS_DIR, using static config only"
      exit 0
    fi

    for gguf in "''${gguf_files[@]}"; do
      basename_noext=$(basename "$gguf" .gguf)

      # Skip non-first shards of split models (e.g., model-00002-of-00003.gguf)
      if [[ "$basename_noext" =~ -[0-9]+-of-[0-9]+$ ]]; then
        if ! [[ "$basename_noext" =~ -00001-of-[0-9]+$ ]]; then
          continue
        fi
        # Extract model base name (remove -00001-of-NNNNN suffix)
        model_name=$(echo "$basename_noext" | sed 's/-00001-of-[0-9]*$//' | tr '[:upper:]' '[:lower:]')
      else
        model_name=$(echo "$basename_noext" | tr '[:upper:]' '[:lower:]')
      fi

      # Skip if already defined in static config
      if $YQ -e ".models.\"$model_name\"" "$CONFIG" >/dev/null 2>&1; then
        echo "Skipping $model_name (defined in static config)"
        continue
      fi

      echo "Auto-discovered model: $model_name -> $gguf"
      export MODEL_CMD="${llama-server} --port \''${PORT} -m $gguf ${cfg.defaultModelArgs}"
      $YQ -i ".models.\"$model_name\".cmd = strenv(MODEL_CMD)" "$CONFIG"
      $YQ -i ".models.\"$model_name\".ttl = ${toString cfg.defaultTtl}" "$CONFIG"
    done

    echo "Final llama-swap config:"
    cat "$CONFIG"
  '';
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
        Statically-defined models here take precedence over auto-discovered ones.
        See https://github.com/mostlygeek/llama-swap for configuration options.
      '';
    };

    modelsDir = mkOption {
      type = types.nullOr types.str;
      default = null;
      description = ''
        Directory to scan for .gguf model files at service start.
        Auto-discovered models are merged with statically-defined settings.models.
        Static entries take precedence over auto-discovered ones.
        Set to null to disable auto-discovery.
      '';
    };

    llamaCppPackage = mkOption {
      type = types.nullOr types.package;
      default = null;
      description = ''
        llama-cpp package to use for auto-discovered model commands.
        If null, uses the default pkgs.llama-cpp.
      '';
    };

    defaultModelArgs = mkOption {
      type = types.str;
      default = "-ngl 99 --split-mode layer --no-webui";
      description = "Default arguments appended to llama-server command for auto-discovered models.";
    };

    defaultTtl = mkOption {
      type = types.int;
      default = 300;
      description = "Default TTL (in seconds) for auto-discovered models before unloading.";
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

    # Dynamic model discovery: override systemd service to scan modelsDir at startup
    systemd.services.llama-swap = mkIf (cfg.modelsDir != null) {
      path = with pkgs; [coreutils gnused];
      serviceConfig = {
        RuntimeDirectory = "llama-swap";
        ExecStartPre = ["${discoveryScript}"];
        ExecStart = mkForce "${lib.getExe config.services.llama-swap.package} --listen :${toString cfg.port} --config /run/llama-swap/config.yaml";
      };
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
