# shopify-agent

A Shopify store assistant that runs on the [Hermes](https://github.com/cgaravitoq/hermes-slim) engine and talks to you over Telegram. It reads and manages a single Shopify store through scripted Admin API calls, runs scheduled jobs (engagement, SEO audits, weekly reports — plus optional price/stock/blog templates), and answers operator questions in chat.

The engine ships as a Docker image (`ghcr.io/cgaravitoq/hermes-slim`); this repo is the agent "brain" and deployment recipe layered on top of it. You configure the agent through `hermes/config.yaml` and a short set of environment variables, then run `docker compose up`.

## Layout

```
shopify-agent/
├── docker-compose.yml      # Hermes gateway service
├── .env                    # secrets (gitignored, copy from .env.example)
├── .env.example
├── examples/farmacia/      # worked vertical overlay (pharmacy)
└── hermes/                 # source brain, synced into the runtime volume on boot
    ├── config.yaml         # model + telegram + branding config
    ├── SOUL.md             # personality, output rules
    ├── AGENTS.md           # operating rules, cron, analytics, SEO audit
    ├── TOOLS.md            # shopify graphql index
    ├── IDENTITY.md         # agent persona (display name set in USER.md)
    ├── USER.md             # store info + telegram routing (copy from USER.md.example)
    ├── HEARTBEAT.md        # health check rules
    ├── tools/              # shopify queries/mutations/blog/...
    └── scripts/            # python + shell helpers (shopify-graphql, upload, ...)
```

Only the source brain, scripts, and Shopify tool docs are meant to be committed. Hermes creates runtime state under the named volume when the gateway runs: sessions, logs, local auth, locks, cached skills, model caches, sqlite state, downloaded helper binaries, and working directories. Those files are gitignored and should not be committed.

The Hermes Docker image is intentionally large because it includes the full Hermes runtime and browser/tooling dependencies. This repo keeps that as an external image dependency rather than vendoring generated runtime files into Git.

## Prerequisites

- Docker with the Compose plugin (Docker Desktop, OrbStack, or a plain Docker Engine all work — the compose file uses standard syntax).
- A Telegram bot token (see below).
- An OpenRouter API key (https://openrouter.ai/keys).
- Shopify Admin API credentials for the target store (`SHOPIFY_STORE`, `SHOPIFY_CLIENT_ID`, `SHOPIFY_CLIENT_SECRET`).

## Create the Telegram bot

1. Open Telegram and start a chat with [@BotFather](https://t.me/BotFather).
2. Send `/newbot`, follow the prompts (name + username ending in `bot`).
3. BotFather replies with an HTTP API token — paste it into `.env` as `TELEGRAM_BOT_TOKEN`.
4. (Optional) `/setprivacy` → `Disable` if you want the bot to read all messages in groups, or leave the default for DMs only.
5. Get the numeric Telegram IDs of every user that should be allowed to talk to the agent. Use [@userinfobot](https://t.me/userinfobot) — forward a message from each user and it replies with their ID. Drop the IDs into `TELEGRAM_ALLOWED_USERS` separated by commas.

## Quickstart

1. Clone and enter the repo:
   ```bash
   git clone https://github.com/cgaravitoq/shopify-agent.git
   cd shopify-agent
   ```
2. Copy the env template and fill in the secrets:
   ```bash
   cp .env.example .env
   $EDITOR .env
   ```
   Required: `OPENROUTER_API_KEY` (model credential for all model roles — main, vision, auxiliary, fallback), `TELEGRAM_BOT_TOKEN`, `TELEGRAM_ALLOWED_USERS`, `SHOPIFY_STORE`, `SHOPIFY_CLIENT_ID`, `SHOPIFY_CLIENT_SECRET`. Optional: `OPENCODE_GO_API_KEY` (alternative model provider — switch the providers in `hermes/config.yaml` to use it).
3. Set the branding in `hermes/config.yaml`: `identity.agent_name` and `owner_name` are interpolated from the matching `.env` vars (`AGENT_NAME`, `OWNER_NAME`); `locale` (default `en`) and `timezone` (default `UTC`) are plain defaults you can edit directly. Note: the brain markdown (`SOUL.md`, `AGENTS.md`, `IDENTITY.md`) is **not** variable-interpolated at runtime, so the agent's display name and the store language are taken from `hermes/USER.md` (next step).
4. Write `hermes/USER.md` from the template:
   ```bash
   cp hermes/USER.md.example hermes/USER.md
   $EDITOR hermes/USER.md
   ```
   Set the agent's display name and the store language here, and describe the store, the operator/client roles, and the Telegram routing for each recipient.
5. Pull the image and start the gateway:
   ```bash
   docker compose pull
   docker compose up -d
   ```
6. Tail the gateway logs while it boots:
   ```bash
   docker compose logs -f hermes
   ```
7. Confirm the scheduled jobs were bootstrapped at boot:
   ```bash
   docker compose exec hermes /opt/hermes/.venv/bin/hermes cron list
   ```
   Re-running `bootstrap-cron.sh` manually is only needed if the canonical job set in `hermes/scripts/bootstrap-cron.sh` was edited and you want to apply the change without restarting the container.

## Verify it works

- Start a chat with the bot from one of the approved Telegram IDs, then send "Hi". The agent should introduce itself using the display name you set in `hermes/USER.md`.
- Ask: "How many products do I have in the store?" — it should run `productsCount` against Shopify and reply.
- Watch `docker compose logs -f hermes` for the live gateway trace.

The agent replies in the store's configured language (set in `hermes/USER.md`), defaulting to English.

## Reproducibility model

This repo is a recipe for a Hermes Agent instance, not a snapshot of a running instance.

Commit:
- `docker-compose.yml`, `.env.example`, `README.md`
- `hermes/config.yaml`
- `hermes/*.md`
- `hermes/tools/*.md`
- `hermes/scripts/*.py`

Do not commit:
- `.env` or `hermes/.env`
- `hermes/USER.md`
- `hermes/auth.json`
- `hermes/state.db*`
- `hermes/gateway.*`
- `hermes/sessions/`, `hermes/logs/`, `hermes/memories/`, `hermes/cron/`
- generated bundled skills under `hermes/skills/`
- downloaded helper binaries under `hermes/bin/`

`HERMES_IMAGE` is defined in `.env.example` and consumed by `docker-compose.yml`. The default is pinned to a tested immutable tag (`ghcr.io/cgaravitoq/hermes-slim:16baf96`, the short commit sha of the engine build), so a fresh `docker compose up` reproduces a known-good runtime. Bump it deliberately when promoting a Hermes upgrade. The `:latest` tag also exists if you prefer to live on the edge.

See `docs/release-flow.md` for the `staging` to `main` promotion process.

Cron schedules are source-documented in `hermes/tools/cron.md` and bootstrapped with `hermes/scripts/bootstrap-cron.sh`; the generated cron database itself stays runtime-only.

This deployment intentionally does not run the Hermes dashboard. The interface is Telegram only, and operational inspection happens through logs and CLI commands.

## Model providers

The Hermes engine is provider-agnostic; this repo just ships an OpenRouter default. In `hermes/config.yaml`, `model.provider` (and each `auxiliary.*.provider` and `fallback_model.provider`) selects the backend, while `model.default` / the per-role `model` fields select the model. Out of the box every role is set to `openrouter` with `google/gemini-2.5-flash`, authenticated by `OPENROUTER_API_KEY` in `.env`.

To point a role at another provider (e.g. `anthropic` or `openai`), set its `provider` and `model` in `hermes/config.yaml`. Per-role overrides for `base_url` and `api_key` are available under `auxiliary.*` for endpoints that need them. The optional `OPENCODE_GO_API_KEY` in `.env` credentials the alternative provider — switch the providers in `hermes/config.yaml` to use it.

## Security model

The production-facing surface is intentionally narrow — this is deliberate hardening, not a missing feature:

- Telegram access is restricted by `TELEGRAM_ALLOWED_USERS` (an allowlist of numeric IDs). The bot ignores everyone else.
- The dashboard is not deployed, removing a network-exposed control surface.
- The gateway port is bound to `127.0.0.1` only, so it is not reachable from outside the host.
- Enabled Hermes toolsets are limited to `file`, `web`, `terminal`, `vision`, `memory`, and `cronjob`.
- Browser automation, delegation, skill creation, code execution, image generation, TTS, and cross-platform messaging are disabled for Telegram.
- Terminal commands run inside the Hermes container against the synced runtime volume, not the host.
- Shopify access goes through the helper scripts in `/opt/data/scripts/`.

Hermes command approvals are disabled in `hermes/config.yaml` (`approvals.mode: 'off'`) so end users never see technical "allow once/session/always" prompts on mobile. The remaining hardline blocklist still blocks catastrophic commands internally. User-facing Shopify mutations are still governed by the business confirmation rules in `SOUL.md` and `AGENTS.md` (confirm before mutate, draft over delete, report every change).

## Adding a vertical

The generic core has no industry-specific behavior. To specialize the agent for a vertical, layer an overlay on top of the base brain. `examples/farmacia/` is a worked example (a Spain pharmacy overlay) showing how vertical-specific rules and tools are kept separate from the generic core.

## Stop / restart

```bash
docker compose down                   # stop, keep state
docker compose up -d                  # start again (state preserved)
docker compose down -v                # stop and wipe volumes (rare)
```

## Editing the brain

Files under `hermes/` are the source of truth. They are bind-mounted read-only at `/opt/init` and synced into the `/opt/data` named volume (`hermes-data`) on every container boot by `start-gateway.sh`. The agent reads from `/opt/data/...`; keep that prefix when adding new scripts.

After editing any markdown file under `hermes/`, restart the container to apply the change:

```bash
docker compose restart hermes
```

Live edits do not reflect mid-session — state lives in the named volume and is re-synced from `/opt/init` only at boot.

## Troubleshooting

- **Bot doesn't reply** → confirm the user's Telegram ID is in `TELEGRAM_ALLOWED_USERS` and the bot was started in that chat with `/start`.
- **`401 unauthorized` from Shopify** → re-check `SHOPIFY_CLIENT_ID` / `SHOPIFY_CLIENT_SECRET`; the script uses `client_credentials` against `/admin/oauth/access_token`.
- **Gateway unhealthy** → `docker compose ps` should show `hermes` as `running`. Check `docker compose logs -f hermes`.

## License

Released under the [MIT License](LICENSE).
