# TOOLS.md — Shopify Store Management

API version `2026-01`. Detailed queries/mutations live in `tools/*.md` and are loaded on demand.

## Store Connection

**Only way to talk to Shopify** is `shopify-graphql.py` (handles auth, 24h token, rate-limit warnings):

```bash
python3 /opt/data/scripts/shopify-graphql.py '<json>'
```

Pass one JSON string with a `"query"` field; for mutations add `"variables"`. Results print to stdout, errors print to stderr as `{"error": "..."}`. Do not use curl, urllib, or any other HTTP client.

Examples:
```bash
python3 /opt/data/scripts/shopify-graphql.py '{"query": "{ productsCount(limit: null) { count } }"}'
python3 /opt/data/scripts/shopify-graphql.py '{"query": "mutation productUpdate($product: ProductUpdateInput!) { productUpdate(product: $product) { product { id title status } userErrors { field message } } }", "variables": {"product": {"id": "gid://shopify/Product/123", "title": "New Title"}}}'
```

## Module Index — read on demand

When a request matches one of these areas, FIRST read the linked file with your `read` tool to get the verified queries and area-specific rules. Do not rely on memory for query syntax — the API can change between versions and these files are the source of truth.

| Area | File | When to read |
|------|------|--------------|
| Read products / search / list collections / inventory | `/opt/data/tools/queries.md` | Any read query |
| Create / update products / collections / variants / images | `/opt/data/tools/mutations.md` | Any write mutation |
| Blog articles + SEO content rules | `/opt/data/tools/blog.md` | Anything blog or content marketing |
| Orders, analytics, low stock, SEO audit | `/opt/data/tools/orders.md` | Reports, dashboards, sales |
| Cron / scheduled tasks | `/opt/data/tools/cron.md` | Setting up recurring runs |
| Discounts & price rules | `/opt/data/tools/discounts.md` | Create/edit/activate/deactivate discounts and codes |
| Gift cards | `/opt/data/tools/gift-cards.md` | Issue, query, or disable gift cards |
| Draft orders | `/opt/data/tools/draft-orders.md` | Manual orders, phone sales, invoices |
| Fulfillments & tracking | `/opt/data/tools/fulfillments.md` | Mark items as shipped, add tracking, cancel shipments |
| Returns & refunds | `/opt/data/tools/returns.md` | Process returns and refunds |
| Order edits & cancellations | `/opt/data/tools/order-edits.md` | Edit line items, cancel orders |
| Inventory transfers & adjustments | `/opt/data/tools/inventory-ops.md` | Move stock between locations, manual adjustments |
| Customers | `/opt/data/tools/customers.md` | Search, create, update, tag customers; marketing consent |
| Online store pages & navigation | `/opt/data/tools/online-store.md` | Manage static pages and navigation menus |
| Shipping zones & rates | `/opt/data/tools/shipping.md` | **Owner-only.** View and edit delivery profiles and rates |
| Markets, locales & currencies | `/opt/data/tools/markets.md` | International markets, language configuration |
| Translations | `/opt/data/tools/translations.md` | Translate products, collections, pages to other languages |

After reading the relevant file, the queries/mutations in it are authoritative — do not invent variations.

## Scopes Available

**Products & inventory:** `write_products`, `read_products`, `read_product_listings`, `write_inventory`, `read_inventory`, `write_inventory_transfers`, `read_inventory_transfers`, `write_inventory_shipments`, `read_inventory_shipments`, `write_files`, `read_files`, `read_publications`, `write_publications`, `read_locations`, `write_locations`

**Content:** `read_content`, `write_content`, `write_metaobjects`, `read_metaobjects`, `read_metaobject_definitions`, `write_metaobject_definitions`, `read_online_store_pages`, `write_online_store_pages`, `read_online_store_navigation`, `write_online_store_navigation`

**Orders & fulfillment:** `read_orders`, `read_all_orders`, `write_orders`, `read_order_edits`, `write_order_edits`, `write_draft_orders`, `read_draft_orders`, `write_fulfillments`, `read_fulfillments`, `write_returns`, `read_returns`, `write_merchant_managed_fulfillment_orders`, `read_merchant_managed_fulfillment_orders`, `write_assigned_fulfillment_orders`, `read_assigned_fulfillment_orders`

**Customers:** `read_customers`, `write_customers`, `read_customer_events`

**Discounts & promotions:** `read_discounts`, `write_discounts`, `read_price_rules`, `write_price_rules`, `read_gift_cards`, `write_gift_cards`, `write_gift_card_transactions`, `read_gift_card_transactions`

**Analytics & reports:** `read_analytics`, `read_reports`, `write_reports`

**Localization:** `read_translations`, `write_translations`, `read_markets`, `write_markets`, `read_locales`, `write_locales`

**Shipping:** `read_shipping`, `write_shipping` *(owner-only — do not call without explicit !admin approval)*

## Scopes Blocked by Policy (available technically, never expose)

- `write_themes`, `write_theme_code` — theme/design changes
- `write_script_tags`, `write_custom_pixels` — store code injection
- `write_checkout_and_accounts_configurations`, `write_checkout_branding_settings` — checkout config
- `read_customer_payment_methods` — customer payment data
- `write_customer_data_erasure`, `write_privacy_settings` — GDPR/legal operations
- `write_legal_policies` — legal texts
- `write_channels`, `write_app_proxy` — distribution/integrations
- All `unauthenticated_write_*` and `customer_write_*` scopes — storefront mutations
- `write_payment_customizations`, `write_payment_mandate` — payment config

## Critical Rules (always apply)

- **NEVER use `productDelete`** — use `productUpdate(status: DRAFT)` instead.
- **Always confirm with user before any mutation.**
- **ALWAYS `publishablePublish` to Online Store (`${ONLINE_STORE_PUBLICATION_ID}`) immediately after `productCreate` or `collectionCreate`.** This store has `autoPublish: false`, so skipping it leaves the item invisible in the storefront. Only confirm success once both create AND publish mutations succeeded without `userErrors`. Set via env `ONLINE_STORE_PUBLICATION_ID`; see `tools/mutations.md`.
- Price updates go through `productVariantsBulkUpdate`, not product update.
- New products always start as `DRAFT` (but must still be published to Online Store — status and publication are independent).
- Report the admin URL after creation: `https://{STORE}/admin/products/{numeric_id}`.
- When searching, use flexible matching (partial title, tags).
- For bulk operations, batch mutations to respect rate limits.
- **HTTP 200 ≠ success.** Always check BOTH the top-level `errors` array AND per-field `userErrors`. If either is non-empty, the operation failed even if status is 200. The helper script `shopify-graphql.py` exits non-zero when `errors` is present, so check the exit code AND scan stderr — do not just parse stdout.
- **Always inspect `extensions.cost.throttleStatus.currentlyAvailable` in responses.** Standard plan = 1000 points bucket, 50/s restore. If the next query's `requestedQueryCost` is close to or exceeds `currentlyAvailable`, wait 5–10 s before retrying. The helper script flags this with a `_warning` field when the available pool drops below 100.
- **Numeric IDs must be wrapped as GID strings.** If the user gives `123456`, convert to `gid://shopify/Product/123456` (or the relevant type — `Variant`, `Order`, `Collection`, `Article`, `MediaImage`, `Metaobject`) before passing to any query/mutation. Do NOT pass bare numbers — most fields require the full `gid://...` form.
- **HTTP 403 with a valid token = missing scope, not a token problem.** Don't tell the user to "regenerate the token". Internally, log it; externally, follow the "When you can't do something" rule in SOUL.md and route the user to the store owner. Never expose scope names in chat.
