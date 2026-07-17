# Hindsight — External Memory Backend

Hindsight is a built-in Hermes memory backend that persists declarative knowledge to a local API server (powered by Lemonade). It uses an auxiliary LLM for fact extraction and deduplication.

## Tools

| Tool | Purpose |
|------|---------|
| `hindsight_recall(query)` | Search for memories. Pass `"any"` for all. |
| `hindsight_retain(content, context, tags)` | Store a memory entry. `context` is a short category label; `tags` are optional. |

## Configuration

Hindsight is configured via `~/.hermes/config.yaml` under the `memory` section, with `provider: hindsight`. The Lemonade model used for fact extraction is specified in the backend config.

## Operational Notes

- **Model dependency:** The fact extraction LLM must be available in the Lemonade model catalog. If the configured model is removed/renamed, `hindsight_retain` returns HTTP 500 with `model_not_found`.
- **Connectivity check before bulk operations:** Always run `hindsight_recall("any")` first when integrating a new or recently-reconfigured Hindsight backend. If the recall call succeeds, bulk stores will work. If it fails, the extraction model needs to be fixed before any `hindsight_retain` calls.
- **In-memory memory transition:** When migrating from in-memory Hermes memory to Hindsight, first read all entries from memory, then transfer via `hindsight_retain` calls, then confirm the in-memory store is empty.

## Reference Example

```python
# Transfer session memory to Hindsight
# 1. Read current entries (displayed in session header)
# 2. Call hindsight_recall to verify API is up
# 3. For each memory entry, call hindsight_retain(content=..., context=...)
# 4. Verify: call hindsight_recall again to confirm entries are stored
```
