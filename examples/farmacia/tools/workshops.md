# Workshops (Workshop Metaobjects)

<!-- pharmacy-overlay: copy to hermes/tools/ when applying the farmacia example. -->

The pharmacy offers in-person workshops stored as **metaobjects** of type `workshop`. Each workshop is a separate metaobject instance. The "workshops" page in the storefront reads them dynamically, filtered by `active: true` and ordered by `sort_order`.

Unlike on-duty pharmacies (one metaobject with weekly fields), workshops are a collection — list, create, update, or deactivate individual entries.

**NEVER use `pageUpdate` for the workshops page.** The page is bound to the metaobject definition; updating the metaobjects updates the page instantly. This does NOT require `write_content`.

## Field reference

The `workshop` definition has these field keys:

| key | type | notes |
|-----|------|-------|
| `image_url` | url | Public URL of the workshop image (string) |
| `category` | single_line_text_field | e.g., "Makeup", "Health", "Baby", "Nutrition" |
| `title` | single_line_text_field | Display title |
| `description` | multi_line_text_field | Body copy |
| `date` | date | ISO 8601 `YYYY-MM-DD`, e.g., `2026-05-26` |
| `time` | single_line_text_field | Free format, e.g., `10:00 – 19:00` or `17:30` |
| `location` | single_line_text_field | Address or venue name |
| `waitlist` | boolean | `"true"` if full and accepting waitlist sign-ups |
| `active` | boolean | `"true"` if visible on the storefront |
| `sort_order` | number_integer | Lower numbers render first |

> All `value` entries are passed as strings — Shopify parses them based on the definition. Booleans are `"true"` / `"false"`, integers are `"1"`, `"2"`, etc. Dates are ISO 8601 strings.

## List all workshops

Use this whenever the user asks "what workshops are there", "which are active", or before creating/editing to avoid duplicates.

```graphql
{
  metaobjects(type: "workshop", first: 50, sortKey: "id") {
    edges {
      node {
        id
        handle
        fields { key value }
      }
    }
  }
}
```

After reading, summarize for the user: title, date, time, category, and whether each is active. Show inactive workshops only if explicitly asked.

## Get a single workshop by id

```graphql
{
  metaobject(id: "gid://shopify/Metaobject/METAOBJECT_ID") {
    id
    handle
    fields { key value }
  }
}
```

Always read the current state before updating so you can confirm with the user exactly what will change.

## Create a new workshop

```graphql
mutation metaobjectCreate($metaobject: MetaobjectCreateInput!) {
  metaobjectCreate(metaobject: $metaobject) {
    metaobject { id handle fields { key value } }
    userErrors { field message code }
  }
}
```

Variables — include only the fields the user provided. A workshop without `title`, `date`, or `time` is not useful, so insist on those three at minimum:

```json
{
  "metaobject": {
    "type": "workshop",
    "fields": [
      {"key": "title", "value": "Skincare Routine Workshop"},
      {"key": "category", "value": "Dermocosmetics"},
      {"key": "description", "value": "Discover an anti-aging skincare routine with our pharmacist..."},
      {"key": "date", "value": "2026-05-26"},
      {"key": "time", "value": "17:00 – 20:00"},
      {"key": "location", "value": "The pharmacy, 123 Example Street"},
      {"key": "image_url", "value": "https://cdn.shopify.com/.../workshop.jpg"},
      {"key": "waitlist", "value": "false"},
      {"key": "active", "value": "true"},
      {"key": "sort_order", "value": "3"}
    ]
  }
}
```

**Defaults when the user does not specify:**

- `active`: `"true"` (a new workshop is usually meant to go live).
- `waitlist`: `"false"`.
- `sort_order`: 1 greater than the max existing `sort_order` so it renders last. Read the list first.
- `image_url`: leave blank if the user has not sent one — ask afterwards: "Could you send me an image for the workshop?"

## Update an existing workshop

Only include the fields you want to change. Omitted fields keep their current value.

```graphql
mutation metaobjectUpdate($id: ID!, $metaobject: MetaobjectUpdateInput!) {
  metaobjectUpdate(id: $id, metaobject: $metaobject) {
    metaobject { id fields { key value } }
    userErrors { field message }
  }
}
```

Variables:

```json
{
  "id": "gid://shopify/Metaobject/METAOBJECT_ID",
  "metaobject": {
    "fields": [
      {"key": "date", "value": "2026-06-02"},
      {"key": "time", "value": "18:00"}
    ]
  }
}
```

## Deactivate a workshop (Draft > Delete)

> **NEVER use `metaobjectDelete`.** Set `active: "false"` instead — same rule as Draft > Delete for products (`AGENTS.md` § Core Rules). The workshop stays in the system for audit and can be re-enabled by flipping the flag.

```json
{
  "id": "gid://shopify/Metaobject/METAOBJECT_ID",
  "metaobject": {
    "fields": [
      {"key": "active", "value": "false"}
    ]
  }
}
```

Reactivate the same way with `"value": "true"`.

## Image handling

`image_url` is a URL field (string), so it just needs a public URL.

When the user sends an image for a workshop:

1. Upload it via the standard 3-step pipeline from `tools/mutations.md` § "Upload Image to Product" — but stop after step 2. The returned `resourceUrl` from `stagedUploadsCreate` is a public Shopify CDN URL.
2. Use that `resourceUrl` as the `image_url` value in `metaobjectCreate` or `metaobjectUpdate`. Skip `productCreateMedia`, which is only for products.
3. If the user gives an external URL, download it first with `scripts/download-external-image.py`, then run the staged upload, so the final URL lives on the Shopify CDN and won't expire.

## Execution pattern

To avoid shell escaping issues with multiline descriptions and JSON payloads, write a small Python helper to `/tmp/workshop_op.py` that:

1. Builds the `variables` dict (one entry per field) — strings, booleans, dates, integers all as strings.
2. Serializes `{"query": mutation, "variables": variables}` with `json.dumps`.
3. Invokes `shopify-graphql.py` via `subprocess.run`.

Then `exec` the script. Same pattern as `tools/on-duty-pharmacies.md`.

## Rules

- Always list current workshops before creating a new one — flag potential duplicates by title or date.
- Confirm ALL changes with the user before mutating. Show: workshop title, fields changing, new values.
- Never fabricate workshop data. Only use what the user explicitly provided in the current conversation.
- For deactivation, confirm explicitly: "Shall I deactivate the workshop X? It will be hidden on the website but not deleted."
- After mutating, confirm clearly that the changes are now live on the website.
- On failure, retry silently up to 2 times (re-read the metaobject, check payload, retry). If it still fails, tell the user there is a temporary technical issue and that you will notify ${OWNER_NAME} to look into it.
- **NEVER use `metaobjectDelete`** — always `metaobjectUpdate` with `active: "false"`.
- **NEVER use `pageUpdate`** for the workshops page — it will fail and you must not attempt it.
- **NEVER mention permissions, scopes, or technical limitations to the user.**
