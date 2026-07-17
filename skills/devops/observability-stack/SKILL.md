---
name: observability-stack
description: Deploy, configure, and troubleshoot the homelab observability stack — Prometheus, Grafana, cAdvisor, node exporters, Phoenix tracing, and Lemonade metrics on pi-services-0.
version: 1.0.0
author: Hermes Agent
license: MIT
platforms: [linux]
metadata:
  hermes:
    tags: [observability, prometheus, grafana, cadvisor, phoenix, monitoring, homelab]
---

# Observability Stack

Manage the homelab's monitoring and tracing stack on `pi-services-0`:
Prometheus, Grafana, cAdvisor, node exporters, Arize Phoenix, and Lemonade
metrics. The Ansible role lives at `ansible/roles/observability/`, compose at
`services/observability/compose.yaml`, dashboards under
`services/observability/grafana/provisioning/dashboards/`, and docs at
`docs/observability.md`.

## Architecture

```
node_exporter (each host) ──┐
cAdvisor (pi-services-0)  ──┤── Prometheus (:9090, localhost) ── Grafana (:3000)
Lemonade /metrics (framework)┘
Phoenix (:6006) ← Lemonade OTLP traces
```

Prometheus uses `network_mode: host` and scrapes:
- `127.0.0.1:9100` (local node exporter)
- `192.168.1.82:9100` (framework node exporter, LAN)
- `pi-hermes:9100` (tailnet)
- `127.0.0.1:8080` (cAdvisor)
- `framework:13305/metrics` (Lemonade)

## Deploy

```bash
cd ~/homelab/ansible
ansible-playbook playbooks/pi-services.yml --limit pi-services-0 --tags observability
```

Node exporters on remote hosts:
```bash
ansible-playbook playbooks/site.yml --limit framework --tags node_exporter
ansible-playbook playbooks/hermes-pi.yml --limit pi-hermes --tags node_exporter
```

## Grafana Dashboard Patterns

Dashboards are provisioned as JSON in
`services/observability/grafana/provisioning/dashboards/`. Key conventions:

- `editable: false` — dashboards are Git-managed, not editable in UI
- `datasource: {"type": "prometheus", "uid": "prometheus"}` — the provisioned datasource
- Panel `id` must be unique within each dashboard
- Bump `version` when changing a dashboard so Grafana picks up the update
- Full-width panels: `"gridPos": {"h": 8, "w": 24, "x": 0, "y": N}`
- Half-width panels: `"gridPos": {"h": 8, "w": 12, "x": 0|12, "y": N}`

### Useful PromQL by panel type

| Panel | Expr |
|---|---|
| CPU usage per host | `100 - (avg by (host) (rate(node_cpu_seconds_total{mode="idle"}[5m])) * 100)` |
| Host memory used | `node_memory_MemTotal_bytes - node_memory_MemAvailable_bytes` |
| Disk utilization % | `100 * (1 - node_filesystem_avail_bytes{fstype!~"tmpfs\|vfat",mountpoint!~"/boot.*"} / node_filesystem_size_bytes{fstype!~"tmpfs\|vfat",mountpoint!~"/boot.*"})` |
| Container memory | `sum by (name) (container_memory_working_set_bytes{name!=""})` |
| GPU utilization | `lemonade_gpu_usage_percent` |
| VRAM used | `lemonade_vram_used_gb` |
| Token throughput | `sum by (model_name) (rate(lemonade_output_tokens_total[5m]))` |

## cAdvisor + Docker 29 (containerd-snapshotter)

**Pitfall**: Docker 29+ enables `containerd-snapshotter` by default. This
breaks cAdvisor's Docker factory — it can't find the overlay2 layerdb metadata
(`google/cadvisor#3749`). Symptom: `container_memory_working_set_bytes` is
empty/zero for all containers; cAdvisor logs show "Registration of the docker
container factory failed".

**Fix**: Disable containerd-snapshotter in `/etc/docker/daemon.json`:
```json
{
  "features": {
    "containerd-snapshotter": false
  }
}
```
This is already handled by the Docker role
(`ansible/roles/docker/tasks/main.yml`). To apply:
```bash
ansible-playbook playbooks/pi-services.yml --limit pi-services-0 --tags docker,observability
```

**Verify**:
```bash
ssh pi-services-0 'docker logs cadvisor 2>&1 | grep "docker container factory"'
# Expected: Registration of the docker container factory successfully
```

## Storage Management

All observability data lives under `/mnt/docker/observability/` on the
pi-services-0 USB SSD (1 TB).

