---
name: time-filtered-queries
description: Handle any query that involves time filtering — calendar, email, tasks, or other MCP tools. Establishes the correct date range before constructing the query.
---

# Time-Filtered Queries

## Core Rule (CRITICAL)

**ALWAYS query the system clock FIRST.** Never infer the current date from calendar data, conversation context, emails, or any other data source.

```bash
date
```

If the system clock is suspect, cross-check:
```bash
date -u  # UTC
```

## Procedure

1. **Get the date** from `date` command — this is the single source of truth.

2. **Parse the user's time expression:**
   - "today" → single day
   - "this week" → Mon 00:00 to Sun 23:59 (ISO week: Monday-start)
   - "this month" → 1st 00:00 to last day 23:59
   - "next week" → following Monday to following Sunday
   - "the past 7 days" → today back 7 days
   - "tomorrow" → single day, +1
   - "yesterday" → single day, -1

3. **Convert to RFC3339 UTC:**
   - Google Calendar API `time_min`/`time_max` expect UTC timestamps
   - Example: `2026-07-14T00:00:00Z` to `2026-07-20T00:00:00Z` for this week (Mon 14 – Sun 20)
   - `time_max` is exclusive — use the boundary of the next period

4. **Apply the filter:**
   - Calendar: `calendar_mcp.list_events(time_min=..., time_max=...)`
   - Gmail: `gmail_mcp.search_threads(query="after:YYYY/MM/DD before:YYYY/MM/DD")`
   - Tasks: `tasks_mcp.list_tasks()` — no native time filter, filter results in code

5. **Present results in user's timezone** (Europe/Paris for Tim, based on system clock timezone).

## Timezone Handling

- API queries: always use UTC (`Z` suffix or `+00:00`)
- Display: convert back to local timezone for the user
- Google Calendar events include their native `timeZone` field — use it to show correct local times

## Time Expression Reference

| Expression | Default Window | Notes |
|---|---|---|
| today | Mon–Sun 00:00–23:59 | Single day |
| this week | Mon 00:00 – Sun 23:59 | ISO week (Monday start) |
| next week | Following Mon – Following Sun | Relative to current week |
| this month | 1st 00:00 – last day 23:59 | Calendar month |
| past N days/days ago | Today – N days | Inclusive |
| tomorrow | +1 day | |
| yesterday | -1 day | |

## Anti-Patterns

- **DO NOT** infer dates from event data
- **DO NOT** guess the user's timezone — use the system clock's timezone
- **DO NOT** hardcode date ranges from previous sessions

## Troubleshooting

- If calendar results look wrong, check: (a) did you use the right date? (b) are you querying UTC correctly? (c) is the user asking for a different week boundary than ISO (e.g. some cultures use Sunday-start)?