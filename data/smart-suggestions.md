---
name: smart-suggestion
description: Use when generating weekly smart suggestions — tailored ideas based on user patterns, homelab activity, and web research.
version: 1.0.0
author: Hermes Agent
license: MIT
metadata:
  hermes:
    tags: [suggestion, weekly, smart, scouting]
    related_skills: [hermes-agent]
---
# Smart Suggestion Tracker

Track which suggestions have been made to avoid repeating ideas.

## Past Suggestions Considered

| # | Date | Idea | Status |
|---|------|------|--------|
| #1 | Jul 12 | Custom homelab-mcp server (wrapping HA, Ollama, docker, gmail-mcp as MCP tools) | Superseded — HA's official MCP integration changes the approach |
| #2 | Jul 13 | Deploy Home Assistant's official MCP Server integration | Awaiting user feedback |
| #3 | Jul 20 | [pending] | — |

## Pattern Rules
- Never repeat a suggestion that was already fully presented in a weekly round
- If an idea was partially implemented (e.g., gmail-mcp built but not deployed), don't suggest it as new
- Cross-reference with cron jobs to avoid suggesting something already automated
