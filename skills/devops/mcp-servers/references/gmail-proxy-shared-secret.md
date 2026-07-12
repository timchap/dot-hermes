# Gmail Proxy Shared-Secret Auth Pattern

Tim's infrastructure uses a gmail-proxy on the framework node (`http://framework:8090/mcp/v1`) as a pass-through that holds the upstream Google OAuth tokens and exposes an MCP endpoint behind a shared-secret Bearer token.

## Auth Layers

1. **Upstream Google OAuth** — the proxy holds refresh_token + client_secret, mints short-lived access_tokens for Google's Gmail MCP endpoint
2. **Proxy inbound auth** — the proxy requires `Authorization: Bearer <shared_secret>` (stored in 1Password as `op://Hermes Readable/Hermes Gmail Proxy Shared Secret/password`)

Hermes config:
```yaml
mcp_servers:
  gmail-proxy:
    url: http://framework:8090/mcp/v1
    headers:
      Authorization: Bearer ${GMAIL_PROXY_SHARED_SECRET}
```

## Error Diagnosis

| Symptom | Likely cause | Fix |
|---------|-------------|-----|
| "The caller does not have permission" | Proxy is reachable (health OK) but rejects the request — upstream OAuth token expired/corrupted OR shared secret mismatch | Check framework node: `docker logs <proxy-container>` or `journalctl -u gmail-proxy` for Google OAuth errors. Verify 1Password secret matches what the proxy expects. |
| "Connection refused" / "UNREACHABLE" | Proxy container not running or port not exposed | `curl -s http://framework:8090/health` — if it returns OK, proxy is up. If not, start/restart the service. |
| Timeout | Proxy is alive but upstream Google API is slow/unreachable | Check proxy logs for connection to `gmailmcp.googleapis.com`. May be a Tailscale routing issue. |

## Key diagnostic commands

```bash
# On the framework node:
curl -s http://framework:8090/health          # should return {"status":"ok","service":"gmail-mcp-proxy"}
docker logs <container> --tail 50              # OAuth/token errors show up here
journalctl -u gmail-proxy --since "1 hour ago" # if running as systemd service
```

## Re-authorizing

If the upstream OAuth access token has expired and the proxy can't refresh it:
1. On the framework node, check if the refresh_token is still valid
2. Re-run the OAuth consent flow (Google Cloud → Gmail MCP API → OAuth consent)
3. Update the refresh_token in the proxy's config/vault
4. Restart the proxy service

## Session note

Diagnosed 2026-07-12: proxy health returned OK, but all MCP tool calls returned `{"error": "The caller does not have permission"}` — consistent with upstream Google OAuth failure, not a proxy-level auth issue.
