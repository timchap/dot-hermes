# Strix Halo LLM Optimizations — Reference

Quick-reference for llama.cpp optimization opportunities on gfx1151 / Ryzen AI MAX+ 395 / 128 GB unified memory.

## DFlash Speculative Decoding

- **What:** Block-diffusion draft-model speculative decoding. Merged into llama.cpp master ~July 2026 (PR #22105, refinements #25110, #25246).
- **Impact:** ~2× speedup on Gemma 4 31B on RTX 4090. On Strix Halo with Vulkan, expect meaningful improvement for Qwen3.6 27B and similar dense models.
- **Install:** Rebuild llama.cpp from master (b9967+):
  ```bash
  pip install -U llama-cpp-python --no-cache-dir --force-reinstall --no-deps
  ```
  Or build from source: clone `https://github.com/ggml-org/llama.cpp`, ensure `llama.cpp` master branch.
- **Run:** `llama-cli -m target-model.gguf -md draft-model.gguf` (draft model shares tokenizer with target).

## MTP (Multi-Token Prediction) — Qwen3.6 27B

- **Landed:** llama.cpp PR #22673 (commit 4f13cb7, May 16, 2026).
- **Strix Halo benchmark:** 2.44× speedup over non-MTP baseline.
- **Run:** `llama-server -hf "Qwen/Qwen3.6-27B" --flash-attn --mtp`
- **Context note:** Full 262K context on 128 GB; MTP may reduce effective context to ~137K. Monitor VRAM usage.

## HIP Engine Fork (Vulkan)

- **Source:** Community fork tuned for RDNA3/RDNA4 including Strix Halo (gfx1151).
- **Impact:** ~10% faster decode/token generation vs vanilla llama.cpp Vulkan. >2× faster prefill/prompt processing.
- **See:** [Framework Community post](https://community.frame.work/t/hipengine-fast-native-qwen-3-6-inference-for-rdna3-including-strix-halo/82803)
- **Note:** Primarily tuned on gfx1100 (W7900/7900 XTX) initially; gfx1151 support available.

## Vulkan vs ROCm on Strix Halo

- Vulkan (RADV) generally outperforms ROCm for llama.cpp on gfx1151.
- ROCm requires rocminfo GPU detection post-upgrade; Ollama v0.31+ dropped some legacy AMD GPUs but gfx1151 should remain supported.
- Dual-backend workflow is the norm — test both and pick based on model and workload.
- Environment: `LLAMA_VK_VISIBLE_DEVICES=0` to control Vulkan device selection.

## Quantization Notes for 128 GB

- **Qwen3.6 27B:** Q4_K_M fits ~18 GB, Q8_0 ~29 GB. Plenty of headroom for context.
- **DeepSeek V4-Flash (284B):** IQ2XXS selective quantization → ~81 GB. Fits in 128 GB. Use with ROCm backend.
- **Qwen3.6 35B-A3B MoE:** AWQ variants available (~24 GB for coding variant). MTP supported.

## Key Version Reference (as of 2026-07-11)

| Tool | Latest | Notes |
|------|--------|-------|
| Hermes Agent | v0.18.2 | v2026.7.7.2, ships ~biweekly |
| Ollama | v0.31.1 | Native agent harness, dropped legacy ROCm GPUs |
| llama.cpp | b9967 | DFlash, MTP, ROCm/Vulkan hardening |
| Lemonade SDK | ~10.x | NPU backend (FastFlowLM v0.9.35 Linux) |
| ROCm | 7.2.0 | Strix Halo system optimization docs available |

## Sources

- DFlash merge: [Medium](https://xhinker.medium.com/dflash-just-landed-in-llama-cpp-worth-to-upgrade-to-get-speed-boost-a20db434e8f7)
- Qwen3.6 MTP benchmarks: [Reddit r/LocalLLaMA](https://www.reddit.com/r/LocalLLaMA/comments/1tgxau6/llamacpp_mtp_support_landed_qwen36_27b_at_244_on/)
- HIP engine: [Framework Community](https://community.frame.work/t/hipengine-fast-native-qwen-3-6-inference-for-rdna3-including-strix-halo/82803)
- DeepSeek V4-Flash quantization: [MindStudio](https://www.mindstudio.ai/blog/run-deepseek-v4-flash-locally-dwarf-star-macbook)
- Hermes releases: [github.com/NousResearch/hermes-agent/releases](https://github.com/NousResearch/hermes-agent/releases)
- Ollama releases: [github.com/ollama/ollama/releases](https://github.com/ollama/ollama/releases/)
- llama.cpp releases: [github.com/ggml-org/llama.cpp/releases](https://github.com/ggml-org/llama.cpp/releases)
