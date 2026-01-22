{
  pkgs,
  lib,
  config,
  unstablePkgs,
  ...
}: let
  cfg = config.programs.llm;

  # Available plugins from nixpkgs-unstable (many more than stable)
  availablePlugins = {
    llm-anthropic = {
      description = "LLM access to models by Anthropic, including the Claude series";
      url = "https://github.com/simonw/llm-anthropic";
    };
    llm-cmd = {
      description = "Use LLM to generate and execute commands in your shell";
      url = "https://github.com/simonw/llm-cmd";
    };
    llm-command-r = {
      description = "Access the Cohere Command R family of models";
      url = "https://github.com/simonw/llm-command-r";
    };
    llm-deepseek = {
      description = "LLM plugin providing access to Deepseek models";
      url = "https://github.com/abrasumente233/llm-deepseek";
    };
    llm-docs = {
      description = "Ask questions of LLM documentation using LLM";
      url = "https://github.com/simonw/llm-docs";
    };
    llm-echo = {
      description = "Debug plugin for LLM";
      url = "https://github.com/simonw/llm-echo";
    };
    llm-fragments-github = {
      description = "Load GitHub repository contents as LLM fragments";
      url = "https://github.com/simonw/llm-fragments-github";
    };
    llm-fragments-pypi = {
      description = "LLM fragments plugin for PyPI packages metadata";
      url = "https://github.com/samueldg/llm-fragments-pypi";
    };
    llm-fragments-reader = {
      description = "Run URLs through the Jina Reader API";
      url = "https://github.com/simonw/llm-fragments-reader";
    };
    llm-fragments-symbex = {
      description = "LLM fragment loader for Python symbols";
      url = "https://github.com/simonw/llm-fragments-symbex";
    };
    llm-gemini = {
      description = "LLM plugin to access Google's Gemini family of models";
      url = "https://github.com/simonw/llm-gemini";
    };
    llm-gguf = {
      description = "Run models distributed as GGUF files using LLM";
      url = "https://github.com/simonw/llm-gguf";
    };
    llm-git = {
      description = "AI-powered Git commands for the LLM CLI tool";
      url = "https://github.com/OttoAllmendinger/llm-git";
    };
    llm-github-copilot = {
      description = "LLM plugin providing access to GitHub Copilot";
      url = "https://github.com/jmdaly/llm-github-copilot";
    };
    llm-grok = {
      description = "LLM plugin providing access to Grok models using the xAI API";
      url = "https://github.com/Hiepler/llm-grok";
    };
    llm-groq = {
      description = "LLM plugin providing access to Groqcloud models";
      url = "https://github.com/angerman/llm-groq";
    };
    llm-hacker-news = {
      description = "Hacker News plugin for LLM";
      url = "https://github.com/simonw/llm-hacker-news";
    };
    llm-jq = {
      description = "Write and execute jq programs with the help of LLM";
      url = "https://github.com/simonw/llm-jq";
    };
    llm-llama-server = {
      description = "LLM plugin for llama.cpp server";
      url = "https://github.com/simonw/llm-llama-server";
    };
    llm-mistral = {
      description = "LLM plugin for Mistral AI models";
      url = "https://github.com/simonw/llm-mistral";
    };
    llm-ollama = {
      description = "LLM plugin providing access to Ollama models using HTTP API";
      url = "https://github.com/simonw/llm-ollama";
    };
    llm-openai-plugin = {
      description = "OpenAI plugin for LLM";
      url = "https://github.com/simonw/llm-openai-plugin";
    };
    llm-openrouter = {
      description = "LLM plugin for OpenRouter";
      url = "https://github.com/simonw/llm-openrouter";
    };
    llm-pdf-to-images = {
      description = "Convert PDF pages to images for LLM";
      url = "https://github.com/simonw/llm-pdf-to-images";
    };
    llm-perplexity = {
      description = "LLM plugin for Perplexity AI";
      url = "https://github.com/simonw/llm-perplexity";
    };
    llm-sentence-transformers = {
      description = "LLM plugin for sentence transformers embeddings";
      url = "https://github.com/simonw/llm-sentence-transformers";
    };
    llm-templates-fabric = {
      description = "Fabric prompt templates for LLM";
      url = "https://github.com/simonw/llm-templates-fabric";
    };
    llm-templates-github = {
      description = "GitHub issue and PR templates for LLM";
      url = "https://github.com/simonw/llm-templates-github";
    };
    llm-tools-datasette = {
      description = "LLM tools for Datasette";
      url = "https://github.com/simonw/llm-tools-datasette";
    };
    llm-tools-quickjs = {
      description = "Execute JavaScript code with QuickJS";
      url = "https://github.com/simonw/llm-tools-quickjs";
    };
    llm-tools-simpleeval = {
      description = "Execute Python expressions safely";
      url = "https://github.com/simonw/llm-tools-simpleeval";
    };
    llm-tools-sqlite = {
      description = "LLM tools for SQLite";
      url = "https://github.com/simonw/llm-tools-sqlite";
    };
    llm-venice = {
      description = "LLM plugin for Venice AI";
      url = "https://github.com/simonw/llm-venice";
    };
    llm-video-frames = {
      description = "Extract frames from videos for LLM";
      url = "https://github.com/simonw/llm-video-frames";
    };
  };

  # Generate options for each plugin
  pluginOptions = lib.mapAttrs (name: info:
    lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "${info.description} <${info.url}>";
    })
  availablePlugins;

  # Get list of enabled plugins
  enabledPlugins = lib.filterAttrs (name: enabled: enabled) cfg.plugins;

  # Build the llm package with selected plugins from unstable
  llmWithPlugins = unstablePkgs.llm.withPlugins (
    lib.mapAttrs' (name: _: lib.nameValuePair name true) enabledPlugins
  );
in {
  options.programs.llm = {
    enable = lib.mkEnableOption "llm CLI tool with plugin support";

    plugins = pluginOptions;

    package = lib.mkOption {
      type = lib.types.package;
      default =
        if enabledPlugins != {}
        then llmWithPlugins
        else unstablePkgs.llm;
      defaultText = lib.literalExpression "unstablePkgs.llm.withPlugins { ... }";
      description = "The llm package to use (from unstable). Automatically configured with selected plugins.";
    };
  };

  config = lib.mkIf cfg.enable {
    home.packages = [cfg.package];
  };
}
