# Local LLM Guide

This guide covers the local LLM infrastructure running on **nas-01**, which provides two backends (Ollama and llama-swap), a web chat interface (Open WebUI), and CLI tools for interacting with models.

## Architecture Overview

```
                          ┌─────────────────────┐
                          │    Open WebUI        │
                          │    port 3001         │
                          │    tailnet: llm      │
                          └────────┬────────────┘
                                   │ OpenAI API (/v1)
                                   ▼
               ┌───────────────────────────────────┐
               │          llama-swap                │
               │          port 8090                 │
               │   auto-discovers GGUF models       │
               │   from /models ZFS dataset         │
               │   tailnet: llama-swap              │
               └───────────────┬───────────────────┘
                               │ spawns llama-server per model
                               ▼
               ┌───────────────────────────────────┐
               │       llama-cpp (Vulkan)           │
               │   one process per active model     │
               └───────────────────────────────────┘

               ┌───────────────────────────────────┐
               │           Ollama                   │
               │           port 11434               │
               │   ROCm GPU acceleration            │
               │   tailnet: ollama                  │
               └───────────────────────────────────┘
```

**Two independent backends run side-by-side:**

| Service | Port | GPU Backend | API | Use Case |
|---------|------|-------------|-----|----------|
| **Ollama** | 11434 | ROCm | Ollama API | Quick access to curated models |
| **llama-swap** | 8090 | Vulkan | OpenAI-compatible `/v1` | GGUF model library, auto-discovery |
| **Open WebUI** | 3001 | — | Web UI | Chat interface (connects to llama-swap) |

Open WebUI talks to llama-swap by default. Both backends share the same two AMD Radeon AI Pro R9700 GPUs (63.8 GiB combined VRAM).

## Hardware

nas-01 has:
- **2x AMD Radeon AI Pro R9700** (RDNA4 / gfx1201), 31.9 GiB VRAM each
- **252 GiB system RAM** available for CPU offload
- Models stored on a dedicated ZFS dataset: `ssdpool/local/models` mounted at `/models` (500G quota, lz4 compression)

## Getting Started

### Web Chat (Open WebUI)

Open WebUI is available at:
- **LAN:** `http://nas-01:3001`
- **Tailscale:** `https://llm.your-tailnet.ts.net`

Authentication is enabled. On first visit, create an account — the first user becomes admin.

Models available in the Open WebUI dropdown come from llama-swap. Any GGUF file in `/models` is auto-discovered and available.

### Command Line (Ollama)

```bash
# Run a model interactively
ollama run llama3.2:3b

# Run with a prompt
ollama run llama3.1:70b "Summarize the theory of relativity in 3 sentences."

# List available models
ollama list

# Check what's currently loaded in VRAM
ollama ps
```

### Command Line (llm CLI)

The `llm` CLI tool is available via Home Manager with the `llm-ollama` plugin:

```bash
# One-shot prompt via Ollama
llm -m llama3.2:3b "What is NixOS?"

# Pipe input
cat error.log | llm -m llama3.1:70b "Explain this error"
```

## Managing Models

**Ollama and llama-swap maintain separate model storage.** Both live on the `/models` ZFS dataset (`ssdpool/local/models`, 500G quota) to keep them off the root disk:

- **Ollama** stores its blob-based format in `/models/ollama`
- **llama-swap** uses raw `.gguf` files in `/models`

They cannot share files — Ollama can import a GGUF via `echo 'FROM /path/to/file.gguf' | ollama create name -f -`, but it copies the data into its blob store, duplicating disk usage. In practice, manage each model set independently: use `ollama pull` for Ollama and `download-model.sh` for llama-swap.

### Finding Models

The two backends use **different naming schemes and different registries**. You cannot use the same model string for both.

