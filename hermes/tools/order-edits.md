# Order Edits & Cancellations — Shopify Admin API 2026-01

Scopes required: `read_orders`, `write_orders`, `read_order_edits`, `write_order_edits`

## Confirmation rules

- Edit: always show a before/after diff. Ask: "Confirm these changes to order [name]?"
- Cancel: show order number, total, items. Ask: "Cancel order [name]? This action cannot be undone."
- Commit is irreversible — never call `orderEditCommit` without showing the diff and getting confirmation.

---

## Get order details for editing

```python
query = """
query getOrder($id: ID!) {
  order(id: $id) {
    id
    name
    displayFinancialStatus
    displayFulfillmentStatus
    lineItems(first: 50) {
      nodes {
        id
        title
        quantity
        originalUnitPriceSet { shopMoney { amount currencyCode } }
        variant { id sku }
        refundableQuantity
        unfulfilledQuantity
      }
    }
    subtotalPriceSet { shopMoney { amount currencyCode } }
    totalPriceSet { shopMoney { amount currencyCode } }
    customer { displayName email }
    note
    tags
  }
}
"""
```

---

## Edit order flow (3 steps: begin → modify → commit)

### Step 1: Begin edit session

```python
mutation = """
mutation orderEditBegin($id: ID!) {
  orderEditBegin(id: $id) {
    calculatedOrder {
      id
      lineItems(first: 50) {
        nodes {
          id
          title
          quantity
          calculatedDiscountedUnitPriceSet { shopMoney { amount currencyCode } }
        }
      }
      subtotalPriceSet { shopMoney { amount currencyCode } }
    }
    userErrors { field message }
  }
}
"""
# Save the calculatedOrder.id — it's needed for all subsequent edit mutations
```

### Step 2a: Add a product variant

```python
mutation = """
mutation addVariant($id: ID!, $variantId: ID!, $quantity: Int!, $allowDuplicates: Boolean) {
  orderEditAddVariant(id: $id, variantId: $variantId, quantity: $quantity, allowDuplicates: $allowDuplicates) {
    calculatedOrder {
      id
      addedLineItems(first: 5) {
        nodes {
          id
          title
          quantity
          calculatedDiscountedUnitPriceSet { shopMoney { amount currencyCode } }
        }
      }
      subtotalPriceSet { shopMoney { amount currencyCode } }
    }
    calculatedLineItem { id title quantity }
    userErrors { field message }
  }
}
"""
variables = {
  "id": "gid://shopify/CalculatedOrder/XXXXXXX",
  "variantId": "gid://shopify/ProductVariant/XXXXXXX",
  "quantity": 1,
  "allowDuplicates": False  # True to add even if variant already in order
}
```

### Step 2b: Change line item quantity

```python
mutation = """
mutation setQuantity($id: ID!, $lineItemId: ID!, $quantity: Int!, $restock: Boolean) {
  orderEditSetQuantity(id: $id, lineItemId: $lineItemId, quantity: $quantity, restock: $restock) {
    calculatedOrder {
      id
      subtotalPriceSet { shopMoney { amount currencyCode } }
    }
    calculatedLineItem { id title quantity }
    userErrors { field message }
  }
}
"""
variables = {
  "id": "gid://shopify/CalculatedOrder/XXXXXXX",
  "lineItemId": "gid://shopify/CalculatedLineItem/XXXXXXX",
  "quantity": 0,    # 0 = remove the line item
  "restock": True   # return units to inventory
}
```

### Step 2c: Add custom (non-catalog) line item

```python
mutation = """
mutation addCustomItem($id: ID!, $title: String!, $price: MoneyInput!, $quantity: Int!, $taxable: Boolean) {
  orderEditAddCustomItem(id: $id, title: $title, price: $price, quantity: $quantity, taxable: $taxable) {
    calculatedOrder { id subtotalPriceSet { shopMoney { amount currencyCode } } }
    calculatedLineItem { id title quantity }
    userErrors { field message }
  }
}
"""
variables = {
  "id": "gid://shopify/CalculatedOrder/XXXXXXX",
  "title": "Consultation service",
  "price": { "amount": "10.00", "currencyCode": "USD" },
  "quantity": 1,
  "taxable": True
}
```

### Step 3: Commit the edit

```python
mutation = """
mutation orderEditCommit($id: ID!, $notifyCustomer: Boolean, $staffNote: String) {
  orderEditCommit(id: $id, notifyCustomer: $notifyCustomer, staffNote: $staffNote) {
    order { id name totalPriceSet { shopMoney { amount currencyCode } } }
    userErrors { field message }
  }
}
"""
variables = {
  "id": "gid://shopify/CalculatedOrder/XXXXXXX",
  "notifyCustomer": True,
  "staffNote": "Item added at customer's request"
}
```

---

## Cancel an order

```python
mutation = """
mutation orderCancel($orderId: ID!, $reason: OrderCancelReason!, $refund: Boolean!, $restock: Boolean!, $notifyCustomer: Boolean, $staffNote: String) {
  orderCancel(orderId: $orderId, reason: $reason, refund: $refund, restock: $restock, notifyCustomer: $notifyCustomer, staffNote: $staffNote) {
    orderCancelUserErrors { field message }
    userErrors { field message }
  }
}
"""

variables = {
  "orderId": "gid://shopify/Order/XXXXXXX",
  "reason": "CUSTOMER",        # CUSTOMER | INVENTORY | FRAUD | DECLINED | OTHER
  "refund": True,              # True = refund automatically if paid
  "restock": True,             # True = return items to inventory
  "notifyCustomer": True,
  "staffNote": "Cancelled at customer's request by phone"
}
```

### Cancellation reason codes

| Code | Use when |
|---|---|
| `CUSTOMER` | Customer requested cancellation |
| `INVENTORY` | Item out of stock |
| `FRAUD` | Suspected fraud |
| `DECLINED` | Payment declined |
| `OTHER` | Other reason |

---

## Update order note or tags (no edit session needed)

```python
mutation = """
mutation orderUpdate($input: OrderInput!) {
  orderUpdate(input: $input) {
    order { id name note tags }
    userErrors { field message }
  }
}
"""

variables = {
  "input": {
    "id": "gid://shopify/Order/XXXXXXX",
    "note": "Customer called to confirm address",
    "tags": ["repeat-customer", "call-confirmed"]
  }
}
```

---

## Safety notes

- An order can only be cancelled if `displayFulfillmentStatus` is `UNFULFILLED` — check before attempting.
- `orderEditBegin` locks the order for other edits. If the session is abandoned (no commit), the lock expires automatically after ~10 minutes.
- `orderEditCommit` with `notifyCustomer: True` sends an email to the buyer — only use when the store's email templates are properly set.
- Setting line item quantity to `0` removes it. This cannot be undone after commit.
- Orders that are fully or partially fulfilled cannot have fulfilled items edited — only unfulfilled line items.
