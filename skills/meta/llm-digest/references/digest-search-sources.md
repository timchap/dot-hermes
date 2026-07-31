# LLM Digest — Search Sources & Patterns

Condensed from multiple digest runs (July 2026). Documented as a knowledge bank for future sessions to avoid re-discovering these sources.

## Key Search Sources

### HuggingFace Trending Models
- **URL:** `https://huggingface.co/models?sort=trending`
- **What it shows:** Top models by downloads/downloads velocity, filterable by pipeline tag (text-generation, image-text-to-text, etc.) and library (GGUF, llama.cpp, Ollama, Transformers.js).
- **How to use:** Extract with `web_extract`. Filter for GGUF/llama.cpp/Ollama tags to find models locally relevant. Look for models in the 3B–100B parameter range for Strix Halo (128 GB unified memory).
- **Note:** The "Trending Papers" page (`huggingface.co/papers/trending`) also surfaces emerging models early.

### HuggingFace GGUF Library
- **URL:** `https://huggingface.co/models?library=gguf`
- **Useful for:** Finding quantized versions of new models across GGUF distributors.

### Reddit r/LocalLLaMA
- **URL pattern:** `https://www.reddit.com/r/LocalLLaMA/search/?q=MODEL_NAME+STRIX+halo&sort=new`
- **What to search:** Model-specific Strix Halo reports, Vulkan vs ROCm comparisons, llama.cpp build discussions.
- **Filter by:** "new" sort for recent findings. Look for benchmark threads and setup guides.

### r/StrixHalo
- **Community reports of running large models** (122B+ on 128 GB UMA). Good for sanity-checking whether a new model could fit the user's setup.

### r/ROCm
- **ROCm-specific issues** and user benchmarks. Watch for gfx1151-native support additions.

### llama.cpp GitHub
- **Releases:** `https://github.com/ggml-org/llama.cpp/releases` — daily builds, check for Vulkan/ROCm binary updates.
- **Discussions:** `https://github.com/ggml-org/llama.cpp/discussions` — pre-release analysis for new model architectures (Kimi K3, etc.). These often show readiness before the model ships.
- **Issues:** `https://github.com/ggml-org/llama.cpp/issues` — bug reports that may affect Strix Halo.

### Ollama Releases
- **URL:** `https://github.com/ollama/ollama/releases`
- **Watch for:** Version bumps, new model additions to library, vendored llama.cpp version updates (critical for Vulkan users since Ollama ships a baked-in llama.cpp).

### ROCm Blog & Releases
- **Blog:** `https://rocm.blogs.amd.com/` — major release announcements, new hardware support.
- **Releases:** `https://github.com/ROCm/ROCm/releases` — look for gfx1151 (Strix Halo) GPU support additions.

### Lemonade Server
- **Releases:** `https://github.com/lemonade-sdk/lemonade/releases` — prebuilt llama.cpp-rocm packages targeting gfx1151.
- **llamacpp-rocm:** `https://github.com/lemonade-sdk/llamacpp-rocm/releases` — ROCm prebuilts specifically for Strix Halo.

### Framework Community
- **URL:** `https://community.frame.work/` — official guides from Framework for their hardware (Strix Halo Desktop).
- **Key threads:** LLM inference guides, GPU setup, Vulkan/ROCm config.

## Dedup Patterns

### What to de-duplicate against
1. **Model names** — If a model was "recommended to watch" in the last 7 days, don't re-report it unless something NEW happened (new quant, new benchmark, new availability).
2. **Tool version bumps** — llama.cpp daily builds, Ollama patch releases. Only report if there's a notable feature change, not version number bumps alone.
3. **ROCm versions** — Track the current "stable" ROCm. Report new ROCm versions only if they add Strix Halo support or fix something relevant.
4. **Vulkan vs ROCm benchmarks** — These have been a consistent theme across many digests. Report only when there's a new driver release, firmware update, or a dramatic (>20%) performance change.

### When to skip (even if technically new)
- 1T+ parameter models without any quantization variant under ~120 GB.
- Cloud-only services with no local inference path.
- Models that require multi-GPU PCIe setups (the user has a single iGPU).
- Anything already flagged as "[WATCH]" in the last 7 days without new developments.
