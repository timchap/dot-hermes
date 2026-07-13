---
name: cron-troubleshooting
description: Diagnose, troubleshoot, and fix Hermes Agent cron job issues — missed runs, delivery failures, model/provider misconfigurations, and scheduling behavior.
category: meta
---

# Cron Troubleshooting

Diagnose why cron jobs didn't run, didn't deliver, or ran unexpectedly. Covers the Hermes internal scheduler (conversation-loop-dependent) and the `cronjob` tool.

## How Cron Actually Works (Critical)

**Hermes cron jobs execute within the conversation loop, NOT as a background daemon.** The scheduler checks for due jobs only when the agent is in an active conversation turn. When the agent is idle (no user session), cron never fires.

This means:
- If you're using the Web UI for a session and close it, cron stops ticking
- If no one interacts with Hermes for hours, overnight cron jobs (3 AM, 4 AM, 6 AM, etc.) will be skipped
- Cron jobs fire when the NEXT conversation turn starts after their scheduled time
- There is no separate `hermes-scheduler` systemd service — it lives inside the agent process

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

### Cron job using wrong model/provider
Check `cronjob action='list'` for `model` and `provider` fields. Update with:
```
cronjob action='update' job_id='...' model='{model: "...", provider: "..."}'
```

### Cron job running way late
This happens when the agent was down/idle and the job fires on the next turn. Not a scheduling bug — expected behavior of conversation-loop scheduling.

### Cron job never ran at all
Check:
1. Job is enabled (`"enabled": true`)
2. Agent process is running
3. Agent was in an active conversation turn when the job should have fired
4. No errors in `~/.hermes/logs/errors.log`

## Fixing Delivery Gaps

If the user needs reliable overnight delivery:

1. **Best option:** Set `deliver` to a messaging platform the user checks regularly:
   ```
   cronjob action='update' job_id='...' deliver='all'
   ```

2. **Alternative:** Use the `no_agent` mode with a script that produces its own output and delivers via a messaging gateway.

3. **Accept the model:** Document the behavior so the user knows to check `cronjob list` after waking up.

## Support Files

- `references/log-diagnostic-patterns.md` — concrete log analysis patterns for cron issues
- `references/delivery-model-explainer.md` — explainer on deliver modes for user-facing use
