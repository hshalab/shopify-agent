# Queries (Read Operations)

All queries verified against Shopify Admin API `2026-01`.

## Count Products

```graphql
{ productsCount(limit: null) { count } }
```

> **API 2026-01 change:** Top-level QueryRoot `*Count` fields (e.g. `productsCount`, `collectionsCount`, `ordersCount`) default to a cap of 10,000. Pass `(limit: null)` for an uncapped count. Nested `productsCount` on objects like `Collection` does NOT accept `limit` — use it without arguments.

## Search Products

```graphql
{
  products(first: 10, query: "title:*keyword*") {
    edges {
      node {
        id
        title
        status
        totalInventory
        priceRangeV2 {
          minVariantPrice { amount currencyCode }
        }
      }
    }
  }
}
```

## Product Details (with variants, media, tags)

```graphql
{
  products(first: 1, query: "title:*keyword*") {
    edges {
      node {
        id
        title
        status
        descriptionHtml
        tags
        totalInventory
        variants(first: 5) {
          edges {
            node {
              id
              title
              price
              sku
              inventoryQuantity
            }
          }
        }
        media(first: 10) {
          edges {
            node {
              id
              mediaContentType
              status
              ... on MediaImage {
                image { url altText }
              }
            }
          }
        }
      }
    }
  }
}
```

## List Collections

```graphql
{
  collections(first: 50) {
    edges {
      node {
        id
        title
        handle
        productsCount(limit: null) { count }
        sortOrder
      }
    }
  }
}
```

## Products in a Collection

```graphql
{
  collection(id: "gid://shopify/Collection/COLLECTION_ID") {
    title
    products(first: 20) {
      edges {
        node {
          id
          title
          status
          totalInventory
        }
      }
    }
  }
}
```

## Inventory Levels (for a variant)

> `location.name` requires `read_locations` scope (not granted). Omit it.

```graphql
{
  productVariant(id: "gid://shopify/ProductVariant/VARIANT_ID") {
    inventoryItem {
      id
      inventoryLevels(first: 3) {
        edges {
          node {
            id
            quantities(names: ["available"]) {
              name
              quantity
            }
          }
        }
      }
    }
  }
}
```

## Pagination Pattern (cursors)

Shopify connections (`products`, `orders`, `collections`, `articles`, `metaobjects`, etc.) cap each page at `first: 250`. To walk a list larger than that, run the same query repeatedly and pass `after: <endCursor>` each time. Stop when `pageInfo.hasNextPage` is `false`.

Reusable shape — always include `pageInfo { hasNextPage endCursor }`:

```graphql
query($cursor: String) {
  products(first: 100, after: $cursor, query: "status:active") {
    edges {
      cursor
      node { id title status }
    }
    pageInfo { hasNextPage endCursor }
  }
}
```

Variables on the first call:

```json
{ "cursor": null }
```

After each call, read `pageInfo.endCursor` and `pageInfo.hasNextPage` from the response. While `hasNextPage` is `true`, run the next call with `{ "cursor": "<endCursor from previous response>" }`.

**Rules:**

- Pass `null` (not an empty string) on the first call.
- Cap the loop at 200 iterations as a safety net to avoid infinite loops on malformed cursors.
- Pause 200–500 ms between calls to stay well under the throttle bucket — see TOOLS.md § "Critical Rules" on `extensions.cost.throttleStatus`.
- For very large dumps (full catalog, all-time orders) prefer fewer big pages (`first: 250`) over many small ones — fewer round-trips, but watch the per-query cost.
- If the connection supports `sortKey`, set it explicitly (`sortKey: CREATED_AT, reverse: true` for newest-first). Default ordering is by `id`, which is rarely what you want for "most recent".