| Component | Bounded by |
|---|---|
| Prometheus TSDB | `--storage.tsdb.retention.time=14d` + `--storage.tsdb.retention.size=2GB` (whichever hits first) |
| Phoenix traces | `PHOENIX_DEFAULT_RETENTION_POLICY_DAYS=30` — weekly auto-purge |
| Grafana | Negligible (dashboard metadata only) |
| cAdvisor / node exporters | Stateless — no disk growth |

Docker images for the stack consume SSD space under `/mnt/docker`. Prune with
`docker image prune -f` if disk pressure becomes a concern.

## Lemonade Metrics

Lemonade 10.9.0+ exposes these at `http://framework:13305/metrics`:

| Metric | Type | Description |
|---|---|---|
| `lemonade_gpu_usage_percent` | gauge | GPU utilization % |
| `lemonade_cpu_usage_percent` | gauge | CPU utilization % |
| `lemonade_npu_usage_percent` | gauge | NPU utilization % |
| `lemonade_vram_used_gb` | gauge | GPU memory in GiB |
| `lemonade_memory_used_gb` | gauge | System memory in GiB |
| `lemonade_model_tokens_per_second` | gauge | Latest decode speed per model |
| `lemonade_model_time_to_first_token_seconds` | gauge | TTFT per model |
| `lemonade_output_tokens_total` | counter | Cumulative output tokens |
| `lemonade_prompt_tokens_total` | counter | Cumulative prompt tokens |
| `lemonade_llamacpp_*` | various | Per-slot llama.cpp internals |

Note: `lemonade_gpu_usage_percent` reads 0 when no inference is in flight —
it's a real-time gauge, not a counter.

## Phoenix Tracing

Phoenix runs as a Docker container on pi-services-0 (`:6006`). Lemonade on
Framework exports OpenInference spans to its OTLP HTTP receiver. Trace content
(prompt/response text) visibility is controlled by
`lemonade_telemetry_hide_inputs/outputs/thinking` in host_vars/framework.yml.

To change trace retention, either set `PHOENIX_DEFAULT_RETENTION_POLICY_DAYS`
in compose.yaml (applies to all new projects) or configure per-project
retention policies in the Phoenix UI.

## Raspberry Pi 5 cgroup Memory Disable

**Pitfall**: Raspberry Pi 5 firmware defaults include `cgroup_disable=memory` in
the kernel command line (baked into the DTB, not in `/boot/firmware/cmdline.txt`).
This prevents Docker from applying `mem_limit` on containers — you'll see:
```
unknown <container>: Your kernel does not support memory limit capabilities or
the cgroup is not mounted. Limitation discarded.
```
And `cat /sys/fs/cgroup/cgroup.controllers` will show `cpuset cpu io pids`
(no `memory`).

**Fix**: Add `cgroup_enable=memory` to the end of `/boot/firmware/cmdline.txt`
(the firmware's args come first, cmdline.txt is appended last, kernel is
last-wins). Then reboot. This is a one-time change that survives kernel upgrades.

**Verify**:
```bash
cat /sys/fs/cgroup/cgroup.controllers
# Should include: cpuset cpu io memory pids
```

The Pi Foundation disables memory cgroups by default because accounting has a
small per-page overhead (~0.5-1% of RAM). On an 8GB+ Pi 5 this is negligible.

See [references/pi5-cgroup-memory.md](references/pi5-cgroup-memory.md) for
background and the GitHub issue tracking this.

## Troubleshooting

### Container memory zero in Grafana
See [cAdvisor + Docker 29](#cadvisor--docker-29-containerd-snapshotter) above.

### Docker mem_limit warnings on Raspberry Pi
See [Raspberry Pi 5 cgroup Memory Disable](#raspberry-pi-5-cgroup-memory-disable) above.

### Lemonade metrics not appearing
1. Check the Lemonade job is UP in Prometheus: `curl http://pi-services-0:9090/api/v1/targets | jq '.data.activeTargets[] | select(.labels.job=="lemonade")'`
2. Confirm metrics are exposed: `curl http://framework:13305/metrics | head -20`
3. Check Tailscale connectivity from pi-services-0 to framework:13305

### Prometheus target down
- node exporter: check the container is running on the target host
- cAdvisor: check `docker logs cadvisor` on pi-services-0
- lemonade: check Lemonade is running on Framework and port 13305 is reachable via tailnet

## References

- [cAdvisor Docker 29 issue](references/cadvisor-docker29.md) — detailed issue analysis and fix from google/cadvisor#3749
