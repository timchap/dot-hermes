# WebUI Delivery Mismatch — Full Diagnostic

## Problem

Cron job runs (`last_status: "ok"`) but user never receives the output.
`last_delivery_error` shows `"unknown platform 'webui'"`.

## Diagnostic Steps

1. **Verify the job actually ran:**
   ```
   cronjob action='list'
   ```
   Look at `last_status` and `last_run_at`. If status is `"ok"`, the job executed.

2. **Check delivery error:**
   Look at `last_delivery_error` field. `"unknown platform 'webui'"` confirms this issue.

3. **Confirm active session platform:**
   Was the user on the WebUI when the job ran? WebUI has no gateway-connected platform to receive `deliver: origin` output.

4. **Check if output was saved locally:**
   ```
   ls -la ~/.hermes/cron/output/
   ```
   Look for a file with a recent timestamp. The output exists here regardless of delivery.

## Fix

Change the job's `deliver` to a platform the user actually checks:

```
cronjob action='update' job_id='JOB_ID' deliver='all'
```

This fans output to ALL connected platforms (Discord, Telegram, etc.).

Alternatively, target a specific platform:
```
cronjob action='update' job_id='JOB_ID' deliver='discord'
```

## Prevention

When creating cron jobs:
- From **WebUI**: never use `deliver='origin'` — it will fail silently
- Use `deliver='all'` to reach all connected platforms
- Or use `deliver='discord'` (or whichever platform the user checks)

## Root Cause

`deliver: origin` routes to the active session's platform type. Hermes has built-in support for Discord, Telegram, and other gateway-connected platforms, but the WebUI session has no platform type — it's just a browser tab. The output is discarded, not saved anywhere the user expects.
