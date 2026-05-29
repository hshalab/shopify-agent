# Blog Articles (Content Marketing / SEO)

Blog ID: `${BLOG_ID}` (handle: `news`)

## List Articles

```graphql
{
  blog(id: "${BLOG_ID}") {
    articles(first: 20, sortKey: PUBLISHED_AT, reverse: true) {
      edges {
        node {
          id
          title
          handle
          publishedAt
          tags
          body
        }
      }
    }
  }
}
```

## Create Article (publish immediately)

```graphql
mutation articleCreate($article: ArticleCreateInput!) {
  articleCreate(article: $article) {
    article {
      id
      title
      handle
      publishedAt
    }
    userErrors { field message }
  }
}
```

Variables:
```json
{
  "article": {
    "blogId": "${BLOG_ID}",
    "title": "Article Title — Sentence Case, No ALL CAPS",
    "author": { "name": "${STORE_NAME}" },
    "body": "<h2>Subtitle</h2><p>Content with proper HTML structure...</p>",
    "tags": ["category-one", "category-two"],
    "isPublished": true
  }
}
```

## Update Article

```graphql
mutation articleUpdate($id: ID!, $article: ArticleUpdateInput!) {
  articleUpdate(id: $id, article: $article) {
    article { id title }
    userErrors { field message }
  }
}
```

Variables:
```json
{
  "id": "gid://shopify/Article/ARTICLE_ID",
  "article": {
    "title": "New Title",
    "body": "<p>Updated content</p>",
    "tags": ["tag1", "tag2"]
  }
}
```

## Delete Article

```graphql
mutation articleDelete($id: ID!) {
  articleDelete(id: $id) {
    deletedArticleId
    userErrors { field message }
  }
}
```

## SEO Blog Content Rules (cron-blog)

- **Title:** sentence case, ≤70 chars, with a long-tail keyword relevant to the store's product categories.
- **Body:** 600-1000 words in `<h2>`, `<h3>`, `<p>`, `<ul>`. Relative internal links to `/collections/handle` or `/products/handle`.
- **Tags:** 2-4 matching store categories. **Author:** always the configured store name (`${STORE_NAME}`).
- **Tone:** educational and helpful, never salesy. Write in the store's configured language, defaulting to English.
- **Never** disclose AI authorship. Avoid unsupported claims — prefer cautious, well-qualified statements.

---

> **Deployment note:** `${BLOG_ID}` is set via env `BLOG_ID`.
> **Deployment note:** `${STORE_NAME}` is set via config/env.
