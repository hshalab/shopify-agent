# Discounts & Price Rules — Shopify Admin API 2026-01

Scopes required: `read_discounts`, `write_discounts`, `read_price_rules`, `write_price_rules`

## Confirmation rules

- Always show: code (if any), type (%), amount, affected products/collections, start/end date.
- Ask: "Confirm this discount?"
- Single discount: ask individually. Batch (4+): summary table then one confirmation.
- NEVER activate a discount without showing the end date — open-ended discounts are risky.

---

## List all active discounts

```python
query = """
{
  discountNodes(first: 20, query: "status:ACTIVE") {
    nodes {
      id
      discount {
        ... on DiscountAutomaticBasic {
          title
          status
          startsAt
          endsAt
          customerGets {
            value {
              ... on DiscountPercentage { percentage }
              ... on DiscountAmount { amount { amount currencyCode } }
            }
            items {
              ... on AllDiscountItems { allItems }
              ... on DiscountProducts { productVariants(first: 5) { nodes { displayName } } }
              ... on DiscountCollections { collections(first: 5) { nodes { title } } }
            }
          }
        }
        ... on DiscountCodeBasic {
          title
          status
          startsAt
          endsAt
          codes(first: 3) { nodes { code } }
          customerGets {
            value {
              ... on DiscountPercentage { percentage }
              ... on DiscountAmount { amount { amount currencyCode } }
            }
          }
        }
      }
    }
  }
}
"""
```

---

## Create automatic discount (no code needed)

Use when the discount should apply automatically at checkout for all customers.

```python
mutation = """
mutation discountAutomaticBasicCreate($discount: DiscountAutomaticBasicInput!) {
  discountAutomaticBasicCreate(automaticBasicDiscount: $discount) {
    automaticDiscountNode {
      id
      discount { ... on DiscountAutomaticBasic { title status startsAt endsAt } }
    }
    userErrors { field message }
  }
}
"""

# Example: 15% off all products from May 15 to May 31
variables = {
  "discount": {
    "title": "15% off all products",
    "startsAt": "2026-05-15T00:00:00Z",
    "endsAt": "2026-05-31T23:59:59Z",
    "customerGets": {
      "value": { "percentage": 0.15 },
      "items": { "allItems": True }
      # For specific collection:
      # "items": { "collections": { "add": ["gid://shopify/Collection/XXXXX"] } }
    },
    "minimumRequirement": {
      # Optional min purchase:
      # "subtotal": { "greaterThanOrEqualToSubtotal": "20.00" }
    }
  }
}
```

---

## Create code discount (customer enters a code)

```python
mutation = """
mutation discountCodeBasicCreate($discount: DiscountCodeBasicInput!) {
  discountCodeBasicCreate(basicCodeDiscount: $discount) {
    codeDiscountNode {
      id
      codeDiscount {
        ... on DiscountCodeBasic {
          title
          status
          codes(first: 1) { nodes { code } }
          startsAt
          endsAt
        }
      }
    }
    userErrors { field message }
  }
}
"""

variables = {
  "discount": {
    "title": "Descuento MAYO20",
    "code": "MAYO20",
    "startsAt": "2026-05-01T00:00:00Z",
    "endsAt": "2026-05-31T23:59:59Z",
    "customerGets": {
      "value": { "percentage": 0.20 },
      "items": { "allItems": True }
    },
    "customerSelection": { "allCustomers": True },
    "usageLimit": 100,              # max total uses, null = unlimited
    "appliesOncePerCustomer": True  # limits 1 use per customer
  }
}
```

---

## Activate / deactivate a discount

```python
# Deactivate code discount
mutation_deactivate = """
mutation deactivate($id: ID!) {
  discountCodeDeactivate(id: $id) {
    codeDiscountNode { id codeDiscount { ... on DiscountCodeBasic { status } } }
    userErrors { field message }
  }
}
"""

# Activate code discount
mutation_activate = """
mutation activate($id: ID!) {
  discountCodeActivate(id: $id) {
    codeDiscountNode { id codeDiscount { ... on DiscountCodeBasic { status } } }
    userErrors { field message }
  }
}
"""

# For automatic discounts use discountAutomaticActivate / discountAutomaticDeactivate
```

---

## Delete a discount

```python
# Code discount
mutation_delete_code = """
mutation deleteCode($id: ID!) {
  discountCodeDelete(id: $id) {
    deletedCodeDiscountId
    userErrors { field message }
  }
}
"""

# Automatic discount
mutation_delete_auto = """
mutation deleteAuto($id: ID!) {
  discountAutomaticDelete(id: $id) {
    deletedAutomaticDiscountId
    userErrors { field message }
  }
}
"""
```

---

## Create buy-X-get-Y discount

```python
mutation = """
mutation bxgy($discount: DiscountAutomaticBxgyInput!) {
  discountAutomaticBxgyCreate(automaticBxgyDiscount: $discount) {
    automaticDiscountNode { id }
    userErrors { field message }
  }
}
"""

variables = {
  "discount": {
    "title": "Buy 2 get 1 free",
    "startsAt": "2026-05-01T00:00:00Z",
    "customerBuys": {
      "value": { "quantity": "2" },
      "items": { "allItems": True }
    },
    "customerGets": {
      "value": { "discountOnQuantity": { "quantity": "1", "effect": { "percentage": 1.0 } } },
      "items": { "allItems": True }
    },
    "usesPerOrderLimit": "1"
  }
}
```

---

## Safety notes

- Always verify `userErrors` — a 200 response does NOT mean the discount was created.
- Discounts with `endsAt: null` are permanent — always ask for an end date.
- Cannot delete an ACTIVE discount. Deactivate first, then delete if needed.
- `appliesOncePerCustomer: True` is recommended for code discounts to prevent abuse.
- Percentage value is decimal: 15% = `0.15`, not `15`.
