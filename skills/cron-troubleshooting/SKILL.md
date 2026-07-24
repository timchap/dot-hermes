---
name: cron-troubleshooting
description: Diagnose, troubleshoot, and fix Hermes Agent cron job issues — missed runs, delivery failures, model/provider misconfigurations, and scheduling behavior.
category: meta
---

# Cron Troubleshooting

Diagnose why cron jobs didn't run, didn't deliver, or ran unexpectedly. Covers the Hermes internal scheduler (conversation-loop-dependent) and the `cronjob` tool.

## How Cron Actually Works (Critical)

**The cron ticker runs inside the Hermes gateway process (or desktop dashboard backend), NOT the agent conversation process.** It is a background thread that ticks every ~60 seconds and fires due jobs.

The tick thread starts via:
- `gateway/run.py::GatewayRunner._start_cron_ticker` when running `hermes gateway run`
- `hermes_cli/web_server.py::_start_desktop_cron_ticker` when running `hermes dashboard` in desktop mode

**Key implication:** If the gateway process is not running, cron does not fire regardless of whether the agent conversation process is active. The gateway process and the agent conversation process are separate things.

This means:
- If the gateway is down (e.g., not installed as a systemd service), overnight cron jobs will be skipped
- If you close the Web UI but the gateway is running as a daemon, cron continues to fire
- Cron jobs fire based on wall-clock time via the tick loop, not when the next conversation turn starts
- There is no separate `hermes-scheduler` systemd service — the tick lives inside the gateway/dashboard process
- Installing the gateway as a persistent service (`sudo hermes gateway install --system`) is the fix for reliable overnight cron execution

**User expectation mismatch:** Users often assume cron jobs are independent daemons (like a traditional crontab). They are not. The gateway must be running 24/7 for jobs to fire at their scheduled times. If the user objects to this model, the alternatives are:
- Run the gateway as a systemd service (recommended)
- Use `no_agent: true` with a shell script that uses an external scheduler (e.g., systemd timers, cron) to trigger Hermes via CLI

## Diagnosing Missed Cron Runs

1. **Check `cronjob action='list'`** — look at `last_run_at` vs `next_run_at` for all jobs
2. **Check the agent log for the gap period:**
   ```
   grep '2026-07-13 0[1-8]:' ~/.hermes/logs/agent.log | head -20
   ```
   If there's no `run_agent:` or `Turn ended:` in that window, the agent was idle
3. **Check the process list:**
   ```
   ps aux | grep hermes
   ```
   If the agent process isn't running at all, it crashed or was stopped
4. **Cross-reference:** If the log shows idle/waiting during the scheduled window, the job was missed because no conversation turn was active

## Delivery Model

Cron jobs have `deliver: origin` by default — this means output goes to the **current active session**. It does NOT push a notification.

- `deliver: origin` → lands in the chat session that exists when the job runs. If no session is active, it's stored but not delivered.
- `deliver: all` → fans out to all connected messaging platforms (Discord, Telegram, etc.)
- `deliver: 'telegram:CHAT_ID:TOPIC_ID'` → targets a specific platform/topic

If the user expects push notifications, configure `deliver` to a gateway-connected platform or use `deliver: all`.

## Common Issues

### Cron never fires overnight
The agent was idle. Fix: ensure a persistent session is running, or acknowledge this is expected behavior and check results when you next connect.

### Cron fired but you got no message
The job delivered to a session that was no longer open. Check `cronjob action='list'` for `last_run_at` and `last_status`. Search past sessions via `session_search` to find the result.

### Cron job ran successfully but output never reached me (WebUI delivery mismatch)
**Symptom:** The user sees that a cron job has `last_status: "ok"` and `last_delivery_error` like `"unknown platform 'webui'"`, or simply asks "why did the most recent cron job fail to deliver output?" even though the job clearly ran.

**Root cause:** `deliver: origin` routes output to the **active session's platform type** (Discord, Telegram, Slack, etc.). The WebUI is NOT a recognized delivery platform. If the job ran while the user was on the WebUI, the output was generated but there was no gateway-connected platform to route it through. The result IS saved to `~/.hermes/cron/output/` but is invisible unless the user explicitly checks there.

