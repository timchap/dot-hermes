# MCP Ecosystem Landscape (2026)

Key ecosystem changes relevant to homelab/agent integration suggestions.

## Protocol Updates

- **MCP 2026-07-28 spec**: Streamable HTTP transport, no handshake or sessions. Simpler endpoint: `POST /mcp HTTP/1.1` with `MCP-Protocol-Version` header.
- **Server discovery** (SEP-1649, SEP-1960): Standardized `.well-known/mcp.json` and `.well-known/mcp/server-card.json` endpoints for auto-discovery.

## Native MCP Tooling

- **n8n**: Built-in MCP Server and MCP Client nodes (no external packages). Expose workflows as MCP tools, connect to existing MCP servers from within workflows. Self-hosted version is free with no execution limits. 400+ integrations.
- **Home Assistant**: Official MCP Server integration (first-party). Exposes entities, automations, Assist API as MCP tools. Third-party HA-MCP (via HACS) adds 60+ extra tools.
- **Google services**: Gmail/Calendar/Tasks MCP proxies (user-built) already exist in their homelab.

## Registry & Directory Size

- Official MCP Registry: ~9,600 server records (mid-2026)
- PulseMCP indexes: ~15,900+
- Smithery catalogs: ~7,300+

## Notable MCP Server Projects

- **theonlytruebigmac/homelab-mcp**: 30+ tools for Docker, Proxmox, GitHub, DNS. Docker image, actively used.
- **homeassistant-ai/ha-mcp**: Third-party HA MCP with 60+ tools via HACS.
- **n8n workflow templates**: FileSystem MCP, SQLite MCP, Google Drive MCP, custom API MCP (all n8n-native).
