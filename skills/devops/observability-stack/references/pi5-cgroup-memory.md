# Raspberry Pi 5 cgroup Memory Disable

## Problem

Raspberry Pi 5 firmware injects `cgroup_disable=memory` into the kernel command
line at boot. This is baked into the DTB (device tree blob), not in
`/boot/firmware/cmdline.txt`, so it's invisible in the usual Pi config files.

### Symptoms

- Docker Compose warns: `Your kernel does not support memory limit capabilities
  or the cgroup is not mounted. Limitation discarded.`
- `cat /sys/fs/cgroup/cgroup.controllers` shows `cpuset cpu io pids` (no `memory`)
- `dmesg | grep cgroup` shows: `cgroup: Disabling memory control group subsystem`
- Container `mem_limit` in compose.yaml is silently ignored

### Why

The Pi Foundation disables memory cgroup accounting by default because it has a
small per-page overhead (~0.5-1% of RAM). On older Pis with 256MB-1GB this
mattered. On a Pi 5 with 8GB+ it's negligible (~40-80MB).

## Fix

Add `cgroup_enable=memory` to the end of `/boot/firmware/cmdline.txt`:

```
console=serial0,115200 console=tty1 root=PARTUUID=... rootfstype=ext4 fsck.repair=yes rootwait quiet splash plymouth.ignore-serial-consoles ... cgroup_enable=memory
```

The firmware prepends its own args (including `cgroup_disable=memory`) and
appends `cmdline.txt` last. The kernel processes `cgroup_enable` and
`cgroup_disable` left-to-right, so the last one wins. Since cmdline.txt comes
after the firmware args, `cgroup_enable=memory` overrides the firmware's
`cgroup_disable=memory`.

Then reboot:
```bash
sudo reboot
```

### Verify

```bash
cat /sys/fs/cgroup/cgroup.controllers
# Should now include: cpuset cpu io memory pids

docker run --rm --memory=128m alpine echo "memory limit works"
# Should print "memory limit works" with no warning
```

## Affected Hosts

This applies to all Raspberry Pi 5 hosts in the homelab:
- `pi-services-0` (observability stack, hindsight, google-mcps)
- `pi-hermes` (Hermes agent, Home Assistant)

The fix is a one-time boot config change that survives kernel upgrades.

## Ansible Integration

Not yet automated — it's a `lineinfile` on `/boot/firmware/cmdline.txt` that
could be added to the common role. The complication is that cmdline.txt is a
single line with no trailing newline, and the file is boot-critical — a typo
prevents the Pi from booting. Manual editing with careful verification is the
current approach.

## Source

- GitHub issue: https://github.com/raspberrypi/linux/issues/6980
- Forum thread: https://forums.raspberrypi.com/viewtopic.php?t=389843
- The downstream-only `cgroup_enable=memory` parameter is the Pi Foundation's
  recommended override mechanism.
