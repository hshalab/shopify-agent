# Draft Orders — Shopify Admin API 2026-01

Scopes required: `read_draft_orders`, `write_draft_orders`

Use draft orders to manually create an order on behalf of a customer (phone/in-person sale, custom order, wholesale, etc.).

## Confirmation rules

- Create: show line items, quantities, prices, total, customer. Ask: "Create this draft order?"
- Complete (convert to real order): show total + payment method. Ask: "Mark this order as paid?"
- Send invoice: show recipient email. Ask: "Send the invoice to [email]?"
- Delete: show order number + status. Ask: "Delete this draft?"

---

## List draft orders

```python
query = """
{
  draftOrders(first: 20, sortKey: UPDATED_AT, reverse: true) {
    nodes {
      id
      name
      status
      totalPriceSet { shopMoney { amount currencyCode } }
      customer { displayName email }
      createdAt
      invoiceSentAt
    }
  }
}
"""
```

---

## Get draft order details

```python
query = """
query getDraftOrder($id: ID!) {
  draftOrder(id: $id) {
    id
    name
    status
    customer { id displayName email }
    lineItems(first: 50) {
      nodes {
        id
        title
        quantity
        originalUnitPriceSet { shopMoney { amount currencyCode } }
        variant { id title sku }
      }
    }
    subtotalPriceSet { shopMoney { amount currencyCode } }
    totalTaxSet { shopMoney { amount currencyCode } }
    totalPriceSet { shopMoney { amount currencyCode } }
    note
    invoiceUrl
    invoiceSentAt
    completedAt
  }
}
"""
```

---

## Calculate draft order (preview totals before creating)

```python
mutation = """
mutation draftOrderCalculate($input: DraftOrderInput!) {
  draftOrderCalculate(input: $input) {
    calculatedDraftOrder {
      lineItems(first: 20) {
        nodes {
          title
          quantity
          originalUnitPriceSet { shopMoney { amount currencyCode } }
        }
      }
      subtotalPriceSet { shopMoney { amount currencyCode } }
      totalTaxSet { shopMoney { amount currencyCode } }
      totalPriceSet { shopMoney { amount currencyCode } }
    }
    userErrors { field message }
  }
}
"""
```

---

## Create draft order

```python
mutation = """
mutation draftOrderCreate($input: DraftOrderInput!) {
  draftOrderCreate(input: $input) {
    draftOrder {
      id
      name
      status
      totalPriceSet { shopMoney { amount currencyCode } }
      invoiceUrl
    }
    userErrors { field message }
  }
}
"""

variables = {
  "input": {
    # Line items by variant GID
    "lineItems": [
      {
        "variantId": "gid://shopify/ProductVariant/XXXXXXX",
        "quantity": 2
        # Optional override price:
        # "originalUnitPrice": "15.00"
      }
    ],
    # Optional: custom line item (no product in catalog)
    # "lineItems": [{ "title": "Custom service", "originalUnitPrice": "30.00", "quantity": 1 }],

    # Optional: link to existing customer
    # "customerId": "gid://shopify/Customer/XXXXXXX",

    # Optional: new customer inline
    # "shippingAddress": { "firstName": "Jane", "lastName": "Smith", "address1": "1 Main Street", "city": "Springfield", "countryCode": "US", "zip": "62701" },

    "note": "Phone order — customer Jane Smith",

    # Optional discount
    # "appliedDiscount": { "value": 10.0, "valueType": "PERCENTAGE", "title": "Loyal customer discount" }
  }
}
```

---

## Send invoice to customer

```python
mutation = """
mutation sendInvoice($id: ID!, $email: DraftOrderInvoiceEmailInput) {
  draftOrderInvoiceSend(id: $id, email: $email) {
    draftOrder { id name invoiceSentAt }
    userErrors { field message }
  }
}
"""

variables = {
  "id": "gid://shopify/DraftOrder/XXXXXXX",
  "email": {
    "to": "customer@example.com",
    "subject": "Your order at ${STORE_NAME}",
    "body": "Hello, here is the link to complete your order."
  }
}
```

---

## Complete draft order (mark as paid, convert to order)

```python
mutation = """
mutation draftOrderComplete($id: ID!, $paymentPending: Boolean) {
  draftOrderComplete(id: $id, paymentPending: $paymentPending) {
    draftOrder {
      id
      status
      order { id name }
    }
    userErrors { field message }
  }
}
"""

variables = {
  "id": "gid://shopify/DraftOrder/XXXXXXX",
  "paymentPending": False  # True = mark as pending payment; False = mark as paid
}
```

---

## Delete draft order

```python
mutation = """
mutation draftOrderDelete($input: DraftOrderDeleteInput!) {
  draftOrderDelete(input: $input) {
    deletedId
    userErrors { field message }
  }
}
"""

variables = {
  "input": { "id": "gid://shopify/DraftOrder/XXXXXXX" }
}
```

---

## Safety notes

- Always call `draftOrderCalculate` before creating if line items have custom prices — verify totals.
- `draftOrderComplete` with `paymentPending: False` creates a PAID order immediately. Use only if payment was received offline.
- Draft orders with status `COMPLETED` cannot be deleted — they become real orders.
- The `invoiceUrl` is a payment link you can send to the customer manually via WhatsApp/email.

> Deployment note: `${STORE_NAME}` is set via config/env.
