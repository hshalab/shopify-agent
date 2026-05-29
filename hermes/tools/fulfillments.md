# Fulfillments & Shipping — Shopify Admin API 2026-01

Scopes required: `read_orders`, `write_fulfillments`, `read_fulfillments`, `write_merchant_managed_fulfillment_orders`, `read_merchant_managed_fulfillment_orders`, `write_assigned_fulfillment_orders`, `read_assigned_fulfillment_orders`

## Confirmation rules

- Fulfill: show order number, items, tracking number (if any). Ask: "Mark these items as shipped?"
- Cancel fulfillment: show order and tracking. Ask: "Cancel this fulfillment?"
- Batch fulfillments: summary table then one confirmation.

---

## Get unfulfilled orders (ready to ship)

```python
query = """
{
  orders(first: 20, query: "fulfillment_status:unfulfilled financial_status:paid") {
    nodes {
      id
      name
      createdAt
      customer { displayName email }
      fulfillmentOrders(first: 5) {
        nodes {
          id
          status
          assignedLocation { name }
          lineItems(first: 20) {
            nodes {
              id
              totalQuantity
              remainingQuantity
              lineItem {
                title
                quantity
                variant { sku }
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

## Get fulfillment orders for a specific order

```python
query = """
query fulfillmentOrders($orderId: ID!) {
  order(id: $orderId) {
    id
    name
    fulfillmentOrders(first: 10) {
      nodes {
        id
        status
        requestStatus
        supportedActions { action }
        lineItems(first: 20) {
          nodes {
            id
            totalQuantity
            remainingQuantity
            lineItem { title variant { sku } }
          }
        }
      }
    }
  }
}
"""
```

---

## Create fulfillment (mark items as shipped)

```python
mutation = """
mutation fulfillmentCreate($fulfillment: FulfillmentV2Input!) {
  fulfillmentCreateV2(fulfillment: $fulfillment) {
    fulfillment {
      id
      status
      trackingInfo { number url company }
      fulfillmentLineItems(first: 20) {
        nodes { quantity lineItem { title } }
      }
    }
    userErrors { field message }
  }
}
"""

variables = {
  "fulfillment": {
    "lineItemsByFulfillmentOrder": [
      {
        "fulfillmentOrderId": "gid://shopify/FulfillmentOrder/XXXXXXX"
        # To fulfill only some items from the fulfillment order:
        # "fulfillmentOrderLineItems": [
        #   { "id": "gid://shopify/FulfillmentOrderLineItem/XXXXXXX", "quantity": 1 }
        # ]
      }
    ],
    "trackingInfo": {
      "number": "1Z999AA10123456784",      # tracking number
      "company": "UPS",                     # carrier name
      "url": "https://www.ups.com/track?tracknum=1Z999AA10123456784"  # optional tracking URL
    },
    "notifyCustomer": True  # sends shipping confirmation email
  }
}
```

---

## Update tracking information after fulfillment

```python
mutation = """
mutation fulfillmentTrackingUpdate($id: ID!, $trackingInfoUpdateInput: FulfillmentTrackingInput!, $notifyCustomer: Boolean) {
  fulfillmentTrackingInfoUpdateV2(fulfillmentId: $id, trackingInfoInput: $trackingInfoUpdateInput, notifyCustomer: $notifyCustomer) {
    fulfillment {
      id
      trackingInfo { number url company }
    }
    userErrors { field message }
  }
}
"""

variables = {
  "id": "gid://shopify/Fulfillment/XXXXXXX",
  "trackingInfoUpdateInput": {
    "number": "9400100000000000000000",
    "company": "USPS",
    "url": "https://tools.usps.com/go/TrackConfirmAction?tLabels=9400100000000000000000"
  },
  "notifyCustomer": False  # True to resend shipping email with new tracking
}
```

---

## Cancel a fulfillment

```python
mutation = """
mutation fulfillmentCancel($id: ID!) {
  fulfillmentCancel(id: $id) {
    fulfillment {
      id
      status
    }
    userErrors { field message }
  }
}
"""
```

Only fulfillments with status `SUCCESS` or `OPEN` can be cancelled. After cancellation, the order returns to unfulfilled status.

---

## List fulfillments for an order

```python
query = """
query orderFulfillments($orderId: ID!) {
  order(id: $orderId) {
    name
    fulfillments(first: 10) {
      id
      status
      createdAt
      trackingInfo { number url company }
      fulfillmentLineItems(first: 20) {
        nodes {
          quantity
          lineItem { title }
        }
      }
    }
  }
}
"""
```

---

## Safety notes

- Always get `fulfillmentOrders` before creating a fulfillment — you need the `fulfillmentOrderId`, not the plain order ID.
- `notifyCustomer: True` sends a Shopify email. Only use if the store's email templates are configured.
- A fulfillment can only be cancelled if its status is `SUCCESS` or `OPEN`. Check before attempting.
- Partial fulfillments are supported — include only the specific `fulfillmentOrderLineItems` you're shipping.
- After cancelling a fulfillment, inventory is automatically returned to stock.
