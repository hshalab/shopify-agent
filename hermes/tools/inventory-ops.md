# Inventory Operations — Shopify Admin API 2026-01

Scopes required: `read_inventory`, `write_inventory`, `read_inventory_transfers`, `write_inventory_transfers`, `write_inventory_shipments`, `read_inventory_shipments`, `read_locations`

Covers: inventory adjustments, moves between locations, transfers, and location management.

## Confirmation rules

- Adjustment: show product, variant, location, current qty → new qty. Ask confirmation.
- Move: show product, source location, destination, quantity. Ask confirmation.
- Batch (4+): summary table then one confirmation.

---

## List locations

```python
query = """
{
  locations(first: 10, includeLegacy: false) {
    nodes {
      id
      name
      isActive
      fulfillsOnlineOrders
      address { address1 city countryCode }
    }
  }
}
"""
```

---

## Get inventory levels for a product variant

```python
query = """
query inventoryLevels($variantId: ID!) {
  productVariant(id: $variantId) {
    id
    displayName
    inventoryItem {
      id
      inventoryLevels(first: 10) {
        nodes {
          id
          quantities(names: ["available", "on_hand", "committed", "incoming"]) {
            name
            quantity
          }
          location { id name }
        }
      }
    }
  }
}
"""
```

---

## Adjust inventory quantity at a location

Use for manual corrections (e.g., physical count differs from system).

```python
mutation = """
mutation inventoryAdjust($input: InventoryAdjustQuantitiesInput!) {
  inventoryAdjustQuantities(input: $input) {
    inventoryAdjustmentGroup {
      id
      reason
      changes {
        name
        delta
        quantityAfterChange
        item { id }
        location { id name }
      }
    }
    userErrors { field message }
  }
}
"""

variables = {
  "input": {
    "reason": "correction",  # correction | received | cycle_count_available | damaged | shrinkage | reservation_created | reservation_deleted | reservation_updated | restock | unknown
    "name": "available",
    "changes": [
      {
        "inventoryItemId": "gid://shopify/InventoryItem/XXXXXXX",
        "locationId": "gid://shopify/Location/XXXXXXX",
        "delta": 10  # positive = add, negative = subtract
      }
    ]
  }
}
```

### Get inventoryItemId from a variant

```python
query = """
query getInventoryItem($variantId: ID!) {
  productVariant(id: $variantId) {
    inventoryItem { id }
  }
}
"""
```

---

## Move inventory between locations

Use when stock needs to be transferred from one location to another (same company).

```python
mutation = """
mutation inventoryMove($input: InventoryMoveQuantitiesInput!) {
  inventoryMoveQuantities(input: $input) {
    inventoryAdjustmentGroup {
      id
      changes {
        name
        delta
        quantityAfterChange
        location { name }
      }
    }
    userErrors { field message }
  }
}
"""

variables = {
  "input": {
    "reason": "movement",
    "changes": [
      {
        "inventoryItemId": "gid://shopify/InventoryItem/XXXXXXX",
        "from": {
          "locationId": "gid://shopify/Location/SOURCE_ID",
          "name": "available",
          "quantity": 5
        },
        "to": {
          "locationId": "gid://shopify/Location/DEST_ID",
          "name": "available",
          "quantity": 5
        }
      }
    ]
  }
}
```

---

## Create inventory transfer (formal transfer between locations)

Use for documented stock movements that need a paper trail.

```python
mutation = """
mutation inventoryTransferCreate($inventoryTransfer: InventoryTransferCreateInput!) {
  inventoryTransferCreate(inventoryTransfer: $inventoryTransfer) {
    inventoryTransfer {
      id
      status
      originLocation { name }
      destinationLocation { name }
      lineItems(first: 20) {
        nodes {
          inventoryItem { id }
          quantity
        }
      }
    }
    userErrors { field message }
  }
}
"""

variables = {
  "inventoryTransfer": {
    "originLocationId": "gid://shopify/Location/SOURCE_ID",
    "destinationLocationId": "gid://shopify/Location/DEST_ID",
    "expectedArrivalDate": "2026-05-20",
    "lineItems": [
      {
        "inventoryItemId": "gid://shopify/InventoryItem/XXXXXXX",
        "quantity": 10
      }
    ]
  }
}
```

---

## Safety notes

- `inventoryAdjustQuantities` with `delta: -5` subtracts 5 units. Verify current quantity first to avoid going negative.
- `inventoryMoveQuantities` does source-deduct + dest-add atomically — no risk of double-counting.
- For bulk adjustments (many products at once), include all changes in a single `inventoryAdjustQuantities` call — they're applied atomically.
- Always show the before/after quantity in the confirmation message, not just the delta.
- `reason` field affects reports and analytics — use `correction` for manual fixes, `received` for new stock.