**Fix:**
1. **Check `cronjob action='list'`** — look at `last_status` and `last_delivery_error`. If `last_status` is `"ok"` but `last_delivery_error` mentions `"webui"` or `"unknown platform"`, this is the issue.
2. **Change deliver target** — set `deliver` to a connected gateway platform or `all`:
   ```
   cronjob action='update' job_id='...' deliver='all'
   ```
3. **Tell the user where to find results** — outputs always land in `~/.hermes/cron/output/` regardless of delivery target. Show them the path if they want to check manually.

See `references/webui-delivery-mismatch.md` for the full diagnostic flow.

### Cron job using wrong model/provider
**Symptom:** Job fails with `"global inference config drifted since this job was created (provider 'X' -> 'Y')"` or similar drift error. This happens when a job was created without pinning provider/model, then the user's default config changes.

**Fix:** The `hermes cron edit` CLI does NOT have provider/model flags. Pin the job by directly editing `~/.hermes/cron/jobs.json`:

```python
import json
with open('/home/hermes/.hermes/cron/jobs.json', 'r') as f:
    data = json.load(f)
for job in data['jobs']:
    if job['id'] == 'JOB_ID_HERE':
        job['provider'] = 'openrouter'  # or desired provider
        job['model'] = 'qwen/qwen3.6-35b-a3b'  # or desired model
        break
with open('/home/hermes/.hermes/cron/jobs.json', 'w') as f:
    json.dump(data, f, indent=2)
    f.write('\n')
```

Then verify: `cronjob action='list'` to confirm the job is fixed.

**Workflow pitfall:** When updating provider/model for multiple jobs, ALWAYS confirm the desired provider with the user first — they may change their mind mid-session (e.g., start wanting openrouter then switch to custom:framework). Making batch updates before confirmation has happened leads to rework. Better flow: list jobs, ask "which provider/model for all of these?", get explicit confirmation, then batch-update.

### Cron job running way late
This happens when the agent was down/idle and the job fires on the next turn. Not a scheduling bug — expected behavior of conversation-loop scheduling.

### Cron job never ran at all
Check:
1. Job is enabled (`"enabled": true`)
2. Agent process is running
3. Agent was in an active conversation turn when the job should have fired
4. No errors in `~/.hermes/logs/errors.log`

## Setting One-Shot Reminders from CLI/TUI

**CRITICAL PATTERN:** When creating a one-shot reminder cron job from a CLI/TUI session, the default `deliver='local'` means the output is saved but **never delivered** — CLI/TUI sessions have no live-delivery channel. The user will never see the reminder.

**Always set `deliver='origin'` (or a specific gateway like `deliver='discord'`)** when creating reminder jobs from CLI/TUI:

```
cronjob action='create' schedule='2026-07-16T17:30:00+02:00' deliver='origin' prompt='Remind the user to ...'
```

- `deliver='origin'` → routes through connected gateway platforms (Discord, Telegram, etc.). Works when the user has a gateway configured.
- `deliver='all'` → fans out to ALL connected platforms. Use when the user checks multiple platforms.
- `deliver='local'` (default) → saves to disk only. **Never use this for reminders from CLI/TUI.**

If you are unsure which gateways are connected, check `~/.hermes/config.yaml` for gateway entries (e.g. `discord:`, `telegram:`). If Discord is listed, `deliver='origin'` will route there.

**Always inform the user** that the reminder will arrive via a specific platform, not in the current terminal.

## Fixing Delivery Gaps

If the user needs reliable overnight delivery:

1. **Best option:** Set `deliver` to a messaging platform the user checks regularly:
   ```
   cronjob action='update' job_id='...' deliver='all'
   ```

2. **Alternative:** Use the `no_agent` mode with a script that produces its own output and delivers via a messaging gateway.

3. **Accept the model:** Document the behavior so the user knows to check `cronjob list` after waking up.

## Support Files

- `references/webui-delivery-mismatch.md` — Full diagnostic flow for WebUI delivery failures
- `references/provider-drift-diagnostic.md` — Provider/model drift diagnostics
