# Lemonade Server Observability

## Built-in OTLP Telemetry (Primary)

Lemonade has a zero-dependency OpenTelemetry telemetry subsystem in `config.json` under `telemetry.*`, **disabled by default**. Exports per-request traces via OTLP for APM tools.

**Dual semantic conventions** — supports `openinference.*` (AI-native: Phoenix, Langfuse) and `otel_genai.*` (official OTel standard: Datadog, Honeycomb, Grafana) simultaneously in a single network payload.

**Key config keys:**
- `telemetry.enabled` — boolean, default `false`
- `telemetry.otlp.endpoint` — default `http://localhost:4318/v1/traces`
- `telemetry.otlp.semantics` — array, default `["openinference", "otel_genai"]`
- `telemetry.hide_inputs/outputs/thinking` — redact text from traces
- `telemetry.otlp.headers` — auth headers (e.g. Honeycomb API key)

**Enable quickly:**
```bash
lemonade config set telemetry.enabled=true
# Optional: redact prompt/completion text (keeps latency, token counts, model name)
lemonade config set telemetry.hide_inputs=true telemetry.hide_outputs=true telemetry.hide_thinking=true
```

**Flush queue on demand:**
```bash
curl -X POST http://localhost:13305/internal/telemetry/flush
```

## Prometheus Metrics (`/metrics` endpoint)

Lemonade exposes a Prometheus-compatible `/metrics` endpoint on the same port
as the HTTP API (default `:13305`). No extra flags needed — it is always on.

### Complete metric list (Lemonade 10.9.0+)

**Server-level:**
- `lemonade_server_up` (gauge) — 1 if server is running
- `lemonade_server_info{version}` (gauge) — build info
- `lemonade_loaded_models` (gauge) — count of loaded models
- `lemonade_max_loaded_models{type}` (gauge) — per-type load limit

**Aggregate token counters:**
- `lemonade_requests_total` (counter)
- `lemonade_input_tokens_total` (counter)
- `lemonade_output_tokens_total` (counter)
- `lemonade_prompt_tokens_total` (counter)

**Per-model gauges (latest request):**
- `lemonade_model_info{checkpoint,device,model_name,recipe,type}` (gauge)
- `lemonade_model_loaded{...}` (gauge) — 1 if currently loaded
- `lemonade_model_input_tokens{...}` (gauge)
- `lemonade_model_output_tokens{...}` (gauge)
- `lemonade_model_prompt_tokens{...}` (gauge)
- `lemonade_model_time_to_first_token_seconds{...}` (gauge)
- `lemonade_model_tokens_per_second{...}` (gauge)
- `lemonade_model_requests_total{...}` (counter)
- `lemonade_model_input_tokens_total{...}` (counter)
- `lemonade_model_output_tokens_total{...}` (counter)
- `lemonade_model_prompt_tokens_total{...}` (counter)

**Accelerator utilization (system-wide):**
- `lemonade_gpu_usage_percent` (gauge) — GPU utilization %
- `lemonade_cpu_usage_percent` (gauge) — CPU utilization %
- `lemonade_npu_usage_percent` (gauge) — NPU utilization %
- `lemonade_memory_used_gb` (gauge) — system RAM in GiB
- `lemonade_vram_used_gb` (gauge) — GPU VRAM in GiB

**llama.cpp layer metrics (per model):**
- `lemonade_llamacpp_prompt_tokens_total{...}` (counter)
- `lemonade_llamacpp_prompt_seconds_total{...}` (counter)
- `lemonade_llamacpp_tokens_predicted_total{...}` (counter)
- `lemonade_llamacpp_tokens_predicted_seconds_total{...}` (counter)
- `lemonade_llamacpp_n_decode_total{...}` (counter) — total llama_decode() calls
- `lemonade_llamacpp_n_tokens_max{...}` (counter) — largest observed n_tokens
- `lemonade_llamacpp_prompt_tokens_seconds{...}` (gauge) — avg prompt throughput tok/s
- `lemonade_llamacpp_predicted_tokens_seconds{...}` (gauge) — avg generation throughput tok/s
- `lemonade_llamacpp_requests_processing{...}` (gauge) — in-flight requests
- `lemonade_llamacpp_requests_deferred{...}` (gauge) — queued requests
- `lemonade_llamacpp_n_busy_slots_per_decode{...}` (gauge) — avg busy slots per decode

All per-model metrics carry labels: `checkpoint`, `device` (e.g. "gpu"),
`model_name`, `recipe` (e.g. "llamacpp"), `type` (e.g. "llm", "embedding").

**Verify locally:**
```bash
curl http://127.0.0.1:13305/metrics | grep '^# HELP' | sort -u
```

### Grafana dashboard PromQL

- Token throughput: `sum by (model_name) (rate(lemonade_output_tokens_total[5m]))`
- Decode speed: `lemonade_model_tokens_per_second`
- Memory: `lemonade_memory_used_gb` (RAM) + `lemonade_vram_used_gb` (VRAM)
- Accelerator util: `lemonade_gpu_usage_percent`, `lemonade_cpu_usage_percent`, `lemonade_npu_usage_percent`

## Recommended Tooling

| Tool | Type | Best For | Setup |
|------|------|----------|-------|
| **Arize Phoenix** | Local APM | Per-request traces, deep debugging | `docker run -d --name phoenix -p 6006:6006 -p 4317:4317 -p 4318:4318 arizephoenix/phoenix` |
| **Prometheus + Grafana** | Dashboards | Day-to-day monitoring, alerts | Scrape Lemonade `/metrics` |
| **Honeycomb** | Cloud APM | SaaS, no infra to manage | Point `telemetry.otlp.endpoint` at Honeycomb |
| **llamacpp-exporter** | Sidecar | Multi-model Prometheus consolidation | `github.com/civitz/llamacpp-exporter` |

## Phoenix Trace Retention

Phoenix defaults to **infinite** trace retention. Set
`PHOENIX_DEFAULT_RETENTION_POLICY_DAYS` to bound storage:

```yaml
environment:
  PHOENIX_DEFAULT_RETENTION_POLICY_DAYS: "30"
```

Phoenix runs a weekly cleanup sweep purging traces older than the configured
days. Per-project overrides are available in the Phoenix UI. SQLite
`VACUUM` reclaim is automatic but asynchronous — freed space may not reflect
immediately in the settings page.

## Prompt Caching Stats

Lemonade telemetry captures token counts (`llm.token_count.prompt`, `llm.token_count.completion`). KV cache hit rates come from llama.cpp slot metrics (`n_prompt_tokens_processed` counter per slot). No dedicated cache-hit-rate metric exists yet.
