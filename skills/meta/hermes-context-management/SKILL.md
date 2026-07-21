---
name: hermes-context-management
description: Use when deciding where to persist declarative knowledge in Hermes — SOUL.md, .hermes.md, AGENTS.md, memory, skills, references, templates, or scripts.
version: 1.0.0
author: agent
license: MIT
platforms: [linux, macos, windows]
metadata:
  hermes:
    tags: [context, placement, organization, soul, memory, skills, metadata]
    related_skills: [hermes-agent]
---

# Context Placement Framework

Hermes has multiple context-loading mechanisms. They serve different scopes, lifetimes, and content types. Misplacing context wastes space or leaks it into wrong sessions.

## Overview

This skill provides a decision framework for choosing where to persist declarative knowledge in Hermes: SOUL.md, .hermes.md, AGENTS.md, memory, skills, references, templates, or scripts.

## When to Use

Load this skill when you need to decide where to store a fact, procedure, template, or script. Use the decision process below to choose the right storage mechanism based on scope, lifetime, and content type.

## The Hierarchy (top to bottom)

### SOUL.md — Identity and mandate
**Scope:** Always loaded, every session, all profiles.  
**Size budget:** ~5k chars (leaves room for other context).  
**Content:** Who you are, behavioral mandates, guiding principles, hard lines not to cross.  
**Examples:** "Self-improvement is your primary behavioral driver", "Before making infra changes, check homelab docs first", "Require explicit user confirmation for any payment."  
**Don't put here:** Project-specific rules, operational details, volatile facts, user preferences about output format (those belong in the relevant skill).

### .hermes.md / AGENTS.md — Project-level behavioral rules
**Scope:** Loaded when cwd is inside the git tree (.hermes.md walks up to git root; AGENTS.md is cwd-only).  
**Content:** "How this repo works, what to check for, preferred workflow." Project-specific instructions.  
**Choice:** Use .hermes.md for Hermes-specific rules that inherit hierarchically. Use AGENTS.md/CLAUDE.md when the project will be worked by other agents (Claude Code, Codex, OpenCode).

### memory — Durable, persistent facts
**Scope:** Injected every turn. Compact, high-signal only.  
**Content:** User preferences, environment facts, corrections. Things that prevent asking the user to repeat themselves.  
**Don't put here:** Task progress, completed-work logs, PR numbers, commit SHAs, anything that will be stale in a week.  
**Format:** Declarative facts, not instructions. "User prefers concise responses" not "Always respond concisely".

### skills — Procedural knowledge: "how to do X"
**Scope:** Loaded when referenced or when umbrella skill loads them.  
**Content:** Repeatable procedures for recurring tasks. Skills are for workflows, not facts or identity.  
**Trigger:** 5+ tool calls, iterative debugging, a new workflow you'd want to reuse.  
**Rule:** When you discover a pitfall that an existing skill doesn't cover, patch it immediately. Don't work around stale skills.

### references/ — Authoritative external content
**Scope:** Loaded when the skill that owns them is loaded.  
**Content:** API docs excerpts, research notes, domain notes. Not for session-specific ephemera.  
**Use:** Condensed, for the value of the task — not a full mirror of upstream docs.
**Linked files:** `references/hindsight-backend.md` — Hindsight external memory backend integration guide (tools, configuration, connectivity checks, model dependency pitfalls).

### templates/ — Starter files
**Scope:** Loaded when the skill that owns them is loaded.  
**Content:** Boilerplate configs, scaffolding, known-good examples the agent can reproduce with modifications.

### scripts/ — Deterministic actions
**Scope:** Loaded when the skill that owns them is loaded.  
**Content:** Static, re-runnable actions the agent should run rather than hand-type. Verification scripts, fixture generators, deterministic probes.

## Systematic Skill Library Quality Review

When conducting comprehensive quality reviews of skill libraries (weekly audits, compliance checks):

### Discovery and Assessment Process
1. **Complete inventory**: `search_files(pattern="SKILL.md", path="~/.hermes/skills")` for all skills
2. **Category mapping**: Read all `DESCRIPTION.md` files to understand intended scope
3. **Systematic review**: Work through skills by category for logical grouping
4. **Standards application**: Check frontmatter, size limits, content quality, factual accuracy

