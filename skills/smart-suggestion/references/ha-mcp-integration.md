# Home Assistant MCP Integration for Hermes

## Overview

Home Assistant now offers two MCP server pathways for connecting AI agents (including Hermes) to smart home control:

### 1. Official HA MCP Server Integration (First-Party)

Home Assistant ships an official "Model Context Protocol Server" integration. Install from HA UI: **Settings → Devices & Services → Add Integration → "Model Context Protocol Server"**.

- Exposes entities, automations, and the Assist API as MCP tools
- Uses HA's built-in Assist API for natural language command execution
- Works on every install type (OS, Supervised, Container, Core)
- Reaches: local network or remote via webhook (Nabu Casa or reverse proxy)
- Compatible with any MCP client: Claude Desktop, ChatGPT, and **Hermes**

**Hermes config** (in `~/.hermes/config.yaml`):
```yaml
mcp_servers:
  home-assistant:
    url: http://localhost:8123/api/mcp
    headers:
      Authorization: Bearer ***<long-lived-access-token>***
```

To get the token: **Settings → People → Long-Lived Access Tokens**.

### 2. HA-MCP Community Server (Third-Party)

The community project [homeassistant-ai/ha-mcp](https://github.com/homeassistant-ai/ha-mcp) installs via HACS and provides 60+ tools:
- Device control, state queries, automation management
- Dashboard configuration
- SSH/SFTP file management
- Deep entity queries

Install: HACS → Integrations → Search "HA-MCP" → Install → Restart HA.

## Why This Matters for Hermes Users

If you already run Home Assistant and use Hermes, this is a **zero-code bridge** between your smart home and your AI agent. No custom wrapper code, no Docker service to maintain. The official integration is maintained by the HA team; the community server adds breadth.

Both run locally — no cloud dependency. Over Tailscale for cross-host access.

## References

- Official integration docs: https://www.home-assistant.io/integrations/mcp_server/
- Community server: https://github.com/homeassistant-ai/ha-mcp
- Community server docs: https://homeassistant-ai.github.io/ha-mcp/
- Setup wizard: https://homeassistant-ai.github.io/ha-mcp/setup/
