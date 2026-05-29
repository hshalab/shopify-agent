# Pharmacy vertical overlay

This overlay turns the generic `shopify-agent` into a **pharmacy assistant**. It adds pharmacy-specific behavior on top of the generic core: managing an on-duty pharmacy schedule, in-person workshops, metaobject-driven home content (offer of the month + featured services), competitor price comparison against other pharmacies, and a pharmacy-flavored blog topic rotation.

The generic core has no vertical. This directory is the worked example that proves the "add a vertical" model: you copy a few brain fragments, copy a few tool docs, add a couple of cron jobs, and set a handful of env vars. Nothing here is wired in automatically — applying the overlay is the manual recipe below.

## What's in this directory

```
examples/farmacia/
├── README.md                     ← this file
├── cron.md                       ← pharmacy cron jobs (prices, stock, blog)
├── brain/
│   ├── SOUL.fragment.md          ← blocks to insert into hermes/SOUL.md
│   ├── AGENTS.fragment.md        ← blocks to insert into hermes/AGENTS.md
│   └── TOOLS.fragment.md         ← Module Index rows to insert into hermes/TOOLS.md
└── tools/
    ├── README.md
    ├── on-duty-pharmacies.md     ← weekly on-duty schedule (single metaobject)
    ├── workshops.md              ← in-person workshops (metaobject collection)
    ├── home-content.md           ← home_offer + home_service metaobjects
    └── competitors.md            ← competitor price comparison
```

## Apply the overlay (recipe)

### 1. Insert the brain fragments

Each file under `brain/` lists, section by section, exactly which blocks to insert into the corresponding base brain file. Insert them into the matching sections:

- `brain/SOUL.fragment.md` → `hermes/SOUL.md`
  - Adds the on-duty pharmacies + workshops capabilities to "What you do".
  - Adds the "You CAN manage on-duty pharmacies, never refuse it" note to "What you DON'T do".
  - Adds the full "On-Duty Pharmacies — MANDATORY BEHAVIOUR" section.
  - Adds the on-duty line to the first-message introduction.
  - Adds the Wednesday price-comparison proactive job.
- `brain/AGENTS.fragment.md` → `hermes/AGENTS.md`
  - Adds the Metaobjects capability under Boundaries → DO and the `pageUpdate` note on Content.
  - Adds the `pageUpdate` / `metaobjectDelete` entries to Boundaries → NEVER.
  - Adds the "On-Duty Pharmacies" subsection.
  - Adds the `cron-prices` job and the pharmacy `cron-blog` category rotation.
- `brain/TOOLS.fragment.md` → `hermes/TOOLS.md`
  - Adds the four pharmacy rows to the "Module Index" table.

### 2. Copy the tool docs

Copy the four files under `tools/` into the live tool directory the engine reads (`hermes/tools/`, mounted at `/opt/data/tools/` in the container):

```
cp examples/farmacia/tools/on-duty-pharmacies.md hermes/tools/
cp examples/farmacia/tools/workshops.md          hermes/tools/
cp examples/farmacia/tools/home-content.md       hermes/tools/
cp examples/farmacia/tools/competitors.md        hermes/tools/
```

These match the Module Index rows you added in step 1. The agent reads them on demand.

### 3. Add the cron jobs

Follow `cron.md`. The pharmacy vertical specializes `cron-prices` (Wednesday competitor comparison), `cron-stock` (Thursday stock alert), and `cron-blog` (pharmacy topic rotation). Add or update them through the `cron` tool, or extend `scripts/bootstrap-cron.sh` so they are recreated on a fresh instance. The on-duty schedule update is on demand, not a cron job.

### 4. Set the env vars and metaobject ids

Add to `.env` (in addition to the generic `AGENT_NAME` / `OWNER_NAME` / `CLIENT_NAME` / `STORE_NAME` / `LOCALE` and the standard `TELEGRAM_*` / `SHOPIFY_*` / model keys):

```
# Pharmacy overlay
FARMACIAS_METAOBJECT_ID=gid://shopify/Metaobject/...   # pharmacy_schedule / current-week entry
THEME_ID=gid://shopify/OnlineStoreTheme/...            # live theme that renders the metaobject content
BLOG_ID=gid://shopify/Blog/...                         # blog used by cron-blog
```

`${BLOG_ID}` and `${THEME_ID}` are the same generic resolved-id placeholders the core already uses; the pharmacy overlay only adds `FARMACIAS_METAOBJECT_ID`.

Set the branding in `config.yaml` the same way the core does (`identity.agent_name`, `owner_name`, `locale`, `timezone`, `home_channel_name`). The overlay references `${OWNER_NAME}`, `${LOCALE}`, and `${TIMEZONE}` — there are no pharmacy-specific config keys.

### 5. Create the metaobject definitions in Shopify

The overlay assumes these metaobject definitions exist in your store (create them in the Shopify admin, or have your developer add them):

- `pharmacy_schedule` — single entry, handle `current-week`. Fields: `week_label`, and for each day (`monday`…`sunday`) a `{day}_name`, `{day}_address`, `{day}_phone`. See `tools/on-duty-pharmacies.md`.
- `workshop` — one entry per workshop. Fields per `tools/workshops.md` § "Field reference".
- `home_offer` — single entry, handle `current`. Fields per `tools/home-content.md`.
- `home_service` — one entry per service. Fields per `tools/home-content.md`.

The storefront theme must read these metaobjects (the on-duty page, workshops page, home offer countdown, and service cards are bound to the metaobject definitions). Wiring the theme is out of scope for this overlay — it is store/theme work owned by ${OWNER_NAME}.

## What stays generic

Everything in the core stays vertical-neutral. The overlay never edits the generic `tools/*.md` (queries, mutations, orders, customers, discounts, etc.) — it only adds the four pharmacy tool docs and the brain fragments above. The agent still responds in the store's configured language (`${LOCALE}`), defaulting to English; nothing here hardcodes a language.
