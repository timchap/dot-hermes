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
      Authorization: "Bearer sk-..."
    timeout: 180
```

Tools appear as `mcp_{server_name}_{tool_name}` (hyphens/dots → underscores).

## Prerequisites

1. **MCP SDK**: `pip install mcp` — without this, MCP support is silently disabled.
2. **Node.js**: Required for `npx`-based servers.
3. **uv**: Required for `uvx`-based servers.
4. **Restart Hermes**: MCP changes require a restart (no hot-reload).

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

## References

- `references/google-gmail-mcp.md` — Google's official Gmail MCP server setup (OAuth, scopes, API enablement)