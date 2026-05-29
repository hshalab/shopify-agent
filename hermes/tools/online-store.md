# Online Store Pages & Navigation — Shopify Admin API 2026-01

Scopes required: `read_online_store_pages`, `write_online_store_pages`, `read_online_store_navigation`, `write_online_store_navigation`

> NOTE: `pageUpdate` here refers to actual **online store pages** (static content pages like "About us", "Legal notice", etc.) — NOT to metaobject-backed content, which uses `metaobjectUpdate`.

## Confirmation rules

- Create page: show title and content preview. Ask: "Create this page?"
- Update page: show what fields change (title, body, SEO). Ask: "Update this page?"
- Delete page: show title + current URL. Ask: "Delete this page? This action is permanent."
- Navigation: show menu name + exact change (item added/removed/reordered). Ask: "Update the menu?"

---

## List online store pages

```python
query = """
{
  onlineStorePage: pages(first: 30, sortKey: TITLE) {
    nodes {
      id
      title
      handle
      publishedAt
      bodySummary
      seo { title description }
      createdAt
      updatedAt
    }
  }
}
"""
```

---

## Get page content

```python
query = """
query getPage($id: ID!) {
  page(id: $id) {
    id
    title
    handle
    bodyHtml
    publishedAt
    seo { title description }
    templateSuffix
  }
}
"""
```

---

## Create page

```python
mutation = """
mutation pageCreate($page: PageCreateInput!) {
  pageCreate(page: $page) {
    page {
      id
      title
      handle
      publishedAt
    }
    userErrors { field message }
  }
}
"""

variables = {
  "page": {
    "title": "Return Policy",
    "bodyHtml": "<h1>Return Policy</h1><p>Policy text...</p>",
    "handle": "return-policy",  # URL slug — auto-generated from title if omitted
    "isPublished": True,
    "seo": {
      "title": "Return Policy | ${STORE_NAME}",
      "description": "Read our return and exchange policy."
    }
  }
}
```

---

## Update page

```python
mutation = """
mutation pageUpdate($id: ID!, $page: PageUpdateInput!) {
  pageUpdate(id: $id, page: $page) {
    page {
      id
      title
      handle
      publishedAt
      updatedAt
    }
    userErrors { field message }
  }
}
"""

variables = {
  "id": "gid://shopify/Page/XXXXXXX",
  "page": {
    # Only include fields to change:
    "bodyHtml": "<h1>Updated title</h1><p>New content...</p>",
    "seo": {
      "title": "New SEO title",
      "description": "New meta description"
    }
    # "isPublished": False  # to unpublish
  }
}
```

---

## Delete page

```python
mutation = """
mutation pageDelete($id: ID!) {
  pageDelete(id: $id) {
    deletedPageId
    userErrors { field message }
  }
}
"""
```

Always confirm twice for deletions — they are permanent.

---

## List navigation menus

```python
query = """
{
  menus(first: 10) {
    nodes {
      id
      title
      handle
      items {
        id
        title
        url
        type
        items {
          id
          title
          url
          type
        }
      }
    }
  }
}
"""
```

Common menu handles: `main-menu`, `footer-menu`.

---

## Update navigation menu (add, reorder, or remove items)

```python
mutation = """
mutation menuUpdate($id: ID!, $items: [MenuItemUpdateInput!]!) {
  menuUpdate(id: $id, menu: { items: $items }) {
    menu {
      id
      title
      items {
        id
        title
        url
      }
    }
    userErrors { field message }
  }
}
"""

variables = {
  "id": "gid://shopify/Menu/XXXXXXX",
  "items": [
    # Full list of items in desired order — replaces existing items
    { "title": "Home", "url": "/" },
    { "title": "Products", "url": "/collections/all" },
    { "title": "Blog", "url": "/blogs/news" },
    { "title": "About", "url": "/pages/about" },
    { "title": "Contact", "url": "/pages/contact" }
  ]
}
```

> The `items` array **replaces the full menu** — always fetch the current menu first, then modify the list.

---

## Safety notes

- Always fetch the current menu before updating — `menuUpdate` replaces the entire item list.
- Page `handle` determines the URL (e.g., `return-policy` → `/pages/return-policy`). Changing the handle breaks existing links.
- Unpublished pages are hidden from the storefront but still accessible via direct URL. Use `isPublished: false` for drafts.
- Deleted pages return 404 — check if any menu items or other pages link to the page before deleting.

> Deployment note: `${STORE_NAME}` is set via config/env.
