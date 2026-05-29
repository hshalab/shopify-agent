# Mutations (Write Operations)

All mutations verified against Shopify Admin API `2026-01`.

## Publishing to Online Store (MANDATORY after any create)

The Online Store publication (`${ONLINE_STORE_PUBLICATION_ID}`) has `autoPublish: false`. New products and collections are NOT visible in the storefront until explicitly published. **After every `productCreate` / `collectionCreate` you MUST run `publishablePublish` against the Online Store publication id.** This is non-negotiable — skipping it ships the item in "unavailable" state and the client cannot see it.

```graphql
mutation publishablePublish($id: ID!, $input: [PublicationInput!]!) {
  publishablePublish(id: $id, input: $input) {
    publishable { availablePublicationsCount { count } }
    userErrors { field message }
  }
}
```

Variables (reuse for products AND collections — pass the created `id`):
```json
{
  "id": "gid://shopify/Product/PRODUCT_ID",
  "input": [{ "publicationId": "${ONLINE_STORE_PUBLICATION_ID}" }]
}
```

## Create Product

Always create as DRAFT first, then immediately publish to Online Store so it is live the moment the owner flips status to ACTIVE.

```graphql
mutation productCreate($product: ProductCreateInput!) {
  productCreate(product: $product) {
    product {
      id
      title
      handle
      status
    }
    userErrors { field message }
  }
}
```

Variables:
```json
{
  "product": {
    "title": "Product Name",
    "descriptionHtml": "<p>Description</p>",
    "status": "DRAFT",
    "tags": ["tag1", "tag2"]
  }
}
```

> **API 2026-01 change:** Argument changed from `input: ProductInput!` to `product: ProductCreateInput!`. Variable name must be `product`, not `input`.

**Immediately after creating, run `publishablePublish`** with the returned product id and the Online Store publication id. Only confirm to the user once both calls succeed — otherwise say "created but not published" and retry.

## Update Product (title, description, status, tags)

```graphql
mutation productUpdate($product: ProductUpdateInput!) {
  productUpdate(product: $product) {
    product { id title status }
    userErrors { field message }
  }
}
```

Variables:
```json
{
  "product": {
    "id": "gid://shopify/Product/PRODUCT_ID",
    "title": "New Title",
    "status": "ACTIVE",
    "seo": {
      "title": "SEO Title — max 70 chars",
      "description": "SEO meta description — max 160 chars"
    },
    "descriptionHtml": "<p>Product description with HTML</p>"
  }
}
```

> **API 2026-01 change:** Argument changed from `input: ProductInput!` to `product: ProductUpdateInput!`. Variable name must be `product`, not `input`.

The `seo` field updates the product's Google/search engine metadata. When the user asks to improve SEO, update `seo.title` and `seo.description`. Only include fields you want to change — omitted fields keep their current values.

Status values: `ACTIVE`, `DRAFT`, `ARCHIVED`

## Update Variant Price

