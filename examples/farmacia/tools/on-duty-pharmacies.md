# On-Duty Pharmacies (Weekly Schedule)

<!-- pharmacy-overlay: copy to hermes/tools/ when applying the farmacia example. -->

The on-duty schedule is a **metaobject** (type `pharmacy_schedule`, handle `current-week`, ID `${FARMACIAS_METAOBJECT_ID}`). The webpage reads it dynamically, so updating the metaobject fields updates the page instantly.

**NEVER use `pageUpdate` for this page.** Always use `metaobjectUpdate` below. This does NOT require `write_content`.

## Read current schedule

```graphql
{
  metaobject(id: "${FARMACIAS_METAOBJECT_ID}") {
    fields { key value }
  }
}
```

## Update schedule

Update any combination of fields. Only include the fields you want to change. Write a Python script to `/tmp/` and execute it — this avoids shell escaping issues with the JSON payload.

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
  "id": "${FARMACIAS_METAOBJECT_ID}",
  "metaobject": {
    "fields": [
      {"key": "week_label", "value": "Week of June 1–7, 2026"},
      {"key": "monday_name", "value": "Example Pharmacy"},
      {"key": "monday_address", "value": "123 Example Street"},
      {"key": "monday_phone", "value": "+1 555 000 0000"},
      {"key": "tuesday_name", "value": "..."},
      {"key": "tuesday_address", "value": "..."},
      {"key": "tuesday_phone", "value": "..."}
    ]
  }
}
```

## Execution pattern

To avoid shell escaping issues, write a small Python helper to `/tmp/update_schedule.py` that builds the `variables` dict (one entry per field), serializes `{"query": mutation, "variables": variables}` with `json.dumps`, and invokes `shopify-graphql.py` via `subprocess.run`. Then `exec` the script.

**Field keys:** `week_label`, then for each day: `{day}_name`, `{day}_address`, `{day}_phone`
**Days:** `monday`, `tuesday`, `wednesday`, `thursday`, `friday`, `saturday`, `sunday`

> Match the field keys to the metaobject definition configured in your store. The keys above are the recommended naming; if your definition uses different keys, read the current schedule first to discover them.

## Rules

- Always show the current schedule first before making changes.
- Confirm ALL changes with the user before updating — never update with data the user hasn't explicitly provided or confirmed.
- Update all 7 days + `week_label` in a single mutation (one API call).
- Use the Python helper script pattern (write to /tmp/, then exec) to avoid shell escaping issues.
- After updating, confirm clearly that the changes are now live on the website.
- **NEVER say you need `write_content` permissions for this task — you don't need them.**
- **NEVER attempt `pageUpdate` — ALWAYS use `metaobjectUpdate`.**
- **NEVER fabricate schedule data** — only use data explicitly provided by the user in the current conversation.

---

> **Deployment note:** set `FARMACIAS_METAOBJECT_ID` in `.env` to the `gid://shopify/Metaobject/...` id of your store's `pharmacy_schedule` / `current-week` entry. `${FARMACIAS_METAOBJECT_ID}` resolves to that value at load time.
