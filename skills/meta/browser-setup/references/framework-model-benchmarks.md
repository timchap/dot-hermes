# Framework Node Model Benchmarking

**Date**: 2026-07-12  
**Host**: framework node (Tailscale, port 13305)  
**Model family**: Qwen3.6-35B-A3B

## Available Models

| Model ID | Runtime | Size | Features |
|----------|---------|------|----------|
| `Qwen3.6-35B-A3B-FP16-vLLM` | vLLM | 71.9 GB | Reasoning, tool-calling, vision |
| `Qwen3.6-35B-A3B-GGUF` | llama.cpp GGUF (Q4_K_XL) | 21.7 GB | Vision, tool-calling |
| `Qwen3.6-35B-A3B-MTP-GGUF` | llama.cpp GGUF (Q4_K_XL) | 23.8 GB | Vision, tool-calling, **MTP** |

## Benchmark Results

Test: `curl -s -X POST "http://framework:13305/v1/chat/completions" -H "Content-Type: application/json" -d '{"model":"<MODEL>","messages":[{"role":"user","content":"Say ok"}],"max_tokens":10}'`

| Model | Prompt throughput | Token throughput | Notes |
|-------|------------------|-----------------|-------|
| MTP-GGUF | 116 tok/s | 103 tok/s | Multi-token prediction (draft_n=6, accepted=6) |
| Standard GGUF | 143 tok/s | 67 tok/s | Standard decode, no MTP |
| FP16-vLLM | — | — | Not responding at test time (may not be running) |

**Key finding**: MTP model is ~54% faster in output token throughput due to multi-token prediction. This is the preferred default for local use since it reduces latency per turn in tool-use loops (browser automation, multi-step reasoning, etc.).

## Usage

```bash
# Test a model
curl -s -X POST "http://framework:13305/v1/chat/completions" \
  -H "Content-Type: application/json" \
  -d '{"model":"Qwen3.6-35B-A3B-MTP-GGUF","messages":[{"role":"user","content":"Say ok"}],"max_tokens":10}'

# List all models
curl -s "http://framework:13305/v1/models"
```

## Config

```yaml
model:
  default: Qwen3.6-35B-A3B-MTP-GGUF
  provider: custom:framework
  base_url: http://framework:13305/v1
  api_mode: chat_completions
```

**CRITICAL**: `base_url` MUST point to the local framework node. If set to an OpenRouter URL, the custom provider's base_url is completely overridden and all requests go to OpenRouter instead of local.