# Returns & Refunds — Shopify Admin API 2026-01

Scopes required: `read_returns`, `write_returns`, `read_orders`, `write_orders`

## Confirmation rules

- Create return: show order number, items, quantities, reason. Ask: "Create this return?"
- Refund: show amount, method (original payment vs. store credit). Ask: "Process the refund of [amount] to [customer]?"
- Refund is irreversible — always double-check the amount before confirming.

---

## List returnable items for an order

Before creating a return, check which items are eligible.

```python
query = """
query returnableItems($orderId: ID!) {
  order(id: $orderId) {
    id
    name
    returnableFulfillments(first: 20) {
      nodes {
        fulfillment {
          id
          status
          trackingInfo { number }
        }
        returnableFulfillmentLineItems(first: 20) {
          nodes {
            quantity
            fulfillmentLineItem {
              id
              quantity
              lineItem {
                title
                quantity
                refundableQuantity
                variant { id sku price }
              }
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

## Create return

```python
mutation = """
mutation returnCreate($returnInput: ReturnInput!) {
  returnCreate(returnInput: $returnInput) {
    return {
      id
      status
      order { name }
      returnLineItems(first: 20) {
        nodes {
          quantity
          returnReason
          returnReasonNote
          fulfillmentLineItem {
            lineItem { title }
          }
        }
      }
    }
    userErrors { field message }
  }
}
"""

variables = {
  "returnInput": {
    "orderId": "gid://shopify/Order/XXXXXXX",
    "returnLineItems": [
      {
        "fulfillmentLineItemId": "gid://shopify/FulfillmentLineItem/XXXXXXX",
        "quantity": 1,
        "returnReason": "UNWANTED",  # see reason codes below
        "returnReasonNote": "Customer changed their mind"
      }
    ],
    "notifyCustomer": True  # sends return confirmation email
  }
}
```

### Return reason codes

| Code | Meaning |
|---|---|
| `UNWANTED` | Customer changed mind |
| `SIZE_TOO_SMALL` | Size issue |
| `SIZE_TOO_LARGE` | Size issue |
| `WRONG_ITEM` | Wrong item received |
| `DEFECTIVE` | Item is defective |
| `NOT_AS_DESCRIBED` | Item doesn't match description |
| `MISSING_PARTS` | Incomplete item |
| `FINAL_SALE` | Cannot be returned (use to flag ineligible) |
| `OTHER` | Other reason — add note |

---

## List returns for an order

```python
query = """
query orderReturns($orderId: ID!) {
  order(id: $orderId) {
    name
    returns(first: 10) {
      nodes {
        id
        status
        createdAt
        returnLineItems(first: 20) {
          nodes {
            quantity
            returnReason
            returnReasonNote
            fulfillmentLineItem {
              lineItem { title }
            }
          }
        }
        refunds(first: 5) {
          id
          totalRefundedSet { shopMoney { amount currencyCode } }
          createdAt
        }
      }
    }
  }
}
"""
```

---

## Create refund (monetary reimbursement)

Refunds can be created independently of returns (e.g., partial refund without return).

```python
mutation = """
mutation refundCreate($input: RefundInput!) {
  refundCreate(input: $input) {
    refund {
      id
      totalRefundedSet { shopMoney { amount currencyCode } }
      transactions(first: 5) {
        nodes {
          id
          status
          amount
          gateway
        }
      }
    }
    userErrors { field message }
  }
}
"""

variables = {
  "input": {
    "orderId": "gid://shopify/Order/XXXXXXX",
    "notify": True,
    # Option A: refund specific line items
    "refundLineItems": [
      {
        "lineItemId": "gid://shopify/LineItem/XXXXXXX",
        "quantity": 1,
        "restockType": "RETURN"  # RETURN | NO_RESTOCK | CANCEL | LEGACY
      }
    ],
    # Option B: refund a fixed amount (shipping, partial, etc.)
    # "transactions": [
    #   {
    #     "parentId": "gid://shopify/OrderTransaction/XXXXXXX",  # original payment transaction ID
    #     "amount": "15.00",
    #     "kind": "REFUND",
    #     "gateway": "manual"
    #   }
    # ],
    "note": "Return due to defective product"
  }
}
```

### Get original transaction ID for refund

```python
query = """
query orderTransactions($orderId: ID!) {
  order(id: $orderId) {
    name
    transactions(first: 5) {
      id
      kind
      status
      amount
      gateway
    }
  }
}
"""
```

---

## Close a return

```python
mutation = """
mutation returnClose($id: ID!) {
  returnClose(id: $id) {
    return { id status }
    userErrors { field message }
  }
}
"""
```

---

## Safety notes

- Refunds are **irreversible** — always show the exact amount and confirm before executing.
- `restockType: "RETURN"` increments inventory back. Use `NO_RESTOCK` if the item is damaged and cannot be resold.
- To refund shipping, use the `transactions` approach with the shipping amount.
- Always check `refundableQuantity` on the line item before creating a refund — you cannot refund more units than were purchased.
- `notifyCustomer: True` sends a Shopify email. Verify the store's email templates before using.
