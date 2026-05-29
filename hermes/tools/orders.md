# Orders & Analytics Queries

## Total Orders Count

```graphql
{ ordersCount(limit: null) { count } }
```

## Orders (recent, or in a date range)

Add `sortKey: CREATED_AT, reverse: true` for "most recent". For a date window use `query: "created_at:>2026-03-01 created_at:<2026-03-31"` (ISO 8601).

```graphql
{
  orders(first: 10, sortKey: CREATED_AT, reverse: true) {
    edges { node {
      id name createdAt
      totalPriceSet { shopMoney { amount currencyCode } }
      displayFinancialStatus displayFulfillmentStatus
      lineItems(first: 10) { edges { node { title quantity originalTotalSet { shopMoney { amount currencyCode } } } } }
    } }
  }
}
```

## Low Stock Products (sorted by inventory ascending)

```graphql
{
  products(first: 20, query: "status:active", sortKey: INVENTORY_TOTAL) {
    edges {
      node {
        id title totalInventory status
        variants(first: 1) { edges { node { inventoryQuantity sku } } }
      }
    }
  }
}
```

## Products with Empty or Short Descriptions (SEO audit)

```graphql
{
  products(first: 50, query: "status:active") {
    edges {
      node {
        id title descriptionHtml status
        seo { title description }
      }
    }
  }
}
```
