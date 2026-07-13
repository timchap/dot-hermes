# Cron Job Provider/Model Drift Diagnostic

## Cause

When a cron job is created without pinning `provider` or `model`, it uses the **current defaults at creation time**. If the user later changes their default model/provider (e.g. `default: Qwen3.6-35B-A3B-MTP-GGUF` via `custom:framework`), existing unpinned jobs become stale.

On next execution, Hermes detects the drift and blocks the job with:
```
RuntimeError: Skipped to prevent unintended spend: global inference config drifted since this job was created (provider 'openrouter' -> 'custom'; model 'qwen/qwen3.6-35b-a3b' -> 'qwen3.6-35b-a3b-mtp-gguf'), and this job is unpinned.
```

## Prevention

Always pin `provider` and `model` when creating cron jobs, especially when the user has non-default defaults:
```
hermes cron create --name "my job" --provider openrouter --model qwen/qwen3.6-35b-a3b --schedule "..."
```

## Diagnostic

1. Check `cronjob action='list'` for any jobs with `last_status` = `"error"` and a drift message
2. Cross-reference `cron/jobs.json` against `config.yaml` model/provider defaults:
   ```python
   import json
   with open('/home/hermes/.hermes/cron/jobs.json') as f:
       data = json.load(f)
   for job in data.get('jobs', []):
       if job.get('provider') is None and job.get('model') is None:
           print(f"UNPINNED: {job['name']} (id={job['id']})")
   ```
3. Pin each unpinned job via direct `jobs.json` edit (CLI has no provider/model edit flags):
   ```python
   import json
   with open('/home/hermes/.hermes/cron/jobs.json', 'r') as f:
       data = json.load(f)
   for job in data['jobs']:
       if job['id'] == 'JOB_ID_HERE':
           job['provider'] = 'openrouter'
           job['model'] = 'qwen/qwen3.6-35b-a3b'
           break
   with open('/home/hermes/.hermes/cron/jobs.json', 'w') as f:
       json.dump(data, f, indent=2)
       f.write('\n')
   ```

## Notes

- `hermes cron edit` does NOT support `--provider` or `--model` flags — only `--schedule`, `--prompt`, `--name`, `--deliver`, `--repeat`, `--skill`, `--script`, `--workdir`, `--no-agent`, `--agent`
- The `_config_version` increment in config.yaml is unrelated to this — it's a separate mechanism
- Pinning uses the `provider` and `model` fields; the job will also record `provider_snapshot` and `model_snapshot` to track the pinned values
- The drift error only fires when the job actually attempts execution — unpinned jobs don't fail silently