Use `productVariantsBulkUpdate` (NOT `productVariantUpdate` which doesn't exist in 2026-01).

```graphql
mutation productVariantsBulkUpdate($productId: ID!, $variants: [ProductVariantsBulkInput!]!) {
  productVariantsBulkUpdate(productId: $productId, variants: $variants) {
    productVariants { id price }
    userErrors { field message }
  }
}
```

Variables:
```json
{
  "productId": "gid://shopify/Product/PRODUCT_ID",
  "variants": [
    {
      "id": "gid://shopify/ProductVariant/VARIANT_ID",
      "price": "19.99"
    }
  ]
}
```

## Create Collection

```graphql
mutation collectionCreate($input: CollectionInput!) {
  collectionCreate(input: $input) {
    collection { id title handle }
    userErrors { field message }
  }
}
```

Variables:
```json
{
  "input": {
    "title": "Collection Name",
    "descriptionHtml": "<p>Description</p>"
  }
}
```

**Immediately after creating, run `publishablePublish`** with the returned collection id and the Online Store publication id (`${ONLINE_STORE_PUBLICATION_ID}`). A collection that is not published to Online Store does not appear in the storefront, even if it has products assigned.

## Add Products to Collection

```graphql
mutation collectionAddProducts($id: ID!, $productIds: [ID!]!) {
  collectionAddProducts(id: $id, productIds: $productIds) {
    collection { id title productsCount { count } }
    userErrors { field message }
  }
}
```

Variables:
```json
{
  "id": "gid://shopify/Collection/COLLECTION_ID",
  "productIds": ["gid://shopify/Product/PRODUCT_ID"]
}
```

## Remove Products from Collection

```graphql
mutation collectionRemoveProducts($id: ID!, $productIds: [ID!]!) {
  collectionRemoveProducts(id: $id, productIds: $productIds) {
    userErrors { field message }
  }
}
```

## Delete Collection

```graphql
mutation collectionDelete($input: CollectionDeleteInput!) {
  collectionDelete(input: $input) {
    deletedCollectionId
    userErrors { field message }
  }
}
```

Variables:
```json
{
  "input": { "id": "gid://shopify/Collection/COLLECTION_ID" }
}
```

## Upload Image to Product (3-step pipeline)

**Step 1 — `stagedUploadsCreate`** to get a signed upload URL:

```graphql
mutation stagedUploadsCreate($input: [StagedUploadInput!]!) {
  stagedUploadsCreate(input: $input) {
    stagedTargets { url resourceUrl parameters { name value } }
    userErrors { field message }
  }
}
```

Variables: `{ "input": [{ "resource": "PRODUCT_IMAGE", "filename": "photo.jpg", "mimeType": "image/jpeg", "httpMethod": "POST" }] }`. Keep the returned `url`, `resourceUrl`, `parameters`.

**Step 2 — POST the file** using the helper (returns `{"ok": true, "status": 200}`):
```
python3 /opt/data/scripts/shopify-upload.py <file_path> <staged_url> '<parameters_json>'
```
`file_path` is typically a Telegram inbound file saved by Hermes or a local file under `/tmp`.

If the user provides an external MiniMax/Aliyun image URL instead of a Telegram file, download it first:
```
python3 /opt/data/scripts/download-external-image.py '<image_url>' /tmp/inbound-image.jpg
```
Then use `/tmp/inbound-image.jpg` as the `file_path` for `shopify-upload.py`.

**Step 3 — `productCreateMedia`** (still preferred over `productSet`, which wipes existing media):

```graphql
mutation productCreateMedia($productId: ID!, $media: [CreateMediaInput!]!) {
  productCreateMedia(productId: $productId, media: $media) {
    media {
      ... on MediaImage { id status image { url altText } }
    }
    mediaUserErrors { field message code }
  }
}
```

Variables (use `resourceUrl` from Step 1):
```json
{
  "productId": "gid://shopify/Product/PRODUCT_ID",
  "media": [{
    "originalSource": "RESOURCE_URL_FROM_STEP_1",
    "alt": "Product description",
    "mediaContentType": "IMAGE"
  }]
}
```

## Delete Product Image

**Step 1: List product media to get media IDs** — use the Product Details query in `tools/queries.md` which returns `media.edges.node.id` for each image. Show the user a numbered list with thumbnail URLs so they can pick which image(s) to delete.

**Step 2: Delete selected media**

```graphql
mutation productDeleteMedia($productId: ID!, $mediaIds: [ID!]!) {
  productDeleteMedia(productId: $productId, mediaIds: $mediaIds) {
    deletedMediaIds
    deletedProductImageIds
    mediaUserErrors { field message code }
  }
}
```

Variables:
```json
{
  "productId": "gid://shopify/Product/PRODUCT_ID",
  "mediaIds": ["gid://shopify/MediaImage/MEDIA_ID"]
}
```

> **Rules:** always list images and confirm the selection before calling. `mediaIds` accepts multiple. The delete is irreversible.

---

> **Deployment note:** `${ONLINE_STORE_PUBLICATION_ID}` is set via env `ONLINE_STORE_PUBLICATION_ID`.
