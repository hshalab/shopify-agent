# Customers — Shopify Admin API 2026-01

Scopes required: `read_customers`, `write_customers`, `read_customer_events`

## Confirmation rules

- Read operations (search, history): autonomous, no confirmation needed.
- Create: show name, email, phone, tags. Ask: "Create this customer?"
- Update: show exact fields that will change (before → after). Ask: "Update this customer's details?"
- Tags: show current tags + changes. Ask: "Update the tags?"
- Email/SMS marketing consent: show current state → new state. Always ask — affects legal compliance.
- Never expose raw payment method data or full billing address without explicit need.

---

## Search customers

```python
query = """
query searchCustomers($query: String!) {
  customers(first: 10, query: $query) {
    nodes {
      id
      displayName
      email
      phone
      numberOfOrders
      totalSpentV2 { amount currencyCode }
      tags
      createdAt
      emailMarketingConsent { marketingState }
      smsMarketingConsent { marketingState }
    }
  }
}
"""
# Query examples:
# "email:jane@example.com"
# "phone:+15555550100"
# "first_name:Jane last_name:Smith"
# "tag:vip-customer"
# "total_spent:>100"
```

---

## Get customer details with order history

```python
query = """
query getCustomer($id: ID!) {
  customer(id: $id) {
    id
    displayName
    firstName
    lastName
    email
    phone
    tags
    note
    numberOfOrders
    totalSpentV2 { amount currencyCode }
    createdAt
    emailMarketingConsent { marketingState consentUpdatedAt }
    smsMarketingConsent { marketingState consentUpdatedAt }
    addresses(first: 5) {
      id
      address1
      city
      countryCodeV2
      zip
      default
    }
    orders(first: 10, sortKey: CREATED_AT, reverse: true) {
      nodes {
        id
        name
        createdAt
        displayFinancialStatus
        displayFulfillmentStatus
        totalPriceSet { shopMoney { amount currencyCode } }
      }
    }
  }
}
"""
```

---

## Create customer

```python
mutation = """
mutation customerCreate($input: CustomerInput!) {
  customerCreate(input: $input) {
    customer {
      id
      displayName
      email
      phone
      tags
    }
    userErrors { field message }
  }
}
"""

variables = {
  "input": {
    "firstName": "Jane",
    "lastName": "Smith",
    "email": "jane@example.com",
    "phone": "+15555550100",
    "tags": ["walk-in-customer"],
    "note": "In-store customer",
    # Email marketing consent (must be explicit):
    "emailMarketingConsent": {
      "marketingState": "SUBSCRIBED",  # SUBSCRIBED | NOT_SUBSCRIBED | UNSUBSCRIBED | PENDING
      "marketingOptInLevel": "SINGLE_OPT_IN"
    }
    # Address (optional):
    # "addresses": [{ "address1": "1 Main Street", "city": "Springfield", "countryCode": "US", "zip": "62701" }]
  }
}
```

---

## Update customer

```python
mutation = """
mutation customerUpdate($input: CustomerInput!) {
  customerUpdate(input: $input) {
    customer {
      id
      displayName
      email
      phone
      tags
      note
    }
    userErrors { field message }
  }
}
"""

variables = {
  "input": {
    "id": "gid://shopify/Customer/XXXXXXX",
    # Only include fields to change:
    "phone": "+15555550199",
    "note": "Prefers contact via WhatsApp",
    "tags": ["vip-customer", "in-store"]  # this REPLACES all existing tags
    # To ADD tags without removing others, use tagsAdd mutation below
  }
}
```

---

## Add tags to customer (non-destructive)

```python
mutation = """
mutation tagsAdd($id: ID!, $tags: [String!]!) {
  tagsAdd(id: $id, tags: $tags) {
    node { id ... on Customer { tags displayName } }
    userErrors { field message }
  }
}
"""
variables = {
  "id": "gid://shopify/Customer/XXXXXXX",
  "tags": ["vip-customer"]
}
```

---

## Remove tags from customer

```python
mutation = """
mutation tagsRemove($id: ID!, $tags: [String!]!) {
  tagsRemove(id: $id, tags: $tags) {
    node { id ... on Customer { tags displayName } }
    userErrors { field message }
  }
}
"""
variables = {
  "id": "gid://shopify/Customer/XXXXXXX",
  "tags": ["tag-to-remove"]
}
```

---

## Update email marketing consent

```python
mutation = """
mutation emailMarketingConsentUpdate($input: CustomerEmailMarketingConsentUpdateInput!) {
  customerEmailMarketingConsentUpdate(input: $input) {
    customer {
      id
      displayName
      emailMarketingConsent { marketingState consentUpdatedAt }
    }
    userErrors { field message }
  }
}
"""

variables = {
  "input": {
    "customerId": "gid://shopify/Customer/XXXXXXX",
    "emailMarketingConsent": {
      "marketingState": "SUBSCRIBED",  # or UNSUBSCRIBED
      "marketingOptInLevel": "SINGLE_OPT_IN",
      "consentUpdatedAt": "2026-05-12T00:00:00Z"
    }
  }
}
```

---

## Update SMS marketing consent

```python
mutation = """
mutation smsMarketingConsentUpdate($input: CustomerSmsMarketingConsentUpdateInput!) {
  customerSmsMarketingConsentUpdate(input: $input) {
    customer {
      id
      displayName
      smsMarketingConsent { marketingState consentUpdatedAt }
    }
    userErrors { field message }
  }
}
"""

variables = {
  "input": {
    "customerId": "gid://shopify/Customer/XXXXXXX",
    "smsMarketingConsent": {
      "marketingState": "SUBSCRIBED",
      "marketingOptInLevel": "SINGLE_OPT_IN",
      "consentUpdatedAt": "2026-05-12T00:00:00Z"
    }
  }
}
```

---

## Get customer events (activity log)

```python
query = """
query customerEvents($id: ID!) {
  customer(id: $id) {
    displayName
    events(first: 20, sortKey: OCCURRED_AT, reverse: true) {
      nodes {
        id
        message
        occurredAt
        attributeToApp
        attributeToUser
      }
    }
  }
}
"""
```

---

## Safety notes

- NEVER expose payment method details (`read_customer_payment_methods` scope exists but should not be used for chat).
- Marketing consent changes have legal implications (GDPR). Always get explicit confirmation from the client before changing a customer's consent state.
- When updating tags with `customerUpdate`, the `tags` field REPLACES all existing tags. Use `tagsAdd`/`tagsRemove` to make non-destructive changes.
- Customer email/phone is PII — never log it in memory files or repeat it in chat beyond what's necessary.
- `customerDelete` is NOT available in this agent — accounts are never deleted, only tagged or noted.
