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
# Smart Suggestion Scout

Generate ONE high-quality, tailored weekly suggestion that could make the user's life easier. Run as a cron job; each run produces a single output delivered to the user.

## Prerequisites

- Read `/home/hermes/.hermes/data/smart-suggestions.md` before starting. This tracker holds past suggestions and must be updated at the end.

## Step 1: Gather Context

Run these in parallel:

1. **Past suggestions**: `session_search(query="suggestion weekly scout recommendation idea", sort="newest", limit=10)` — look at what was suggested and the user's reaction (positive, negative, "tell me more").
2. **Recent work**: `session_search(query="project work homelab smart home productivity", sort="newest", limit=10)` — what has the user been working on in the last 4 weeks?
3. **Memory**: `cat /home/hermes/.hermes/memories/*.md 2>/dev/null`
4. **SOUL.md**: `cat /home/hermes/.hermes/SOUL.md`
5. **Cron jobs**: `cronjob action='list'` (or inspect `/home/hermes/.hermes/cron/jobs.json`)
6. **Skills**: `ls /home/hermes/.hermes/skills/ 2>/dev/null`
7. **Homelab activity**: `cd /home/hermes/repositories/homelab && git log --oneline -20 2>/dev/null` (homelab repo lives under `repositories/`, not a top-level directory)

Also check for **new trends** since last suggestion — especially any ecosystem changes that shift the landscape (e.g., new integrations, protocol updates).

## Step 2: Web Research

Run 3-5 web searches covering:
- New tools/techniques in agentic AI (2025-2026)
- Homelab/IoT automation
- Smart home + AI integrations
- Self-hosted AI applications
- Hermes Agent ecosystem updates

Use queries like "agentic AI productivity 2025 2026", "MCP server homelab", "local AI smart home projects".

## Step 3: Filter & Select

From all gathered signals, pick ONE suggestion. It must be:

- **Tailored** to the user's actual usage patterns and stated interests
- **Actionable** — something they could implement (not vague)
- **Novel** — NOT already in their cron jobs, skills, or memory
- **Superseded-aware** — if a previous suggestion makes this one obsolete (e.g., new official integration exists), note it and pick a different direction
- **Interesting** — they should say "tell me more"
- **In scope** — productivity, homelab, personal assistant, automation, or expressed interests

If nothing genuinely interesting emerges, output `[SILENT]` with nothing else.

## Step 4: Output Format

```
## 🎯 Weekly Suggestion #[NNN]

**What:** [One-line description]

**Why you:** [2-3 sentences explaining why this fits THEM specifically, referencing their actual patterns]

**How it works:** [Brief explanation of what it is and how they'd use it]

**Effort to set up:** [Low / Medium / High] + rough estimate

**What you'd need:** [Specific tools, services, or changes required]

---
Note: This replaces suggestion #[NNN-1]. Previous suggestions considered: [brief list of recent ideas that didn't make the cut]
```

## Step 5: Update Tracker

Read and update `/home/hermes/.hermes/data/smart-suggestions.md`:
- Add the new suggestion to the table with date, idea, and status
- Note any superseding relationships (e.g., "Superseded — HA's official MCP integration changes the approach")

## Pitfalls

- **Homelab repo location**: The repo is at `/home/hermes/repositories/homelab/`, NOT `/home/hermes/homelab/`. Always check the former.
- **Don't repeat**: Check the tracker and previous suggestions to avoid re-proposing the same idea.
- **Cross-reference with cron jobs**: A suggestion is not novel if it's already automated.
- **Superseded suggestions**: If the landscape changed (new official integration, protocol update), note it and pivot away from the old approach.
- **Track ALL considered ideas**: Even ideas you rejected — future runs need to know what was passed on.

## Support Files

- `references/ha-mcp-integration.md` — Home Assistant MCP Server integration guide for Hermes
