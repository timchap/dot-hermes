---
name: skill-maintenance
description: Use when reviewing, auditing, or maintaining Hermes Agent skill quality — detecting frontmatter drift, truncation artifacts, hallucinated references, and structural issues across the user's local skill collection.
version: 1.0.0
author: Hermes Agent
license: MIT
platforms: [linux]
metadata:
  hermes:
    tags: [skills, maintenance, quality, audit, review, quality-assurance]
    related_skills: [hermes-agent-skill-authoring, hermes-agent]
---

# Skill Quality Maintenance

## Overview

Weekly review process for auditing the quality of user-local skills in `~/.hermes/skills/`. Detects frontmatter drift, truncation artifacts, hallucinated references, and structural compliance issues. All user-local skills are maintained here — no in-repo bundled skills are touched.

## When to Use

- Running the weekly `skill-quality-review` cron job
- Any time you need to audit skill quality across the user's local skill collection
- Before creating a new skill, to check for overlap with existing ones

## Discovery

1. **List all user-local skills:**
   ```bash
   find ~/.hermes/skills/ -name 'SKILL.md' | sort
   ```

2. **Check for in-repo or DESCRIPTION.md files:**
   ```bash
   ls /home/bb/hermes-agent/skills/ 2>/dev/null
   find /home/bb/hermes-agent/skills/ -name 'DESCRIPTION.md' 2>/dev/null
   ```
   If empty, all skills are user-local only (this is the current layout).

3. **List each skill's frontmatter** for automated scanning:
   ```bash
   for f in $(find ~/.hermes/skills/ -name 'SKILL.md' | sort); do
     echo "=== $f ==="
     sed -n '/^---$/,/^---$/p' "$f"
   done
   ```

## Quality Checks

Run these checks against every SKILL.md:

### 1. Frontmatter Completeness
Every skill MUST have all these fields:
- `name` — lowercase, hyphens, ≤64 chars
- `description` — starts with "Use when ...", ≤1024 chars
- `version` — e.g. `1.0.0`
- `author` — must be `Hermes Agent` (NOT `agent`, `AI`, `bot`, or empty)
- `license` — `MIT`
- `platforms` — array, e.g. `[linux, macos, windows]`
- `metadata.hermes.tags` — non-empty array
- `metadata.hermes.related_skills` — non-empty array

Common frontmatter drift patterns:
- Missing `platforms` field entirely
- Missing `metadata.hermes.related_skills` (tags present but no related_skills)
- `author: agent` instead of `author: Hermes Agent`
- `license` omitted in new skills

### 2. Content Issues
- **Orphaned bullets:** Lines that don't belong to any section (often from truncation). Fix: integrate into the nearest section or remove.
- **Duplicate sections:** Two `## Pitfalls` or `## Common Pitfalls` sections. Fix: merge into one.
- **Trailing blank lines:** After the last checklist item. Fix: remove.
- **Copy-paste artifacts:** Text fragments that belong to a different skill. Fix: rewrite or remove.

### 3. Reference Validation
- **Hallucinated skill references:** Skills reference other skills that don't exist (e.g., `generative-widgets`). Check every `references/` or `skill_view()` call in the skill against the actual skill list.
- **Outdated tool versions:** CLI commands, API endpoints, or protocol versions that may have changed.

### 4. Structural Compliance
- Starts with `---` (no leading blank line)
- Closes with `---` before the body
- Has `## Overview`, `## When to Use`, `## Common Pitfalls`, `## Verification Checklist`
- Description starts with "Use when ..."
- Total size ≤ 100,000 chars

## Workflow

1. **Scan frontmatter** across all skills for missing fields
2. **Read each skill** in category order
3. **Run automated checks** using a Python script that validates YAML frontmatter
4. **Patch issues found** using `skill_manage(action='patch')` for small fixes
5. **Verify patches** by re-reading the patched skill
6. **Summarize results:** total reviewed, pass count, changes applied

## Patching Strategy

For small frontmatter fixes (missing `platforms`, `related_skills`, wrong `author`):
```yaml
skill_manage(action='patch', name='skill-name', old_string='missing line', new_string='corrected line')
```

For content issues (orphaned bullets, duplicate sections, trailing whitespace):
```yaml
skill_manage(action='patch', name='skill-name', old_string='problematic text', new_string='fixed text')
```

For major structural issues:
```yaml
skill_manage(action='edit', name='skill-name', content='...full new content...')
```

## Common Pitfalls

1. **Don't edit bundled skills.** `hermes-agent-skill-authoring`, `hermes-agent`, and hub-installed skills are protected. Skip them — they are maintained upstream.
2. **Frontmatter drift is cumulative.** Skills created by lower-quality models consistently miss `platforms` and `metadata.hermes.related_skills`. Run this review regularly to catch drift.
3. **Truncation artifacts appear as orphans.** When a model's context fills up during skill creation, the last section gets cut mid-sentence. Look for orphaned bullet points with no section header.
4. **Hallucinated references are common.** AI-generated skills often invent references to skills that don't exist. Always validate against the actual skill list before patching.
5. **The user-local tree has no DESCRIPTION.md files.** Unlike the in-repo tree, user-local skills don't need category-level DESCRIPTION.md files. Don't create them unless explicitly requested.

## Verification Checklist

- [ ] All user-local skills reviewed (verify count with `find`)
- [ ] Frontmatter completeness checked for all skills
- [ ] No orphaned bullets or duplicate sections remain
- [ ] No hallucinated skill references exist
- [ ] All patches verified by re-reading patched files
- [ ] Summary produced with pass/fail counts and change list

## Output Format

```
## Weekly Skill Quality Review — Summary

**Total skills reviewed:** N
**Skills needing changes:** N
**Skills passing:** N

### Changes Applied

| # | Skill | Issue | Fix |
|---|-------|-------|-----|
| 1 | ... | ... | ... |

### Skills That Passed
[list of passing skills]
```
