---
name: smart-home
description: Use when controlling smart home devices — lights, switches, sensors, and home automation systems via Home Assistant, MQTT, or similar platforms.
version: 1.0.0
author: Hermes Agent
license: MIT
platforms: [linux, macos, windows]
metadata:
  hermes:
    tags: [smart-home, home-assistant, mqtt, iot, automation, lights, sensors, zigbee]
    related_skills: [hermes-agent, systemd-services]
---

# Smart Home Control

Control smart home devices — lights, switches, sensors, and home automation systems.

## Overview

This skill covers interacting with smart home ecosystems to query state, change settings, automate routines, and troubleshoot device connectivity.

## When to Use

- User asks to turn on/off lights, check sensor readings, or control any smart home device
- Setting up automations or routines (e.g. "turn on lights at sunset")
- Troubleshooting why a device isn't responding
- Adding new devices to the smart home system

## Supported Platforms

- **Home Assistant** — primary platform, via REST API or MQTT
- **MQTT** — direct device control via publish/subscribe
- **Zigbee/Z-Wave** — via Home Assistant or direct coordinator access

## Prerequisites

Ensure the home automation backend is running:

```bash
# Home Assistant check
curl -s http://localhost:8123/api/states | head -c 500

# MQTT check
mosquitto_sub -h localhost -t "#" -C 1 -W 5
```

## Controlling Devices

### Home Assistant API

```bash
# Get all entities
curl -H "Authorization: Bearer $HA_TOKEN" \
  http://localhost:8123/api/states

# Turn on a light
curl -X POST -H "Authorization: Bearer $HA_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"entity_id": "light.living_room"}' \
  http://localhost:8123/api/services/light/turn_on

# Get device state
curl -H "Authorization: Bearer $HA_TOKEN" \
  http://localhost:8123/api/states/sensor.bedroom_temperature
```

### MQTT Direct Control

```bash
# Publish to a topic
mosquitto_pub -h localhost -t "home/living_room/light" -m "on"

# Subscribe to a topic
mosquitto_sub -h localhost -t "home/+/+/state" -v
```

## Common Routines

| Routine | Action |
|---------|--------|
| "Good morning" | Turn on bedroom lights to 50%, set thermostat to 72°F |
| "Good night" | Turn off all lights, lock doors, arm security |
| "Away mode" | Turn off lights, enable motion-based lighting, arm cameras |
| "Movie mode" | Dim living room lights to 15%, close blinds |

## Pitfalls

1. **Always authenticate.** Never skip the auth header — Home Assistant tokens grant full control.
2. **Check device availability first.** Before toggling, verify the device state isn't `unavailable`.
3. **MQTT topics are hierarchical.** Use wildcards (`+` for single level, `#` for all levels) when subscribing.
4. **Rate limit automations.** Don't fire more than one state change per second per entity — it can cause dashboard glitches.
5. **Battery devices sleep.** Zigbee/Z-Wave battery sensors may not respond immediately — they report on wake cycles, not on demand.

## Verification

After making changes:

1. Confirm the device state changed as expected
2. Check the automation log for any errors
3. Verify no unintended side effects on other devices

## Verification Checklist

- [ ] Home Assistant or MQTT backend confirmed running before device control
- [ ] Auth header included in all Home Assistant API requests
- [ ] Device state checked for `unavailable` before toggling
- [ ] No more than one state change per second per entity (rate limiting)
- [ ] MQTT topics use correct wildcards (+ for single level, # for all levels)
- [ ] Battery devices given time to respond (Zigbee/Z-Wave sleep cycles)
- [ ] No unintended side effects on other devices after changes