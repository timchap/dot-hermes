---
name: mcp-servers
description: "Set up, configure, and troubleshoot MCP servers in Hermes — stdio and HTTP transports, OAuth flows, env var security, credential sourcing."
version: 1.0.0
author: Hermes Agent
license: MIT
platforms: [linux, macos]
metadata:
  hermes:
    tags: [mcp, mcp-server, stdio, http, model-context-protocol, integration]
---

# MCP Servers

Setting up and managing Model Context Protocol (MCP) servers in Hermes Agent.

## Quick Reference

Hermes has a **built-in MCP client**. Add servers to `~/.hermes/config.yaml` under `mcp_servers`:

```yaml
mcp_servers:
  server_name:
    command: "npx"             # stdio transport
    args: ["-y", "pkg-name"]
    env:
      SOME_API_KEY: "value"    # ONLY explicit env vars pass to the subprocess
    timeout: 120

  http_server:
    url: "https://my-server.example.com/mcp"  # HTTP transport
    headers:
      Authorization: "Bearer sk-..."           # or inject a 1Password secret:
    timeout: 180                              #   Authorization: "Bearer {{MY_SECRET}}"
```

### Injecting 1Password Secrets into MCP Headers

Use the `{{VAR}}` substitution syntax in `mcp_servers.<name>.headers.*` values.
The variable must be injected via the `secrets.onepassword.env` section:

```yaml
mcp_servers:
  my-proxy:
    url: "http://proxy-host:8080/mcp"
    headers:
      Authorization: "Bearer {{MY_PROXY_SECRET}}"
    timeout: 60

secrets:
  onepassword:
    enabled: true
    env:
      MY_PROXY_SECRET: op://<vault>/<item title>/password   # or op://<item-id>/reveal
```

At connection time Hermes resolves `{{MY_PROXY_SECRET}}` from the injected env var.
This keeps secrets out of config.yaml (though the config file itself still has the `{{VAR}}` placeholder).

### Writing to config.yaml

Hermes **blocks direct `patch`/`write_file` edits to `~/.hermes/config.yaml`** — it is security-sensitive.
To add or modify MCP servers:
- **CLI (preferred):** `hermes mcp add <name> --url <endpoint>` (interactive prompts for auth).
- **Editor:** `hermes config edit` opens config.yaml in the configured editor.
- **Programmatic:** If the security block is lifted or you are editing via a script, the `{{VAR}}` syntax works in any `headers` field as shown above.

### CLI Pitfall

`hermes mcp add NAME --url <endpoint> --auth header` prompts for the API key interactively and may fail to persist the header in non-TTY sessions.
If the interactive prompt hangs or the connection test fails mid-way, **do not force-save** — instead use `hermes config edit` or the `{{VAR}}` pattern shown above.

Tools appear as `mcp_{server_name}_{tool_name}` (hyphens/dots → underscores).

## Prerequisites

1. **MCP SDK**: `pip install mcp` — without this, MCP support is silently disabled.
2. **Node.js**: Required for `npx`-based servers.
3. **uv**: Required for `uvx`-based servers.
4. **Config location**: `~/.hermes/config.yaml` under the `mcp_servers` key.

## Stdio Transport

Most common. Hermes launches the server as a subprocess.

```yaml
mcp_servers:
  filesystem:
    command: "npx"
    args: ["-y", "@modelcontextprotocol/server-filesystem", "/home/user/documents"]
```

## HTTP Transport

For remote/shared MCP servers. Requires `mcp` package with HTTP support.

```yaml
mcp_servers:
  remote_api:
    url: "https://mcp.example.com/mcp"
    headers:
      Authorization: "Bearer sk-..."
```

If HTTP support is unavailable, upgrade: `pip install --upgrade mcp`.

## Security: Environment Variables

For stdio servers, Hermes **filters** the subprocess environment. Only these pass through:

- `PATH`, `HOME`, `USER`, `LANG`, `LC_ALL`, `TERM`, `SHELL`, `TMPDIR`
- Any `XDG_*` variables

**All other env vars are excluded** unless explicitly added via the `env` config key. This prevents accidental credential leakage.

