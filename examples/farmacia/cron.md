# Pharmacy Cron Jobs

<!-- pharmacy-overlay: pharmacy-specific scheduled jobs. See examples/farmacia/README.md
     for how these fit into the generic cron set. -->

These are the cron jobs the pharmacy vertical adds or specializes on top of the generic schedule. Schedules are interpreted in the configured timezone (`${TIMEZONE}`). Business jobs go to the client/owner recipients; system jobs go to ${OWNER_NAME} only.

## Specialized / added jobs

| Name | Schedule | Purpose |
|------|----------|---------|
| `cron-prices` | `0 11 * * 3` | Wednesday competitor price comparison |
| `cron-stock` | `0 9 * * 4` | Thursday smart stock alert |
| `cron-blog` | `0 12 * * 2,4` | Autonomous SEO blog article (pharmacy topic rotation) |

The on-duty schedule itself is updated on demand by the owner (image, PDF, or text), not by a cron job — see `tools/on-duty-pharmacies.md`.

## cron-prices — Competitor price comparison (Wednesday 11:00)

Compare the top 3 best sellers (or 3 with healthy stock if there were no sales) against a reference competitor pharmacy. Mechanics live in `tools/competitors.md`.

- If we are more expensive: suggest a concrete price and offer to adjust it.
- If we are competitive: confirm we are well positioned.
- If we are cheaper: suggest raising the price slightly.
- If there were no sales: compare high-stock products to rule out price as a barrier.

Send the result to the client recipients. If the comparison fails (all competitor fetches blocked), notify ${OWNER_NAME} instead of sending an empty report.

## cron-stock — Smart stock alert (Thursday 9:00)

Cross-reference low stock with sales data and classify urgency:

- URGENT: low stock + actively selling → restock now.
- ATTENTION: out of stock + no recent sales → restock or archive?
- RELAXED: low stock + no movement → no rush.

Maximum 5-6 products, end with a concrete question. Send to the client recipients.

## cron-blog — Autonomous SEO article (Tuesday and Thursday 12:00)

Generate and publish one SEO-optimized blog article. Publishes directly without confirmation (the standing autonomous exception). Log the title + handle to memory.

Rotate topics across these pharmacy categories, avoiding recently used ones (check existing articles first): dermocosmetics, supplements, hair care, oral care, orthopedics, intimate hygiene, baby and pregnancy, sexual wellness.

Tone: a pharmacist advising a patient — educational, never salesy. Respond in the store's configured language (`${LOCALE}`), defaulting to English. Never disclose AI authorship. Never promise cures — use phrasing like "may help" or "consult a professional". See `tools/blog.md` for format and SEO rules.

## Bootstrap

After copying the pharmacy tool docs into `hermes/tools/` and setting the env vars (see `examples/farmacia/README.md`), create or update these jobs through the `cron` tool, or add them to `scripts/bootstrap-cron.sh` so they are recreated on a fresh instance. On an existing instance, list current jobs first to avoid duplicates.
