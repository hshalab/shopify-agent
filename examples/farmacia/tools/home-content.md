# Home Editable Content (Offer + Services)

<!-- pharmacy-overlay: copy to hermes/tools/ when applying the farmacia example. -->

Parts of the home page (and the "On-Duty Pharmacies" page) are driven by Shopify **Metaobjects**, not by template JSON. Updating these metaobjects updates the live storefront instantly without touching `templates/index.json` or the on-duty pharmacies page template.

The theme is your store's live theme (id `${THEME_ID}`, slug "your-theme"). The metaobject-driven content pattern is wired into that theme's sections and snippets.

**Two metaobjects:**

| Type | Handle pattern | What it drives |
|------|----------------|----------------|
| `home_offer` | single entry, handle `current` | "Offer of the month" countdown + featured product |
| `home_service` | one entry per service, any handle | Service cards on home and on the "On-Duty Pharmacies" page |

**NEVER edit `templates/index.json` or the on-duty pharmacies page template for operational content.** Always update the metaobjects below. This requires `write_metaobjects` only — does NOT require `write_themes` or `write_content`.

---

## home_offer — Offer of the month

Single entry with handle `current`. Drives the urgency-countdown and featured-product sections.

### Fields

| Key | Type | Notes |
|-----|------|-------|
| `heading` | single_line_text | Headline of the offer |
| `subtext` | multi_line_text | Subtext under the headline |
| `deadline_at` | date_time | Countdown deadline (ISO 8601, e.g. `2026-05-31T23:59:00Z`) |
| `expired_message` | single_line_text | Shown after the deadline passes |
| `featured_product` | product_reference | Product highlighted alongside the countdown |
| `active` | boolean | If `false`, the theme falls back to default settings/blocks |

### Read current offer

```graphql
{
  metaobjectByHandle(handle: {type: "home_offer", handle: "current"}) {
    id
    fields { key value reference { ... on Product { id title handle } } }
  }
}
```

### Update offer

Build a Python helper in `/tmp/` (avoids shell escaping) and exec via `shopify-graphql.py`.

```graphql
mutation metaobjectUpdate($id: ID!, $metaobject: MetaobjectUpdateInput!) {
  metaobjectUpdate(id: $id, metaobject: $metaobject) {
    metaobject { id fields { key value } }
    userErrors { field message }
  }
}
```

Variables (only include the fields you want to change):
```json
{
  "id": "<gid from metaobjectByHandle>",
  "metaobject": {
    "fields": [
      {"key": "heading", "value": "Skincare Pack -20%"},
      {"key": "subtext", "value": "This week only"},
      {"key": "deadline_at", "value": "2026-05-31T23:59:00Z"},
      {"key": "featured_product", "value": "gid://shopify/Product/123456789"},
      {"key": "active", "value": "true"}
    ]
  }
}
```

### Deactivate offer (fall back to theme defaults)

Set `active` to `false`. The countdown and featured-product sections will render their default settings/blocks instead.

```json
{"key": "active", "value": "false"}
```

---

## home_service — Featured services

One metaobject entry per service. Drives the services section and service-card snippet. The same section is reused on the home page and on the "On-Duty Pharmacies" page.

### Fields

| Key | Type | Notes |
|-----|------|-------|
| `title` | single_line_text | Service name |
| `description` | multi_line_text | Short description |
| `image` | file_reference | Service card image |
| `cta_label` | single_line_text | Button text |
| `cta_type` | single_line_text | Either `whatsapp` or `collection` |
| `whatsapp_message` | multi_line_text | Pre-filled message when `cta_type = whatsapp` |
| `collection` | collection_reference | Target collection when `cta_type = collection` |
| `active` | boolean | If `false`, the card is hidden |
| `sort_order` | number_integer | Lower = earlier in the list |

### List all services (ordered)

```graphql
{
  metaobjects(type: "home_service", first: 50, sortKey: "display_name") {
    nodes {
      id
      handle
      fields { key value reference { ... on Collection { id handle title } ... on MediaImage { image { url } } } }
    }
  }
}
```

(The theme sorts by the `sort_order` field at render time; the query above lists all entries — both active and inactive.)