To pass secrets, use the `env` key — or use 1Password secrets (`OP_*` env vars or `hermes onepassword` CLI) for dynamic secret sourcing instead of hardcoding values.

## Tool Naming

Pattern: `mcp_{server_name}_{tool_name}`

Examples:
- Server `github`, tool `list-issues` → `mcp_github_list_issues`
- Server `my-api`, tool `fetch.data` → `mcp_my_api_fetch_data`

## CLI Management

```bash
hermes mcp list              # Show configured servers
hermes mcp add NAME --command CMD [ARGS...]   # Add stdio server
hermes mcp add NAME --url URL   # Add HTTP server
hermes mcp remove NAME          # Remove server
hermes mcp test NAME            # Test connection
hermes mcp configure NAME       # Toggle tool selection
```

**Adding via CLI:** `hermes mcp add <name> --url <endpoint> [--auth {oauth,header}]` — writes to `~/.hermes/config.yaml` under `mcp_servers.<name>`. For header-based auth, pass `--auth header` and add the secret via `--env` for stdio or `headers` in config for HTTP.

**Reloading:** Use the `/reload-mcp` slash command to reload MCP servers without restarting Hermes. No full restart needed.

**Config location:** `~/.hermes/config.yaml` under the `mcp_servers` key. No separate `mcp_servers.yaml` file.

## Troubleshooting

| Problem | Fix |
|---------|-----|
| "MCP SDK not available" | `pip install mcp` |
| "No MCP servers configured" | Add entries under `mcp_servers` in config.yaml |
| "Failed to connect" | Check command/path/package; increase `connect_timeout` |
| Tools not appearing | Verify `mcp_servers` (not `mcp`), check tool naming prefix |
| Connection dropping | Client retries 5× with backoff (1s→60s). Check server health. |

## Supported Transport Types

| Transport | When to use | Config keys |
|-----------|-------------|-------------|
| `stdio` (default) | Local processes (npx, uvx, custom binary) | `command`, `args`, `env` |
| `HTTP` | Remote or shared MCP endpoints | `url`, `headers` |
| `StreamableHTTP` | Remote servers with SSE/streaming | `url`, `headers` |

A server config must have either `command` OR `url`, not both.

## OAuth Isolation via Proxy (high-trust-agent pattern)

When an MCP server requires long-lived credentials you don't want the agent host itself to hold
(e.g. Gmail OAuth client secret + refresh token, or any credential where a prompt-injection/agent
compromise should not be able to exfiltrate it), don't put the credential directly in Hermes'
`mcp_servers` config. Instead, build a small pass-through proxy:

1. Deploy the proxy as its own service (own host/container/VM) — physically or at least
   privilege-separated from the Hermes host.
2. The proxy holds the OAuth client id/secret/refresh token and manages the access-token
   refresh cycle itself (refresh_token → short-lived access_token via the provider's `/token`
   endpoint, cached in memory, refreshed before expiry).
3. The proxy exposes the **exact same MCP JSON-RPC API shape** as the real upstream server —
   forward `initialize`, `ping`, `tools/list`, `tools/call` etc. verbatim, attaching
   `Authorization: Bearer <access_token>` to the upstream call. Zero protocol translation needed
   on the Hermes side — point `mcp_servers.<name>.url` at the proxy instead of the real endpoint.
4. Optionally require its own inbound shared-secret (`Authorization: Bearer <proxy_secret>`)
   distinct from the upstream OAuth secret — Hermes can safely hold this since compromising it
   only grants API access, not the ability to mint fresh OAuth tokens or read the refresh token.
5. Network-isolate the proxy: bind only where the agent host can reach it (Tailscale/LAN), never
   expose it publicly.

This pattern generalizes beyond Gmail to any MCP integration with sensitive long-lived credentials
(Google Workspace APIs, other OAuth-gated SaaS MCP servers). See `references/google-gmail-mcp.md`
for the Gmail-specific endpoint/scope details this pattern was first applied to.

## References

- `references/google-gmail-mcp.md` — Google's official Gmail MCP server setup (OAuth, scopes, API enablement)