# Markets, Locales & Currencies — Shopify Admin API 2026-01

Scopes required: `read_markets`, `write_markets`, `read_locales`, `write_locales`

## Confirmation rules

- Create market: show name, countries, currency, language. Ask: "Create this market?"
- Update market: show what changes. Ask: "Update the market configuration?"
- Enable locale: show language code + what it enables. Ask: "Enable language [X] on the store?"
- Disable locale: show affected market. Ask: "Disable language [X]? Customers in that market will see the default language."

---

## List markets

```python
query = """
{
  markets(first: 10) {
    nodes {
      id
      name
      handle
      enabled
      primary
      regions(first: 20) {
        nodes {
          ... on MarketRegionCountry {
            code
            name
            currency { isoCode }
          }
        }
      }
      webPresences(first: 5) {
        nodes {
          alternateLocales
          defaultLocale
          subfolderSuffix
          domain { host }
        }
      }
    }
  }
}
"""
```

---

## Get primary market

```python
query = """
{
  marketByGeography: markets(first: 1, query: "primary:true") {
    nodes {
      id
      name
      primary
      enabled
      regions(first: 20) { nodes { ... on MarketRegionCountry { code name } } }
    }
  }
}
"""
```

---

## Create a new market

```python
mutation = """
mutation marketCreate($input: MarketCreateInput!) {
  marketCreate(input: $input) {
    market {
      id
      name
      enabled
      regions(first: 10) { nodes { ... on MarketRegionCountry { code name } } }
    }
    userErrors { field message }
  }
}
"""

variables = {
  "input": {
    "name": "Canada",
    "regions": [
      { "countryCode": "CA" }
    ],
    "enabled": True
  }
}
```

---

## Update a market (enable/disable, rename, add regions)

```python
mutation = """
mutation marketUpdate($id: ID!, $input: MarketUpdateInput!) {
  marketUpdate(id: $id, input: $input) {
    market {
      id
      name
      enabled
      regions(first: 10) { nodes { ... on MarketRegionCountry { code name } } }
    }
    userErrors { field message }
  }
}
"""

variables = {
  "id": "gid://shopify/Market/XXXXXXX",
  "input": {
    "enabled": True,
    "name": "Canada & Mexico Market"
    # To add regions, use marketRegionsCreate mutation (see below)
  }
}
```

---

## Add countries to an existing market

```python
mutation = """
mutation marketRegionsCreate($marketId: ID!, $regions: [MarketRegionCreateInput!]!) {
  marketRegionsCreate(marketId: $marketId, regions: $regions) {
    market {
      id
      name
      regions(first: 20) { nodes { ... on MarketRegionCountry { code name } } }
    }
    userErrors { field message }
  }
}
"""

variables = {
  "marketId": "gid://shopify/Market/XXXXXXX",
  "regions": [
    { "countryCode": "MX" }  # Mexico
  ]
}
```

---

## List available locales in the store

```python
query = """
{
  shopLocales {
    locale
    name
    primary
    published
  }
}
"""
```

---

## Enable a new locale

```python
mutation = """
mutation shopLocaleEnable($locale: String!) {
  shopLocaleEnable(locale: $locale) {
    shopLocale { locale name published }
    userErrors { field message }
  }
}
"""

variables = { "locale": "en" }  # ISO language code: "en", "fr", "pt", "ca", "de", etc.
```

---

## Update locale (publish/unpublish)

```python
mutation = """
mutation shopLocaleUpdate($locale: String!, $shopLocale: ShopLocaleInput!) {
  shopLocaleUpdate(locale: $locale, shopLocale: $shopLocale) {
    shopLocale { locale name published }
    userErrors { field message }
  }
}
"""

variables = {
  "locale": "en",
  "shopLocale": { "published": True }
}
```

---

## Disable a locale

```python
mutation = """
mutation shopLocaleDisable($locale: String!) {
  shopLocaleDisable(locale: $locale) {
    locale
    userErrors { field message }
  }
}
"""

variables = { "locale": "fr" }
```

---

## Currency settings for a market

Markets use the currency of their primary country by default. To override:

```python
mutation = """
mutation marketCurrencySettingsUpdate($marketId: ID!, $settings: MarketCurrencySettingsUpdateInput!) {
  marketCurrencySettingsUpdate(marketId: $marketId, settings: $settings) {
    market {
      id
      name
    }
    userErrors { field message }
  }
}
"""

variables = {
  "marketId": "gid://shopify/Market/XXXXXXX",
  "settings": {
    "baseCurrency": { "currencyCode": "CAD" }
  }
}
```

---

## Safety notes

- The primary market cannot be deleted or disabled — it's the fallback for all customers.
- Disabling a locale removes it from the storefront for all customers in that language. Translations for that locale are preserved.
- Enabling a locale without having translations means customers will see the default language (usually Spanish). Use with `translations.md` to add content.
- `marketRegionsCreate` is additive — it doesn't remove existing regions. Use `marketRegionsDelete` to remove.
- Currency changes in a market affect prices shown to customers in that market — review pricing strategy before enabling a new currency.
