---
name: reminder-pattern
description: General rule for handling reminders, tasks, and cron jobs together
created: 2026-07-16
---
# Reminder Pattern

When asked to remind the user about something, follow this pattern:

1. **Create a Google Tasks task** with a clear title describing the reminder. This gives the user something tangible to check off, creating the "personal assistant" feel.
2. **Create a cron job** to check on the task status at the reminder time.
3. **Cron job logic**: At reminder time, the cron job checks if the task is still pending. Only sends the notification message if the task is NOT completed.
4. **Delivery**: Use `deliver='origin'` so the notification goes through the connected gateway (Discord in this case).

This avoids nagging (user completes task → no reminder message) and provides a visible task list for tracking.
