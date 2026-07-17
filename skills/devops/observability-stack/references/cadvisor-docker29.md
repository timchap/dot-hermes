# cAdvisor + Docker 29 containerd-snapshotter Breakage

## Problem

Docker Engine 29+ enables `containerd-snapshotter` as the default image storage
backend. This changes the internal metadata structure from the classic
`/var/lib/docker/image/overlay2/layerdb/` layout to containerd's snapshotter
layout. cAdvisor relies on the overlay2 layerdb metadata to identify container
read-write layers, so when the Docker factory tries to register it fails with:

```
Registration of the docker container factory failed: failed to validate Docker info:
failed to detect Docker info: Error response from daemon: client version 1.41
is too old. Minimum supported API version is 1.44
```

And even with a cAdvisor version that supports the new API (v0.53.0+), the
layerdb path is still missing:

```
Failed to create existing container: failed to identify the read-write layer ID
for container "{id}". open /rootfs/var/lib/docker/image/overlayfs/layerdb/mounts/{id}/mount-id:
no such file or directory
```

When `--docker_only=true` is set and the Docker factory fails, cAdvisor has
nothing to report. All `container_*` metrics are empty, which means
`container_memory_working_set_bytes` shows zero for every container in Grafana.

## Fix

Two parts (both needed):

1. **Disable containerd-snapshotter** in `/etc/docker/daemon.json`:
   ```json
   {
     "features": {
       "containerd-snapshotter": false
     }
   }
   ```
   This reverts Docker to the classic overlay2 storage driver.

2. **Use a recent cAdvisor image** (v0.53.0+ from ghcr.io, or v0.60.5 which
   is what this homelab pins). The old gcr.io/cadvisor/cadvisor:latest is
   pinned at v0.49.1 and uses Docker API v1.41, which Docker 29 rejects.

In this homelab, both are handled by the Ansible roles:
- `ansible/roles/docker/tasks/main.yml` writes the daemon.json with
  `containerd-snapshotter: false` (unconditionally, for all hosts)
- `services/observability/compose.yaml` pins `ghcr.io/google/cadvisor:v0.60.5`

## Applying

```bash
cd ~/homelab/ansible
ansible-playbook playbooks/pi-services.yml --limit pi-services-0 --tags docker,observability
```

The Docker role restarts Docker (daemon.json changed), then the observability
role recreates cAdvisor. All containers on pi-services-0 will briefly restart
during the Docker daemon restart.

## Verification

```bash
ssh pi-services-0 'docker info | grep -i "storage driver\|snapshotter"'
# Expected: Storage Driver: overlay2  (no containerd-snapshotter line)

ssh pi-services-0 'docker logs cadvisor 2>&1 | grep "docker container factory"'
# Expected: Registration of the docker container factory successfully
```

After verification, container memory metrics will populate in Grafana within
1-2 scrape intervals (15s each).

## Source

- GitHub issue: https://github.com/google/cadvisor/issues/3749
- The issue has 29+ thumbs and was closed. Key comment from @vigenere23
  identified the two separate problems (API version + containerd-snapshotter).
- cAdvisor images moved from gcr.io to ghcr.io/google/cadvisor for newer tags.
