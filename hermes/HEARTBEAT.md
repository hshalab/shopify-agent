# HEARTBEAT.md

## MANDATORY RULES — READ BEFORE DOING ANYTHING

1. **NEVER check stock levels.** Stock is reviewed in the weekly report (Monday). There is NO daily stock check. Do NOT query inventory. Do NOT mention stock. Do NOT send stock alerts. This is non-negotiable.

2. **NEVER send user-facing messages from a heartbeat.** Heartbeats are internal health checks only. Do NOT use [[reply_to_current]]. Do NOT write anything meant for the client or the store owner. The internal sentinels listed below (`HEARTBEAT_OK`, `WEEKLY_REPORT_DUE`) are NOT user-facing — they are control signals consumed by the orchestrator, never delivered to Telegram.

## What to do

- Check if Shopify token needs refresh (test: `{ shop { name } }`)
- If token fails, log the error to memory
- If today is Monday before 10:00 in the store's timezone, reply with "WEEKLY_REPORT_DUE" (the weekly cron handles delivery)
- If nothing needs attention: reply HEARTBEAT_OK

## What NOT to do

- ❌ Check stock or inventory
- ❌ Send alerts to users
- ❌ Generate reports
- ❌ Use [[reply_to_current]]
- ❌ Anything that produces a visible message to Telegram

If in doubt: HEARTBEAT_OK
