# Speculative Decoding on Strix Halo (2026)

## Methods Compared

### MTP (Multi-Token Prediction) — Weight-Baked
Prediction heads baked into the GGUF model weights. No external draft model needed.
- **Qwen 3.6 27B MTP Q4_K_M**: ~19.8 t/s short, ~20.2 t/s long (3.1x baseline)
- **Qwen 3.6 27B MTP Q8_0**: ~20.9 t/s short, ~16.7 t/s long (3.2x baseline)
- **Gemma 4 31B MTP assistant**: ~22.9 t/s at block-size 5 (3.7x baseline)
- **Why it wins**: MTP heads ride the same sequential weight read as the target — zero memory bus contention.
- **Catch**: Requires specially converted MTP GGUFs or fork-specific assistant models.

### BeeLlama DFlash — Cross-Attention Draft Model
Separate draft GGUF (~1 GB) with cross-attention weights. Cross-attends to target hidden states.
- **Gemma 4 31B DFlash**: 16.5 t/s short, 12.5 t/s long (2.7x baseline)
- **Qwen 3.6 27B DFlash**: 16.0 t/s short, 12.0 t/s long (2.5x baseline)
- **Why it's easier**: Works with ANY unmodified target GGUF. Single fork for all model families.
- **Catch**: On Vulkan, uses CPU ring fallback (GPU ring path is CUDA-only). 23-67% slower than MTP.
- **Draft models**: Anbeeld/gemma-4-31B-it-DFlash-GGUF (IQ4_XS, ~836 MB), Anbeeld/Qwen3.6-27B-DFlash-GGUF (Q4_K_M, ~1 GB) on HuggingFace.

### ngram-mod / Cross-gen Draft
- **ngram-mod**: ~6.18 t/s (no improvement over baseline on Strix Halo)
- **Qwen 3.5 2B cross-gen draft**: ~6.19 t/s (no improvement over baseline)

## Full Leaderboard (Strix Halo, Vulkan, ~218 GB/s unified memory)

### Qwen 3.6 27B (Dense)
| Method | Short TG | Long TG | vs Baseline |
|--------|----------|---------|-------------|
| MTP Q8_0 (n-max 5) | ~20.9 | ~16.7 | ~3.2x / ~2.6x |
| MTP Q4_K_M (n-max 5) | ~19.8 | ~20.2 | ~3.1x / ~3.1x |
| Bee DFlash (Q8 target) | ~16.0 | ~12.0 | ~2.5x / ~1.9x |
| Cross-gen draft (Qwen 3.5 2B) | 6.19 | — | 0% |
| nmod | 6.18 | — | 0% |
| Baseline (stock) | 6.46 | 6.48 | — |

### Gemma 4 31B (Dense)
| Method | TG Speed | vs Baseline |
|--------|----------|-------------|
| MTP assistant (bs=5) | 22.9 | 3.7x |
| Bee DFlash (Q8 target) | 16.5 | 2.7x |
| E2B draft model (dm=4) | 12.3 | 2.0x |
| Baseline | 6.2 | — |

## Key Takeaway for Digests
MTP remains the fastest speculative method on Strix Halo's Vulkan path due to architectural advantage (no separate model competing for memory bus). DFlash is the better "plug-and-play" option when no MTP GGUF exists for a model family. Neither beats baseline ngram-mod on this hardware — speculative decoding only works when the method is architecture-matched to the memory-bottlenecked path.

## Sources
- [BeeLlama DFlash on Strix Halo — Sleeping Robots](https://sleepingrobots.com/dreams/beellama-dflash-strix-halo/)
- [MTP Qwen 3.6 benchmarks — Sleeping Robots](https://sleepingrobots.com/dreams/mtp-qwen36-strix-halo/)
- [MTP Gemma 4 assistant benchmarks — Sleeping Robots](https://sleepingrobots.com/dreams/gemma4-mtp-assistant-strix-halo/)
