# Competitor Price Comparison

<!-- pharmacy-overlay: copy to hermes/tools/ when applying the farmacia example. -->

Use `web_fetch` to pull product pages from competitor pharmacies. URL-encode product names (spaces → `+`).

Configure the competitor list for your market. Examples (illustrative — replace with the competitors relevant to your store):

- `www.example-competitor-a.com/search?q=PRODUCT_NAME`
- `www.example-competitor-b.com/catalogsearch/result/?q=PRODUCT_NAME` (may hit a captcha)
- `www.example-competitor-c.com/?s=PRODUCT_NAME&post_type=product` (WooCommerce-style, may need category browsing)

Flow: get the product name from Shopify → `web_fetch` each search URL → extract the price → present a table `product | our price | competitor | price | diff`.

## Rules
- Read-only (no forms, no accounts, no reviews/customer data).
- 2-3s between requests to the same domain.
- Max 2 URL attempts per competitor. If both fail, skip and note it.
