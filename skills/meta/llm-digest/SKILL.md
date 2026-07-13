---
name: llm-digest
description: Use when running the daily LLM/Local AI news digest cron job. Searches for tools, models, and updates relevant to the user's Strix Halo + Hermes setup; writes a dated digest to ~/homelab/docs/digests/; checks recent digests to avoid duplicating past recommendations; commits and pushes to the homelab repo.
version: 1.1.0
author: Hermes Agent
license: MIT
platforms: [linux, macos, windows]
metadata:
  hermes:
    tags: [llm, digest, cron, amd, strix-halo, local-ai, newsletter]
    related_skills: [hermes-agent]
---

# LLM News Digest (Cron Workflow)

## Overview

Writes a daily digest of LLM/Local AI news relevant to the user's hardware setup into `~/homelab/docs/digests/llm-digest-YYYY-MM-DD.md`. Checks the last 7 days of digests to avoid re-reporting the same recommendations. Commits and pushes to the homelab repo.

## When to Use

- Running the `llm-tools-daily-scout` cron job
- Any time you need to produce a new LLM digest entry

## Setup

Ensure the directory exists:

```bash
mkdir -p ~/homelab/docs/digests
```

## Workflow (numbered steps)

1. **Read recent digests for dedup**
   List `~/homelab/docs/digests/llm-digest-*.md` files from the last 7 days. Read the "Recommendations" section of each. Build a set of already-recommended items (model names, tools, GitHub repos, specific quantization formats, version numbers).

2. **Search the web**
   Search broadly (Reddit, HuggingFace, GitHub, news) for LLM developments in the last 24-48 hours. Key sources:
   - Reddit: r/LocalLLaMA, r/hermesagent, r/LocalLLM, r/Ollama
   - HuggingFace trending models
   - GitHub repos for AMD/ROCm/Vulkan LLM tools
   - Hermes Agent release notes
   - llama.cpp developments

3. **Filter and prioritize**
   Only keep findings relevant to this user's setup:
   - **Raspberry Pi** running Hermes Agent
   - **Framework Desktop** with Ryzen AI MAX+ 395 / Strix Halo / gfx1151 / 128 GB RAM
   - **Ollama** and **Lemonade Server** with Vulkan/ROCm backends
   - **llama.cpp** with ROCm or Vulkan
   - **Tailscale** networking
   Skip things that are cloud-only, API-only with no local relevance, or already covered in recent digests.

4. **Write the digest file**
   Create `~/homelab/docs/digests/llm-digest-YYYY-MM-DD.md` with this exact structure:

   ```markdown
   # LLM Digest — YYYY-MM-DD

   ## Digest

   Brief news items (what, why it matters, link). Group by category if multiple.
   Keep each finding to 2-3 sentences max. Include:
   - What it is
   - Why it matters to this setup (Strix Halo / Hermes / AMD / llama.cpp)
   - Source link

   ## Recommendations

   Actionable items the user should consider enacting. Each with a severity tag and file reference:

   ### Critical
   - **[ACTION]** Brief description of the change needed. Link to source. Reference the relevant homelab doc (e.g. `[llm-strix-halo.md](../llm-strix-halo.md)`).

   ### Useful to evaluate
   - **[EVALUATE]** Brief description. Link to source.

   ### Watch / low priority
   - **[WATCH]** Brief description. Link to source.

   If no recommendations, write: `None at this time.`

   ## User Feedback

   > [Leave notes here about what you tried, whether it worked, or any questions.]
   >
   > — [Date you acted on it]
   ```

5. **Preflight check the homelab repo**
   Before committing, verify the repo is properly configured:
   ```bash
   cd ~/homelab
   # Check it is a git repo with a remote
   [ -d .git ] && git remote -v | grep -q 'origin' || {
     echo "WARN: ~/homelab is not a git repo or has no remote configured — commit locally only"
     NEEDS_REMOTE_SETUP=1
   }
   ```
   If `NEEDS_REMOTE_SETUP=1`, commit locally but skip the push. Notify the user that the repo needs a remote configured.

6. **Commit and push to the homelab repo**
   ```bash
   cd ~/homelab
   git add docs/digests/llm-digest-YYYY-MM-DD.md
   git commit -m "digest: LLM news digest for YYYY-MM-DD"
   git pull --rebase
   git push
   ```
   If the push is rejected (remote has changes), do `git pull --rebase` first, then push again.
   If no remote is configured (from step 5 preflight), skip push — the commit is still saved locally.

6. **Produce a concise summary for delivery**
   Return a brief summary of the digest (digest items + recommendations) as the final response. Do NOT output the full file content — just the highlights. If nothing notable was found, return `[SILENT]`.

## Common Pitfalls

1. **Duplicating past recommendations** — always check the last 7 days before writing. A model that was "recommended to watch" 3 days ago does not need to be recommended again.
2. **Over-reporting API-only models** — skip 1T-parameter models with no local relevance. Focus on things that could run on 128 GB unified memory or improve the local inference stack.
3. **Forgetting to push** — the digest must be committed AND pushed to the homelab repo so it's tracked remotely.
4. **Not tagging severity** — every recommendation must have a severity tag (Critical / Useful to evaluate / Watch).
5. **Writing too much** — the delivery should be a summary. The full digest lives in the file.
6. **Push rejection** — if git push is rejected, always `git pull --rebase` before retrying.

## Verification Checklist

- [ ] Read last 7 days of digests for dedup
- [ ] Digest file created at `~/homelab/docs/digests/llm-digest-YYYY-MM-DD.md`
- [ ] File has all 3 sections: Digest, Recommendations, User Feedback
- [ ] Recommendations tagged with severity
- [ ] Committed and pushed to ~/homelab/
- [ ] Delivery message is a summary, not full file content