### Common Quality Issues to Fix
- **Content duplication**: Identical "When to Use" sections, redundant descriptions
- **Version drift**: Skills referencing outdated versions or incorrect syntax patterns  
- **Format violations**: Missing required fields, oversized descriptions, malformed YAML
- **Stale information**: Commands, paths, or procedures that are no longer accurate

### Review Standards (from hermes-agent-skill-authoring)
- Frontmatter: Starts with `---`, includes `name` and `description` fields
- Size limits: Description ≤ 1024 chars, name ≤ 64 chars, total file ≤ 100k chars  
- Content quality: Clear trigger conditions, actionable procedures, no duplication
- Accuracy: Fact-check verifiable information against current state

### Fixing Strategy
- Use `patch` tool for surgical fixes rather than full rewrites
- Batch multiple related issues in single skill into one edit pass
- Prioritize content accuracy and removal of duplication
- Document what was fixed and why in review summary

This systematic approach ensures the skill library maintains high quality and consistency while capturing institutional knowledge effectively.

## Decision Process

When you learn something new that could be persisted:

1. **Is it about who I am or my behavioral mandate?** → SOUL.md (check it fits under 5k chars)
2. **Is it project-specific?** → .hermes.md or AGENTS.md (depending on whether other agents work in this repo)
3. **Is it a persistent fact about the user or environment?** → memory tool (add or replace)
4. **Is it a procedure for doing something?** → skill (patch existing or create new)
5. **Is it authoritative external content?** → references/
6. **Is it a starter file or template?** → templates/
7. **Is it a deterministic script to run?** → scripts/

## Common Mistakes

- Putting operational details in SOUL.md where they'll be in every session unnecessarily
- Saving task progress or completed-work in memory (it'll be stale next week)
- Creating a new skill when an existing umbrella covers the territory
- Writing negative claims as skill constraints ("X tool doesn't work") instead of capturing the fix
- Letting a discovered pitfall go unpatched in an existing skill

## Common Pitfalls

1. **Putting operational details in SOUL.md** -- where they'll be in every session unnecessarily. SOUL.md is identity and mandates only.
2. **Saving task progress or completed-work in memory** -- it'll be stale next week. Use session_search for that.
3. **Creating a new skill when an existing umbrella covers the territory** -- check existing skills first.
4. **Writing negative claims as skill constraints** -- capture the fix, not "X tool doesn't work."
5. **Letting a discovered pitfall go unpatched** -- when you find a new pitfall, patch the existing skill immediately.
6. **Bulk-storing to external memory backends without verifying connectivity first** -- Hindsight's `hindsight_retain` uses a local LLM for fact extraction; if the configured model is removed/renamed, bulk-stores fail with HTTP 500. Always `hindsight_recall("any")` first to confirm the API is reachable and the extraction model is available before attempting a batch transfer.
7. **Flat-file and directory-form skills silently collide on the same name** -- e.g. `~/.hermes/skills/foo.md` and `~/.hermes/skills/foo/SKILL.md` both exist. `skill_view(name='foo')` then fails with "Ambiguous skill name ... 2 skills match" and blocks normal loading. Fix: read both candidates (`skill_view` with the disambiguated path from the error's `matches` list, or `read_file` directly), merge any unique content into the directory-form `SKILL.md` (preferred, since it supports `references/`/`templates/`/`scripts/`), then delete the stray flat `.md` file with `terminal`/`rm` (skill_manage requires a unique name so it can't target an ambiguous one directly). Re-run `skill_view(name=...)` to confirm it now resolves to a single file before considering it fixed.

## Verification Checklist

- [ ] Chosen storage mechanism matches the content's scope (identity -> SOUL, project -> .hermes.md, fact -> memory, procedure -> skill)
- [ ] Content fits within the target mechanism's size budget
- [ ] Fact is declarative (not imperative) if stored in memory
- [ ] No duplicates created -- checked existing skills/souls/memory first
- [ ] Pitfall from this skill patched into the relevant existing skill if discovered