### Create a new service

```graphql
mutation metaobjectCreate($metaobject: MetaobjectCreateInput!) {
  metaobjectCreate(metaobject: $metaobject) {
    metaobject { id handle fields { key value } }
    userErrors { field message }
  }
}
```

Variables for a WhatsApp-CTA service:
```json
{
  "metaobject": {
    "type": "home_service",
    "handle": "pharmacist-consultation",
    "fields": [
      {"key": "title", "value": "Pharmacist consultation"},
      {"key": "description", "value": "We answer your questions over WhatsApp."},
      {"key": "image", "value": "gid://shopify/MediaImage/123456789"},
      {"key": "cta_label", "value": "Message us"},
      {"key": "cta_type", "value": "whatsapp"},
      {"key": "whatsapp_message", "value": "Hi, I wanted to ask about..."},
      {"key": "active", "value": "true"},
      {"key": "sort_order", "value": "10"}
    ]
  }
}
```

Variables for a Collection-CTA service:
```json
{
  "metaobject": {
    "type": "home_service",
    "handle": "dermocosmetics",
    "fields": [
      {"key": "title", "value": "Dermocosmetics"},
      {"key": "description", "value": "Curated products for your skin."},
      {"key": "image", "value": "gid://shopify/MediaImage/123456789"},
      {"key": "cta_label", "value": "View products"},
      {"key": "cta_type", "value": "collection"},
      {"key": "collection", "value": "gid://shopify/Collection/123456789"},
      {"key": "active", "value": "true"},
      {"key": "sort_order", "value": "20"}
    ]
  }
}
```

### Edit a service

Use `metaobjectUpdate` with the entry's `id`. Only include the fields you want to change.

### Hide a service (keep history, hide from web)

Set `active` to `false`. The card disappears from home + the On-Duty Pharmacies page without deleting the entry.

```json
{"key": "active", "value": "false"}
```

### Reorder services

Update `sort_order` on the entries you want to move. Lower numbers render first. Leave gaps (10, 20, 30) so re-inserting is cheap.

### Delete a service permanently

Prefer `active=false` over deletion. If the owner explicitly asks to delete:

```graphql
mutation metaobjectDelete($id: ID!) {
  metaobjectDelete(id: $id) {
    deletedId
    userErrors { field message }
  }
}
```

---

## Execution pattern

Same as `on-duty-pharmacies.md`/`workshops.md`: write a small Python helper to `/tmp/` that builds the `variables` dict, serializes `{"query": mutation, "variables": variables}` with `json.dumps`, and invokes `shopify-graphql.py` via `subprocess.run`. Then `exec` the script.

For reads, a one-liner via `shopify-graphql.py` is fine.

## Rules

- Always show the current state first (offer fields or service list) before making changes.
- Confirm ALL changes with the user before mutating — never act on data the user hasn't explicitly provided or confirmed in the current conversation.
- **NEVER edit `templates/index.json` or the on-duty pharmacies page template** — always go through the metaobjects.
- **NEVER touch the theme code or `themePublish` mutations.** Theme changes are ${OWNER_NAME}-only.
- For `home_service.cta_type`, only `whatsapp` or `collection` are valid. If the owner asks for a different CTA type, route them to ${OWNER_NAME}.
- For `home_offer.deadline_at`, accept human input ("May 31", "Friday at 23:59") and convert to ISO 8601 in the store's timezone (`${TIMEZONE}`). Confirm the resolved date with the owner before submitting.
- After updating, confirm clearly that the changes are now live on the website.
- When `home_offer.active = false` or no `home_service` entries are active, the theme falls back to its default settings/blocks — that's the expected behaviour, not an error.

## Memory hygiene

Following the policy in `SOUL.md`:

- Log each meaningful change to `MEMORY.md` with the date (e.g. `2026-05-22 - Updated home_offer/current heading to "Skincare Pack -20%"`).
- For `home_offer/current`, when the offer is replaced, mark the previous `MEMORY.md` entry as `[superseded YYYY-MM-DD]` instead of deleting it.
- For `home_service`, treat each entry independently — log create/edit/deactivate operations per handle.
