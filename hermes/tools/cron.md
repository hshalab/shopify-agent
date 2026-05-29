# Cron Capabilities

Cron jobs are runtime state in Hermes. Do not commit `hermes/cron/`; recreate jobs from source instructions after setting up `.env`.

The generic core auto-bootstraps six canonical jobs (three business-facing, three system). Business jobs are delivered to the configured recipients (`${OWNER_NAME}` / the configured home channel):

| Name | Schedule | Purpose |
|------|----------|---------|
| `cron-engagement` | `0 9 * * 1-5` | Daily smart good-morning insight |
| `cron-seo-daily` | `30 9 * * 1-5` | Daily micro-improvement |
| `cron-report` | `15 9 * * 1` | Weekly report |
| `cron-monitor` | `0 10 * * *` | System health monitor |
| `cron-backup` | `50 3 * * *` | Daily volume backup (state.db + memories + cron + auth → /opt/data/backups/) |
| `cron-cleanup` | `55 3 * * *` | Runtime cleanup |

Three more jobs are **optional templates** — they are NOT auto-bootstrapped, because they need per-store configuration (a competitor source, a blog, an autonomous-publish policy). Add them yourself once configured:

| Name | Schedule | Purpose |
|------|----------|---------|
| `cron-prices` | `0 11 * * 3` | Price/catalog review (configure the source for your vertical) |
| `cron-stock` | `0 9 * * 4` | Smart stock alert |
| `cron-blog` | `0 12 * * 2,4` | Autonomous SEO blog article (requires `${BLOG_ID}`) |

Schedules are interpreted in the configured Hermes timezone (`${TIMEZONE}`, default `UTC`).

Tailor the optional templates' prompt content to the store's vertical. See `examples/farmacia/` for a fully worked vertical example that wires them up.

The six canonical jobs are bootstrapped automatically at container boot by `scripts/bootstrap-cron.sh` (invoked from `start-gateway.sh`), once `.env` contains the Shopify credentials, `TELEGRAM_HOME_CHANNEL`, and the configured recipients. To (re)run it manually inside the container:

```bash
cd /opt/data
bash scripts/bootstrap-cron.sh
```

The script creates only the six canonical jobs. On an existing instance, check `hermes cron list` before re-running to avoid duplicates. The optional `cron-prices` / `cron-stock` / `cron-blog` templates are not created by the script — add them with `hermes cron create` once configured for your store.
