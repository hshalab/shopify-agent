# Shipping Zones & Rates — Shopify Admin API 2026-01

Scopes required: `read_shipping`, `write_shipping`

> **Policy: owner-only.**  
> Shipping configuration directly affects all future orders and checkout behavior. Changes require explicit ${OWNER_NAME} approval (`!admin` command). Never modify shipping as a response to a normal customer chat message.

## Confirmation rules

- ALL write operations: owner-only via `!admin shipping <action>`.
- Read operations: autonomous (queries only, no data exposed to the customer unless asked).
- Before any write: show current state → proposed change. Ask: "Confirm this shipping change?"
- After any write: verify by re-querying the affected profile.

---

## List delivery profiles

```python
query = """
{
  deliveryProfiles(first: 10) {
    nodes {
      id
      name
      default
      profileLocationGroups {
        locationGroup {
          id
          locations(first: 5) { nodes { name } }
        }
        locationGroupZones(first: 20) {
          nodes {
            zone {
              id
              name
              countries {
                code { countryCode }
                name
              }
            }
            methodDefinitions(first: 10) {
              nodes {
                id
                name
                active
                methodConditions {
                  field
                  operator
                  conditionCriteria {
                    ... on MoneyV2 { amount currencyCode }
                    ... on Weight { value unit }
                  }
                }
                rateProvider {
                  ... on DeliveryRateDefinition {
                    price { amount currencyCode }
                  }
                  ... on DeliveryParticipant {
                    participantService { name }
                    fixedFee { amount currencyCode }
                  }
                }
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

## Add a flat rate to an existing zone

```python
mutation = """
mutation deliveryProfileUpdate($id: ID!, $profile: DeliveryProfileInput!) {
  deliveryProfileUpdate(id: $id, profile: $profile) {
    profile {
      id
      name
    }
    userErrors { field message }
  }
}
"""

# Adding a flat rate requires knowing the zone ID from the query above.
# The full profile input replaces existing configuration — fetch and rebuild before updating.
# Structure example (simplified):
variables = {
  "id": "gid://shopify/DeliveryProfile/XXXXXXX",
  "profile": {
    "locationGroupsToUpdate": [
      {
        "id": "gid://shopify/DeliveryLocationGroup/XXXXXXX",
        "zonesToUpdate": [
          {
            "id": "gid://shopify/DeliveryZone/XXXXXXX",
            "methodDefinitionsToCreate": [
              {
                "name": "Standard shipping",
                "active": True,
                "rateDefinition": {
                  "price": { "amount": "3.99", "currencyCode": "USD" }
                }
                # Optional weight/price conditions:
                # "conditions": {
                #   "toCreate": [
                #     { "field": "TOTAL_WEIGHT", "operator": "LESS_THAN_OR_EQUAL_TO", "criteria": { "value": 5.0, "unit": "KILOGRAMS" } }
                #   ]
                # }
              }
            ]
          }
        ]
      }
    ]
  }
}
```

---

## Free shipping above a threshold (condition-based rate)

To add "free shipping over 50.00", create a rate with `price: 0.00` and a condition:

```python
# Inside methodDefinitionsToCreate:
{
  "name": "Free shipping over 50",
  "active": True,
  "rateDefinition": {
    "price": { "amount": "0.00", "currencyCode": "USD" }
  },
  "conditions": {
    "toCreate": [
      {
        "field": "TOTAL_PRICE",
        "operator": "GREATER_THAN_OR_EQUAL_TO",
        "criteria": { "amount": "50.00", "currencyCode": "USD" }
      }
    ]
  }
}
```

---

## Get shipping zones (simpler read-only overview)

```python
query = """
{
  shop {
    shippingZones: deliveryProfiles(first: 3) {
      nodes {
        name
        profileLocationGroups {
          locationGroupZones(first: 10) {
            nodes {
              zone { name countries { name code { countryCode } } }
              methodDefinitions(first: 10) {
                nodes {
                  name
                  active
                  rateProvider {
                    ... on DeliveryRateDefinition { price { amount currencyCode } }
                  }
                }
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

## Safety notes

- `deliveryProfileUpdate` with `profile.locationGroupsToUpdate` merges changes into the existing profile — but `zonesToUpdate` replaces the zone's method definitions. Fetch the current state first.
- Changes to shipping rates take effect immediately for new checkout sessions.
- Removing a rate that existing customers have in their carts will not affect those carts — only new sessions.
- Always test with a dummy order on the dev store before changing production shipping rates.
- Free shipping thresholds are a common discount trigger — coordinate with `discounts.md` to avoid double-discounting.
