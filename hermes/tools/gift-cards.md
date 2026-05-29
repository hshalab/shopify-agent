# Gift Cards — Shopify Admin API 2026-01

Scopes required: `read_gift_cards`, `write_gift_cards`, `write_gift_card_transactions`

## Confirmation rules

- Create: show amount, expiry date, recipient. Ask: "Create this gift card?"
- Disable: show code (masked) and balance. Ask: "Disable this gift card? The remaining balance will be lost."
- Transactions: owner-only — never execute a manual transaction without ${OWNER_NAME} approving via `!admin`.

---

## List gift cards

```python
query = """
{
  giftCards(first: 20, sortKey: CREATED_AT, reverse: true) {
    nodes {
      id
      maskedCode
      balance { amount currencyCode }
      initialValue { amount currencyCode }
      createdAt
      expiresOn
      enabled
      customer { email displayName }
      note
    }
  }
}
"""
```

---

## Get single gift card

```python
query = """
query getGiftCard($id: ID!) {
  giftCard(id: $id) {
    id
    maskedCode
    balance { amount currencyCode }
    initialValue { amount currencyCode }
    createdAt
    expiresOn
    enabled
    lastCharacters
    transactions(first: 10) {
      nodes {
        id
        amount { amount currencyCode }
        createdAt
        processedAt
      }
    }
  }
}
"""
```

---

## Create gift card

```python
mutation = """
mutation giftCardCreate($input: GiftCardCreateInput!) {
  giftCardCreate(input: $input) {
    giftCard {
      id
      maskedCode
      initialValue { amount currencyCode }
      balance { amount currencyCode }
      expiresOn
    }
    giftCardCode  # full code — only available at creation time, show to client
    userErrors { field message }
  }
}
"""

variables = {
  "input": {
    "initialValue": "50.00",  # amount in store currency
    "expiresOn": "2026-12-31",  # YYYY-MM-DD, null = no expiry
    "note": "Sent to customer: Jane Smith",
    # Optional: link to a customer
    # "customerId": "gid://shopify/Customer/XXXXXXX"
  }
}
```

> **IMPORTANT:** `giftCardCode` (the full unmasked code) is only returned at creation time. 
> Show it to the client or note it down — it cannot be retrieved again from the API.

---

## Disable gift card

```python
mutation = """
mutation giftCardDisable($id: ID!) {
  giftCardDisable(id: $id) {
    giftCard {
      id
      enabled
      maskedCode
      balance { amount currencyCode }
    }
    userErrors { field message }
  }
}
"""
```

Disabled gift cards cannot be re-enabled. Always confirm before disabling.

---

## Update gift card (note, expiry, customer link)

```python
mutation = """
mutation giftCardUpdate($id: ID!, $input: GiftCardUpdateInput!) {
  giftCardUpdate(id: $id, input: $input) {
    giftCard { id maskedCode expiresOn note }
    userErrors { field message }
  }
}
"""

variables = {
  "id": "gid://shopify/GiftCard/XXXXXXX",
  "input": {
    "note": "Renewed for customer Jane Smith",
    "expiresOn": "2027-06-30"
    # "customerId": "gid://shopify/Customer/XXXXXXX"
  }
}
```

---

## Safety notes

- The full gift card code appears **only once** at `giftCardCreate` in the `giftCardCode` field. After that, only the masked code is available.
- Disabled gift cards are permanent — cannot be re-enabled via API or admin.
- Gift card transactions (manual credits/debits) are owner-only operations (require ${OWNER_NAME} approval).
- Never expose the full code in a chat message to an unverified recipient.
