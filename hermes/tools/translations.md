# Translations — Shopify Admin API 2026-01

Scopes required: `read_translations`, `write_translations`, `read_locales`, `read_products`, `read_content`

Use these operations to translate product titles, descriptions, collection names, pages, blog articles, and other storefront content into other languages.

## Confirmation rules

- Read (list untranslated): autonomous.
- Translate single resource: show resource title + target language. Ask: "Translate [X] into [language]?"
- Batch translate: show count + resource type + language. Ask: "Translate these 20 products into [language]?"
- Remove translations: show what will be removed. Ask: "Remove the translations for [X]?"

---

## List translatable resource types

Resources that can be translated: `PRODUCT`, `PRODUCT_VARIANT`, `PRODUCT_OPTION`, `PRODUCT_OPTION_VALUE`, `COLLECTION`, `BLOG`, `ARTICLE`, `PAGE`, `METAOBJECT`, `SHOP`, `SHOP_POLICY`, `EMAIL_TEMPLATE`

---

## Get translatable fields for a product

```python
query = """
query translatableProduct($id: ID!) {
  translatableResource(resourceId: $id) {
    resourceId
    translatableContent {
      key
      value
      digest
      locale
    }
    translations(locale: "en") {
      key
      value
      outdated
      updatedAt
    }
  }
}
"""
```

The `digest` is required when registering a translation — it links the translation to the source content.

---

## List products with missing translations

```python
query = """
query untranslatedProducts($locale: String!) {
  translatableResourcesByType(resourceType: PRODUCT, first: 20) {
    nodes {
      resourceId
      translatableContent { key value digest locale }
      translations(locale: $locale) { key value }
    }
  }
}
"""
variables = { "locale": "en" }
```

Filter out resources where `translations` is empty or missing keys vs. `translatableContent`.

---

## Register translations for a resource

```python
mutation = """
mutation translationsRegister($resourceId: ID!, $translations: [TranslationInput!]!) {
  translationsRegister(resourceId: $resourceId, translations: $translations) {
    translations {
      key
      value
      locale
      outdated
    }
    userErrors { field message }
  }
}
"""

variables = {
  "resourceId": "gid://shopify/Product/XXXXXXX",
  "translations": [
    {
      "locale": "en",
      "key": "title",
      "value": "Moisturizing Cream SPF 50",
      "translatableContentDigest": "abc123..."  # digest from translatableContent query above
    },
    {
      "locale": "en",
      "key": "body_html",
      "value": "<p>Moisturizing cream with SPF 50 protection...</p>",
      "translatableContentDigest": "def456..."
    }
  ]
}
```

### Common translation keys by resource type

| Resource | Keys |
|---|---|
| `PRODUCT` | `title`, `body_html`, `handle` |
| `PRODUCT_VARIANT` | `title`, `option1`, `option2` |
| `COLLECTION` | `title`, `body_html`, `handle` |
| `ARTICLE` | `title`, `body_html`, `summary_html`, `handle` |
| `PAGE` | `title`, `body_html`, `handle` |
| `BLOG` | `title`, `handle` |

---

## Batch translate multiple resources (loop pattern)

```python
# Get all product IDs first, then loop:
query_all = """
query productIds($cursor: String) {
  products(first: 50, after: $cursor) {
    nodes {
      id
      title
    }
    pageInfo { hasNextPage endCursor }
  }
}
"""

# For each product: get digest → register translation
# Rate limit: pause 200ms between translationsRegister calls for large batches
```

---

## Remove translations

```python
mutation = """
mutation translationsRemove($resourceId: ID!, $translationKeys: [String!]!, $locales: [String!]!) {
  translationsRemove(resourceId: $resourceId, translationKeys: $translationKeys, locales: $locales) {
    translations {
      key
      locale
    }
    userErrors { field message }
  }
}
"""

variables = {
  "resourceId": "gid://shopify/Product/XXXXXXX",
  "translationKeys": ["title", "body_html"],
  "locales": ["en"]
}
```

---

## Check locale availability

Before translating, verify the target locale is enabled in the store:

```python
query = """
{ shopLocales { locale name published } }
"""
# If locale is not present, enable it first via markets.md § "Enable a new locale"
```

---

## Safety notes

- The `translatableContentDigest` is required and must match the current source content. If the source changes, the digest changes and the translation is marked `outdated: true`.
- Outdated translations still display until updated — they don't revert to the source language.
- `handle` translations affect the URL in that locale (e.g., `/en/products/moisturizing-cream`). Changing a translated handle breaks bookmarks/links in that language.
- Translations are live immediately — no publish step required.
- For large catalogs (500+ products), batch into groups of 50 and pause between batches to avoid throttle.
