---
name: lemonade-server
description: Configure and optimize AMD Lemonade Server for local LLM inference on Strix Halo / AMD hardware — backend selection, ROCm/Vulkan config, speculative decoding, and custom llama.cpp args.
version: 1.0.0
author: Hermes Agent
license: MIT
platforms: [linux, windows]
metadata:
  hermes:
    tags: [lemonade, amd, strx-halo, llama-cpp, speculative-decoding, local-ai, inference]
---

# Lemonade Server Configuration

Configure and optimize AMD Lemonade Server for local LLM inference, specifically on Strix Halo / AMD hardware (gfx1151, Ryzen AI MAX+ 395, 128 GB unified memory).

## Quick Config

All settings are managed via the `lemonade config` CLI. Changes apply immediately and persist to `config.json`.

```bash
# List all current config values
lemonade config list

# Set backend (vulkan, rocm, cpu, or auto)
lemonade config set llamacpp.backend=vulkan

# Switch ROCm channel
lemonade config set rocm_channel=nightly

# Pin to specific nightly build
lemonade config set llamacpp.rocm_bin=b9990

# Pass custom llama.cpp args (see speculative decoding section)
lemonade load <model-name> --llamacpp-args "<args>"
```

## Backend Selection (Strix Halo)

| Backend | Best For | Notes |
|---|---|---|
| **Vulkan** (recommended) | Strix Halo gfx1151 | Primary GPU path; ROCm official support for Strix Halo is incomplete |
| **ROCm** | Discrete AMD GPUs (RDNA2/3/4) | Best for RX 6000/7000/9000 series; check `rocm-smi` after upgrade |
| **CPU** | Testing / small models | Universal fallback, slowest option |
| **Auto** | Default | Picks based on available hardware; usually Vulkan on Strix Halo |

**Default on ARM64 Linux:** Vulkan. On x86 with discrete AMD GPU: ROCm preferred.

## ROCm Configuration

### Stable vs Nightly Channel

```bash
# Switch to nightly for latest ROCm driver stack (e.g. ROCm 7.12+)
lemonade config set rocm_channel=nightly

# Pin to specific nightly build
lemonade config set llamacpp.rocm_bin=b1260

# Switch back to stable
lemonade config set rocm_channel=stable
```

### ROCm 7.12 Performance Boost

A combined AMD firmware update + ROCm 7.12 driver roll-out delivered **~40% inference speedup** for Vulkan-backed llama.cpp on Strix Halo with Qwen 3.5 35B. Verify after update:

```bash
# Check ROCm version
rocm-smi --showdriverversion

# Check Vulkan detection
lemonade status
```

If on an older ROCm/Vulkan driver stack, update to gain the speedup.

## Speculative Decoding

Speculative decoding is particularly well-suited for Strix Halo: models run from shared LPDDR5X memory (memory bandwidth bottleneck), so GPU compute is idle during standard decoding. The batched verification step exploits spare RDNA 3.5 compute to extract multiple accepted tokens from a single memory pass over weights.

**Feature status:** Native UI integration is in [Draft PR #1638](https://github.com/lemonade-sdk/lemonade/pull/1638) — not yet merged. Use custom args (below) today.

### N-gram / Self-Speculative (Draft-Free)

Uses pattern matching in the prompt to guess upcoming tokens. No draft model needed, minimal overhead, typically ~2× speedup on Strix Halo.

```bash
lemonade load <model-name> --llamacpp-args "--spec-type ngram-mod --spec-ngram-size-n 24 --draft-min 48 --draft-max 64"
```

**Parameters:**
- `--spec-type ngram-mod` — modified n-gram method (better than simple for most models)
- `--spec-ngram-size-n 24` — number of n-grams to consider
- `--draft-min 48` — minimum draft tokens
- `--draft-max 64` — maximum draft tokens

**Benchmark:** GLM 4.7 Flash went from ~50 tok/s → ~120 tok/s (2.4×). Similar gains expected on Qwen models.

### MTP — Multi-Token Prediction (Qwen Native Heads)

Qwen3.6 models have built-in prediction heads. MTP uses these heads to draft multiple tokens per step — no separate draft model needed, memory-efficient for 128 GB unified memory.

```bash
lemonade load <model-name> --llamacpp-args "--flash-attn --mtp"
```

**Parameters:**
- `--flash-attn` — flash attention optimization
- `--mtp` — multi-token prediction (uses model's native heads)

**Benchmark:** Qwen3.6 35B-A3B on Strix Halo: ~90-110 tok/s vs ~35-45 tok/s baseline (2.4× speedup). Best results with IQ4_XS-Q8nextn quantization.

### Draft Models (Secondary Smaller Model)

Uses a secondary, much smaller model to guess the next tokens. More compute overhead than n-gram but can yield higher acceptance rates for some models. Requires loading both a main model and a draft model.

Not recommended for Strix Halo in most cases — n-gram and MTP provide comparable or better speedups with zero extra memory cost.

## Custom llama.cpp Args

Any `lemonade load` command accepts `--llamacpp-args` to pass arbitrary flags to the underlying llama.cpp `llama-server`:

```bash
lemonade load Qwen3.6-35B-A3B-GGUF --llamacpp-args "--flash-attn --mtp --spec-type ngram-mod --spec-ngram-size-n 24"
```

Common useful args:
- `--flash-attn on` — flash attention (recommended for GPU inference)
- `--no-mmap` — don't memory-map the model (reduces peak file descriptors)
- `--ctx-size 8192` — context window size (default varies by model)
- `--gpu-layers 999` — offload all layers to GPU

## Model Loading Workflow

```bash
# Check what models are loaded
lemonade models list

# Load a model (from HuggingFace or local path)
lemonade load Qwen3.6-35B-A3B-GGUF --llamacpp-args "<args>"

# Start/restart the server (loads the most recent model)
lemonade start

# Check status
lemonade status
```

## Troubleshooting

### Backend not detected
```bash
# Check what Lemonade sees
lemonade status

# Force Vulkan backend
lemonade config set llamacpp.backend=vulkan
```

### Vulkan showing poor performance
- Update ROCm driver stack (aim for 7.12+ on Linux)
- Verify Vulkan backend is actually being used (not falling back to CPU)
- Try `--flash-attn` flag
- Pin to a newer nightly: `lemonade config set llamacpp.rocm_bin=<latest-tag>`

### Speculative decoding not helping
- Try `ngram-mod` instead of `ngram-simple` for better acceptance rates
- Adjust `--draft-min`/`--draft-max` (higher = more aggressive, less overhead)
- MTP only works with Qwen models that have native prediction heads
- DFlash (block-diffusion speculative decoding) is in llama.cpp master (b9967+) but requires rebuilding from source — not currently exposed via Lemonade

### Model fails to load
- Check GPU memory with `lemonade status`
- Try a smaller quantization (Q4 instead of Q8)
- Reduce `--ctx-size`
- Set `llamacpp.backend=cpu` to test CPU-only loading

## References

- [Speculative decoding status and benchmarks](references/speculative-decoding-status.md) — detailed tracking of PR #1638 status, all spec decoding methods, architecture rationale
- [Lemonade Server docs](https://lemonade-server.ai/docs/guide/configuration/llamacpp/)
- [llama.cpp speculative decoding docs](https://github.com/ggml-org/llama.cpp/blob/master/docs/speculative.md)
