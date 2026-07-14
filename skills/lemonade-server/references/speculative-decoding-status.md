# Speculative Decoding Status in Lemonade Server

## Current State (as of 2026-07-14)

Native speculative decoding UI integration in Lemonade is **not yet merged** into main. A draft PR exists and is being actively developed.

## Feature Request & PR

- **Issue #1419** — [Feature Request: Integrate Speculative Decoding for Token Generation Speedup](https://github.com/lemonade-sdk/lemonade/issues/1419)
  - Opened March 20, 2026 by @sawansri (Lemonade collaborator)
  - Describes two approaches: draft models and n-gram/self-speculative
  - Provides early benchmarks on GLM 4.7 Flash (~50 tok/s → ~120 tok/s)

- **Draft PR #1638** — [Integrate Speculative Decoding into Lemonade](https://github.com/lemonade-sdk/lemonade/pull/1638)
  - Opened April 15, 2026
  - 15 commits, 915 additions / 47 deletions
  - Adds WebUI controls for speculative decoding settings
  - Includes backend logic to resolve draft model paths (checkpoint/model name → local GGUF paths)
  - Enables creating recipes with draft models
  - **Still a draft** — not yet merged to main (as of July 2026)

## Workaround: Custom llama.cpp Args

Until PR #1638 merges, use `--llamacpp-args` to pass speculative decoding flags directly:

```bash
# N-gram speculative decoding (no draft model needed)
lemonade load <model> --llamacpp-args "--spec-type ngram-mod --spec-ngram-size-n 24 --draft-min 48 --draft-max 64"

# MTP (Qwen native heads only)
lemonade load <model> --llamacpp-args "--flash-attn --mtp"
```

## Speculative Decoding Methods in llama.cpp

### N-gram / Self-Speculative
- **Methods:** `ngram-simple`, `ngram-mod`, `ngram-map-k4v`
- **How it works:** Pattern matching in current context to guess next tokens
- **Overhead:** Very slight
- **Best for:** Any model, zero extra memory, immediate speedup
- **Typical speedup:** 2× on Strix Halo

### Draft Models
- **How it works:** Secondary smaller model drafts tokens, main model verifies
- **Overhead:** Higher (needs to load and run draft model)
- **Best for:** Models where a good draft model exists
- **Typical speedup:** 1.5-2.5× depending on draft model quality

### MTP (Multi-Token Prediction)
- **How it works:** Uses model's own built-in prediction heads (Qwen3.6+)
- **Overhead:** Minimal — same model, no extra weights
- **Best for:** Qwen3.6+ models with native MTP heads
- **Benchmark:** Qwen3.6 35B-A3B on Strix Halo: ~90-110 tok/s (2.4× baseline)

### DFlash (Block-Diffusion)
- **Merged in:** llama.cpp master b9967+
- **How it works:** Block-diffusion draft-model speculative decoding (PR #22105)
- **Benchmark:** ~2× speedup for Gemma 4 31B on RTX 4090
- **Lemonade support:** Not yet exposed via config — requires rebuilding llama.cpp from source
- **Note:** May not work with TurboQuant KV cache (known bug in llama.cpp)

## Architecture Notes

On UMA architectures (Strix Halo with 128 GB unified LPDDR5X memory), **memory bandwidth is the primary bottleneck**, not GPU compute. Speculative decoding is particularly effective because:
- The RDNA 3.5 GPU compute is largely idle during standard decoding
- The batched verification step exploits spare compute
- Multiple accepted tokens come from effectively one memory pass over weights

This makes speculative decoding on Strix Halo especially valuable compared to architectures where compute is already saturated.
