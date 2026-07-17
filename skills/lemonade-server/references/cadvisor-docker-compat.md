# cAdvisor + Docker Compatibility

## Docker 29 + containerd-snapshotter breaks cAdvisor

Docker Engine 29+ enables `containerd-snapshotter` as the default image storage
backend. This changes the internal metadata structure from the classic
`/var/lib/docker/image/overlay2/layerdb/` layout to containerd's snapshotter
layout, which cAdvisor cannot read.

**Symptom:** `container_memory_working_set_bytes` (and all other
`container_*` metrics) are empty or zero. cAdvisor logs show:

```
Registration of the docker container factory failed: failed to validate Docker info:
  Error response from daemon: client version 1.41 is too old.
  Minimum supported API version is 1.44
```

Or (with newer cAdvisor that supports the API version):

```
Failed to create existing container: ... failed to identify the read-write layer ID
  for container "...". - open /rootfs/var/lib/docker/image/overlayfs/layerdb/mounts/.../mount-id:
  no such file or directory
```

**Fix:** Disable containerd-snapshotter in `/etc/docker/daemon.json`:

```json
{
  "features": {
    "containerd-snapshotter": false
  }
}
```

Then restart Docker and cAdvisor. This reverts Docker to the overlay2 storage
driver that cAdvisor understands.

**Ansible pattern** (from homelab `roles/docker/tasks/main.yml`):

```yaml
- name: Configure Docker daemon
  ansible.builtin.copy:
    dest: /etc/docker/daemon.json
    content: |
      {
        {% if docker_data_root is defined -%}
        "data-root": "{{ docker_data_root }}",
        {% endif -%}
        "features": {
          "containerd-snapshotter": false
        }
      }
    mode: "0644"
  notify: Restart docker
```

The task is unconditional — every Docker host gets the flag, not just hosts
with a custom data-root.

## Verification

```bash
docker info | grep -i 'storage driver\|snapshotter'
# Expected: Storage Driver: overlay2  (no containerd-snapshotter line)

docker logs cadvisor 2>&1 | grep 'docker container factory'
# Expected: Registration of the docker container factory successfully
```

## cAdvisor image registry note

Newer cAdvisor images (v0.53.0+) are published to `ghcr.io/google/cadvisor`,
not `gcr.io/cadvisor`. The `gcr.io` `latest` tag is stuck at v0.49.1 which
uses Docker API v1.41 — too old for Docker 29 (requires v1.44+). Always pin
the ghcr.io image with an explicit version tag.

## Reference

- GitHub issue: https://github.com/google/cadvisor/issues/3749
- Fix PR (containerd-snapshotter support): https://github.com/google/cadvisor/pull/3709
