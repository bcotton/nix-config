# LLM Module

Home Manager module for configuring the `llm` CLI tool with plugins.

## Usage

Enable the llm tool in your Home Manager configuration:

```nix
programs.llm = {
  enable = true;

  # Enable specific plugins
  plugins = {
    llm-anthropic = true;      # Claude models
    llm-gemini = true;         # Google Gemini models
    llm-ollama = true;         # Local Ollama models
    llm-openai-plugin = true;  # OpenAI models
  };
};
```

## Available Plugins

The following plugins are available from nixpkgs-unstable (35+ plugins):

### Model Access Plugins
- **llm-anthropic** - Claude models (Anthropic)
- **llm-gemini** - Google Gemini models
- **llm-openai-plugin** - OpenAI models (GPT-3.5, GPT-4, etc.)
- **llm-ollama** - Local Ollama models
- **llm-command-r** - Cohere Command R models
- **llm-deepseek** - Deepseek models
- **llm-grok** - xAI Grok models
- **llm-groq** - Groqcloud models
- **llm-mistral** - Mistral AI models
- **llm-perplexity** - Perplexity AI
- **llm-venice** - Venice AI
- **llm-openrouter** - OpenRouter (access to 100+ models)
- **llm-github-copilot** - GitHub Copilot
- **llm-llama-server** - llama.cpp server

### Tool Plugins
- **llm-cmd** - Generate and execute shell commands
- **llm-git** - AI-powered Git commands
- **llm-jq** - Write and execute jq programs
- **llm-tools-datasette** - Datasette tools
- **llm-tools-quickjs** - Execute JavaScript with QuickJS
- **llm-tools-simpleeval** - Execute Python expressions safely
- **llm-tools-sqlite** - SQLite tools

### Fragment Loaders
- **llm-fragments-github** - Load GitHub repository contents
- **llm-fragments-pypi** - PyPI package metadata
- **llm-fragments-reader** - Jina Reader API integration
- **llm-fragments-symbex** - Python symbol loader

### Templates
- **llm-templates-fabric** - Fabric prompt templates
- **llm-templates-github** - GitHub issue/PR templates

### Media & Documents
- **llm-pdf-to-images** - Convert PDF pages to images
- **llm-video-frames** - Extract frames from videos
- **llm-gguf** - Run GGUF model files

### Utilities
- **llm-docs** - Ask questions of LLM documentation
- **llm-echo** - Debug plugin
- **llm-hacker-news** - Hacker News integration
- **llm-sentence-transformers** - Sentence embeddings

See the full list with URLs in `home/modules/llm.nix`

## How It Works

The module uses the `llm.withPlugins` function from nixpkgs-unstable to build a custom llm installation with the selected plugins. Using unstable gives access to 35+ plugins vs the 7 available in stable. This is the Nix-native way to install llm plugins, as the standard `llm install` command is disabled in the Nix package.

## Example Configuration

```nix
programs.llm = {
  enable = true;

  plugins = {
    # Enable Claude support
    llm-anthropic = true;

    # Enable local model support via Ollama
    llm-ollama = true;

    # Enable command generation
    llm-cmd = true;
  };
};
```

## Adding More Plugins

If additional llm plugins become available in nixpkgs, they can be added to the module by editing `home/modules/llm.nix` and adding them to the `availablePlugins` attrset.

## Disabling the Install Command

Note that `llm install <plugin>` is disabled when llm is installed via Nix. You must configure plugins through this Home Manager module instead. This ensures reproducible and declarative configuration of your llm installation.
