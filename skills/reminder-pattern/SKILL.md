---
name: reminder-pattern
description: General rule for handling reminders, tasks, and cron jobs together
created: 2026-07-16
---
# Reminder Pattern

## ⚠️ CRITICAL: Google Tasks MCP — Never Send Empty Bodies

The Tasks MCP tool schemas show `task_body` and `patch_body` as empty objects `{}`. **This is misleading — you MUST populate them with actual fields.** Sending `{}` creates tasks with empty titles, which is useless and requires cleanup.

- **`create_task`**: `task_body={"title": "Your task title", "notes": "Details here..."}`
- **`update_task`**: `patch_body={"title": "New title"}` or `patch_body={"status": "completed"}` or both
- **`delete_task`**: only needs `task_id` (not `task_body`)
- **`list_tasks`**: uses `show_completed`, `max_results` (no body needed)

**Verification step**: After creating a task, immediately `list_tasks` to confirm the title and notes are present. If the title is empty, delete it and recreate with proper fields.

## Pattern Steps

1. **Create a Google Tasks task** with a clear, descriptive title. Include `notes` with details if needed.
   - Example: `task_body={"title": "Pick up dry cleaning", "notes": "Blue suit, from TailorShop on Main St"}`
2. **Create a cron job** to check on the task status at the reminder time. Store the task ID so the cron job can reference it.
3. **Cron job logic**: At reminder time, the cron job checks if the task is still pending. Only sends the notification message if the task is NOT completed.
4. **Delivery**: Use `deliver='origin'` so the notification goes through the connected gateway (Discord in this case).

This avoids nagging (user completes task → no reminder message) and provides a visible task list for tracking.

## Choosing the reminder time

When the user gives a vague reminder request with no time specified:
- Default: schedule the reminder for **18:00 today** (end of workday). If it's already past 18:00, schedule for **tomorrow morning** instead (use judgment on exact time, e.g. 08:00-09:00).
- Override the default using contextual/task-type judgment:
  - **Computer/online tasks** (e.g. cancel a subscription, reply to an email, fill a form) can be reminded **during working hours** since the user can act on them at their desk.
  - **Out-and-about / errand tasks** (e.g. pick something up, visit an office) are better reminded **as the user leaves work (~18:00) or on the weekend**, since they require being physically somewhere.
- Once Home Assistant location access is available, factor in the user's real-time location to refine timing and enable location-based reminders (e.g. remind when arriving near a relevant place).

## User Preferences (Style & Format)

- **Be direct** — give the answer or result first, don't over-explain before delivering.
- **Use actual field values** in MCP tool calls — never pass empty `{}` as a body parameter.
- **Verify after creation** — always confirm the task was created with proper content before declaring success.