**Ollama** uses its own registry at [ollama.com/library](https://ollama.com/library). Model names are short tags:

```
llama3.1:70b          # model:size
mistral:7b
qwen2.5:72b
deepseek-r1:14b
gemma3:27b-it-q4_K_M  # model:variant
```

Browse available models at `https://ollama.com/library`. Use `ollama pull <name>` to download.

**llama-swap** uses raw GGUF files, typically from [HuggingFace](https://huggingface.co/models?sort=trending&search=gguf). Model names are HuggingFace repo IDs:

```
bartowski/Meta-Llama-3.1-8B-Instruct-GGUF
bartowski/Qwen2.5-72B-Instruct-GGUF
TheBloke/Mistral-7B-Instruct-v0.2-GGUF
```

To find GGUF models on HuggingFace, search for the model name + "GGUF". Popular GGUF uploaders include `bartowski`, `TheBloke`, and `mradermacher`. Use `download-model.sh` to fetch them.

**Same model, different commands:**

| Model | Ollama | llama-swap (download-model.sh) |
|-------|--------|-------------------------------|
| Llama 3.1 8B | `ollama pull llama3.1:8b` | `./scripts/download-model.sh bartowski/Meta-Llama-3.1-8B-Instruct-GGUF Q4_K_M` |
| Qwen 2.5 72B | `ollama pull qwen2.5:72b` | `./scripts/download-model.sh bartowski/Qwen2.5-72B-Instruct-GGUF Q4_K_M` |
| Mistral 7B | `ollama pull mistral:7b` | `./scripts/download-model.sh TheBloke/Mistral-7B-Instruct-v0.2-GGUF Q4_K_M` |

With Ollama you pick a model and it chooses a default quantization. With llama-swap you explicitly choose the quantization (Q4_K_M, Q5_K_M, etc.) — see the quantization table below for guidance.

### Ollama Models

Ollama stores models in `/models/ollama` (configured via `models` option). Models listed in the NixOS config are pulled automatically on service start.

```bash
# Pull a new model
ollama pull mistral:7b

# List installed models
ollama list

# Remove a model
ollama rm mistral:7b

# Show model details (parameters, quantization, size)
ollama show llama3.1:70b
```

To permanently add a model so it's pulled on every service start, add it to the config in `hosts/nixos/nas-01/default.nix`:

```nix
services.clubcotton.ollama = {
  acceleration = "rocm";
  loadModels = ["llama3.1:70b" "llama3.2:3b" "mistral:7b"];
};
```

### llama-swap Models (GGUF Files)

llama-swap auto-discovers any `.gguf` file in `/models`. No config changes needed — just download and restart the service.

**Download with the helper script:**

```bash
# Download a specific quantization from HuggingFace
./scripts/download-model.sh bartowski/Meta-Llama-3.1-8B-Instruct-GGUF Q4_K_M

# Download all quantizations from a repo
./scripts/download-model.sh bartowski/Meta-Llama-3.1-8B-Instruct-GGUF

# Preview what would be downloaded (no actual download)
./scripts/download-model.sh bartowski/Qwen2.5-72B-Instruct-GGUF Q4_K_M --dry-run
```

The script SSHes into nas-01 and uses `hf download` to fetch files directly to `/models`.

**Restart the service to pick up new models:**

```bash
ssh root@nas-01 systemctl restart llama-swap
```

**Verify models are available:**

```bash
curl -s http://nas-01:8090/v1/models | jq '.data[].id'
```

**Remove a model:**

```bash
ssh root@nas-01 rm /models/some-model-Q4_K_M.gguf
ssh root@nas-01 systemctl restart llama-swap
```

### Choosing Quantizations

GGUF models come in different quantization levels trading quality for size:

| Quant | Quality | Size (7B) | Size (70B) | Notes |
|-------|---------|-----------|------------|-------|
| Q8_0 | Best | ~8 GB | ~75 GB | Near-original quality |
| Q6_K | Great | ~6 GB | ~57 GB | Good balance for large VRAM |
| Q5_K_M | Good | ~5 GB | ~49 GB | Recommended general use |
| Q4_K_M | Good | ~4 GB | ~42 GB | Best size/quality tradeoff |
| Q3_K_M | Fair | ~3.5 GB | ~33 GB | For fitting larger models |
| Q2_K | Low | ~3 GB | ~27 GB | Last resort |

With 63.8 GiB VRAM, a 70B Q4_K_M fits entirely on GPU. A 70B Q8_0 would require hybrid mode.

## GPU Offloading and Hybrid Mode

### How It Works

When a model is too large for VRAM, it runs in **hybrid mode** — some layers on GPU, the rest in system RAM. GPU layers run fast, CPU layers run slower, so throughput depends on the split ratio.

### Ollama (Automatic)

Ollama handles this transparently. It detects available VRAM and offloads as many layers as fit. Check the split with:

```bash
ollama ps
```

The `PROCESSOR` column shows the split:
- `100% GPU` — entirely in VRAM
- `48/80 GPU` — 48 of 80 layers on GPU, rest on CPU

### llama-swap (Configurable)

llama-swap's default args include `-ngl 99` (offload up to 99 layers to GPU). llama-cpp automatically caps at the number of layers the model has and what fits in VRAM.

To manually control the split for a specific model, define it statically in `hosts/nixos/nas-01/default.nix` instead of relying on auto-discovery:

```nix
services.clubcotton.llama-swap = {
  port = 8090;
  modelsDir = "/models";
  llamaCppPackage = pkgs.llama-cpp.override {vulkanSupport = true;};
  settings = {
    healthCheckTimeout = 120;
    models = {
      "my-huge-model" = {
        cmd = "llama-server --port \${PORT} -m /models/huge-model-Q8_0.gguf -ngl 40 --split-mode layer --no-webui";
        ttl = 600;
      };
    };
  };
};
```

Adjust `-ngl` (number of GPU layers) to control the split. Lower values put more on CPU. Static config entries take precedence over auto-discovered ones.

### Estimating VRAM Usage

Rough formula: `model_size_on_disk + context_overhead ≈ VRAM needed`

Context overhead depends on context length and is typically 1-4 GB for 4096-8192 context.

With 63.8 GiB total VRAM across two GPUs:
- Models under ~60 GB: fully GPU, no hybrid needed
- Models 60-300 GB: hybrid mode, partial GPU offload
- The 252 GiB system RAM can handle very large models in hybrid

## API Reference

The two backends expose different APIs. When configuring a client, you need to know which protocol it speaks.

### Ollama API

Ollama exposes its own **Ollama API** — a REST API specific to Ollama. Documentation: https://github.com/ollama/ollama/blob/main/docs/api.md

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/api/generate` | POST | Generate a completion (single prompt) |
| `/api/chat` | POST | Chat completion (message history) |
| `/api/pull` | POST | Pull/download a model |
| `/api/list` | GET | List local models |
| `/api/show` | POST | Show model details |
| `/api/ps` | GET | List running models |

Ollama also provides an **OpenAI-compatible endpoint** at `/v1/chat/completions`, so clients that speak OpenAI can use Ollama too.

**Client configuration examples:**

```
# Ollama-native clients
OLLAMA_HOST=http://nas-01:11434

# OpenAI-compatible clients talking to Ollama
OPENAI_API_BASE=http://nas-01:11434/v1
OPENAI_API_KEY=not-needed
```

### OpenAI API (llama-swap)

llama-swap exposes the **OpenAI Chat Completions API** — the same REST API used by OpenAI's GPT models. This is the most widely supported LLM API and works with nearly every client and library. Documentation: https://platform.openai.com/docs/api-reference/chat

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/v1/chat/completions` | POST | Chat completion (primary endpoint) |
| `/v1/models` | GET | List available models |

No API key is required (set to any non-empty string if a client demands one).

**Client configuration examples:**

```
# Standard OpenAI-compatible environment variables
OPENAI_API_BASE=http://nas-01:8090/v1
OPENAI_API_KEY=not-needed

# Python (openai library)
client = OpenAI(base_url="http://nas-01:8090/v1", api_key="not-needed")

# curl
curl http://nas-01:8090/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{"model": "qwen2.5-72b-instruct-q4_k_m", "messages": [{"role": "user", "content": "Hello"}]}'
```

### Which API Should Clients Use?

| Client/Tool | Protocol | Point at |
|-------------|----------|----------|
| Open WebUI | OpenAI API | llama-swap `:8090/v1` (default config) |
| `ollama` CLI | Ollama API | Ollama `:11434` |
| `llm` CLI (llm-ollama plugin) | Ollama API | Ollama `:11434` |
| Python `openai` library | OpenAI API | llama-swap `:8090/v1` or Ollama `:11434/v1` |
| LangChain, LlamaIndex | Either | Depends on provider class used |
| Any "OpenAI-compatible" tool | OpenAI API | llama-swap `:8090/v1` or Ollama `:11434/v1` |
| Continue (VS Code) | OpenAI API | Either `:8090/v1` or `:11434/v1` |

**Rule of thumb:** If a client asks for an "OpenAI base URL", use llama-swap (`http://nas-01:8090/v1`). If it asks for an "Ollama host", use Ollama (`http://nas-01:11434`). Both work for OpenAI-compatible clients, but llama-swap has the larger GGUF model library while Ollama has the curated set.

## Serving Models to Remote Clients

### Via Tailscale

All three services are exposed on the tailnet:

| Hostname | URL | API |
|----------|-----|-----|
| `llm` | `https://llm.your-tailnet.ts.net` | Open WebUI |
| `ollama` | `https://ollama.your-tailnet.ts.net` | Ollama API |
| `llama-swap` | `https://llama-swap.your-tailnet.ts.net` | OpenAI `/v1` |

**Use from any machine on the tailnet:**

```bash
# Ollama API
curl https://ollama.your-tailnet.ts.net/api/generate \
  -d '{"model": "llama3.2:3b", "prompt": "Hello", "stream": false}'

# OpenAI-compatible API (llama-swap)
curl https://llama-swap.your-tailnet.ts.net/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "meta-llama-3.1-8b-instruct-q4_k_m",
    "messages": [{"role": "user", "content": "Hello"}]
  }'
```

### Via LAN

Services are also accessible on the LAN (firewall ports are open by default):

- `http://nas-01:11434` — Ollama
- `http://nas-01:8090` — llama-swap
- `http://nas-01:3001` — Open WebUI

### Using with the llm CLI from Other Machines

Point the `llm` CLI at the remote Ollama or llama-swap:

```bash
# Via Ollama
llm -m llama3.2:3b "Hello" --option host https://ollama.your-tailnet.ts.net

# Or set in llm config for persistent use
llm keys set ollama-host https://ollama.your-tailnet.ts.net
```

### Using as an OpenAI Drop-in

llama-swap's `/v1` endpoint is OpenAI-compatible. Any tool that supports a custom OpenAI base URL can use it:

```bash
export OPENAI_API_BASE=http://nas-01:8090/v1
export OPENAI_API_KEY=not-needed
```

## Monitoring

### GPU Utilization

```bash
# Real-time AMD GPU monitoring
amdgpu_top

# Vulkan device info
vulkaninfo --summary

# PCI device listing
lspci | grep -i vga
```

### Service Status

```bash
# Check service status
systemctl status ollama
systemctl status llama-swap
systemctl status open-webui

# View logs
journalctl -u ollama -f
journalctl -u llama-swap -f
journalctl -u open-webui -f
```

### Model Loading Status

```bash
# Ollama: what's loaded in VRAM
ollama ps

# llama-swap: available models
curl -s http://localhost:8090/v1/models | jq '.data[].id'
```

## Troubleshooting

### Ollama: "entering low vram mode" / "failure during GPU discovery"

ROCm failed to detect the GPUs. Check:
1. `HSA_OVERRIDE_GFX_VERSION` should **not** be set — native gfx1201 support works with ROCm 6.4.3+
2. Verify kernel modules: `lsmod | grep amdgpu`
3. Check device nodes exist: `ls /dev/kfd /dev/dri/render*`

### llama-swap: model not appearing

1. Verify the `.gguf` file is in `/models`: `ls /models/*.gguf`
2. Restart the service: `systemctl restart llama-swap`
3. Check discovery logs: `journalctl -u llama-swap | grep -i discover`

### Model loading is slow

First load of a model compiles GPU kernels (ROCm) or shaders (Vulkan), which can take 30-60 seconds. Subsequent loads from the same session are faster.

### Out of VRAM

If two large models are loaded simultaneously (one in Ollama, one in llama-swap), they compete for VRAM. Options:
- Increase Ollama's `OLLAMA_KEEP_ALIVE` to unload faster (default 5 minutes)
- Reduce llama-swap `defaultTtl` (default 300 seconds)
- Use only one backend at a time for large models

## Configuration Reference

All LLM services are configured in `hosts/nixos/nas-01/default.nix`:

```nix
# Enable services (in the services.clubcotton block)
ollama.enable = true;
llama-swap.enable = true;
open-webui.enable = true;

# Ollama settings
services.clubcotton.ollama = {
  acceleration = "rocm";          # GPU backend: "rocm", "cuda", false, or null
  models = "/models/ollama";      # Store on ZFS dataset, not root disk
  loadModels = ["llama3.1:70b"];  # Auto-pull on start
};

# llama-swap settings
services.clubcotton.llama-swap = {
  port = 8090;
  modelsDir = "/models";                                          # GGUF auto-discovery dir
  llamaCppPackage = pkgs.llama-cpp.override {vulkanSupport = true;};  # GPU backend
  settings = {
    healthCheckTimeout = 120;
    # Static model overrides go in settings.models (see hybrid mode section)
  };
};
```

Model files live on a dedicated ZFS dataset (`ssdpool/local/models`) mounted at `/models` with a 500 GB quota.
