# Release flow

This repo uses two long-lived branches:

- `main`: production-ready source brain and deployment recipe.
- `staging`: integration branch for new ${AGENT_NAME} capabilities, Hermes config changes, and `hermes-slim` image update validation.

## Branch policy

Create feature branches from `staging` and merge them back into `staging` first. Promote `staging` to `main` only after the branch has been validated against the running Hermes gateway and the intended Shopify/Telegram behavior.

Use `main` for the current stable production state. Avoid direct commits to `main` except for explicit hotfixes.

## Image policy

The compose file reads `HERMES_IMAGE` from `.env`, defaulting to `ghcr.io/cgaravitoq/hermes-slim:latest` when unset. For production reproducibility, set `HERMES_IMAGE` to a tested tag or digest before promoting a runtime upgrade to `main`.

Recommended flow for `hermes-slim` updates:

1. Publish or select the candidate `hermes-slim` image.
2. Set `HERMES_IMAGE` in the staging environment to that candidate.
3. Run the gateway smoke checks from the README.
4. Promote the same image reference to production only after validation.

## Promotion checklist

- `git status --short` shows only the intended release changes.
- `docker compose config --quiet` passes with the target `.env`.
- `docker compose pull hermes` resolves the intended `HERMES_IMAGE`.
- Telegram smoke test succeeds from an allowed user.
- Shopify read smoke test succeeds.
- Any write-capability change has the required business confirmation rules documented in `hermes/SOUL.md`, `hermes/AGENTS.md`, or the relevant `hermes/tools/*.md` file.
