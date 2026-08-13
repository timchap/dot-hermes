# Web Extraction Fallback — Detailed Reference

## The Problem

`web_extract` on Shopify-based storefronts triggers `ERR_BLOCKED_BY_CLIENT`.
The extraction agent's request headers trigger Shopify's shop.app extension
block before content is returned.

## Confirmed Affected Domains (as of 2026-08)

- `merzbschwanen.com` (Shopify)
- `redcastheritage.com` (Shopify)
- `witheredfig.com` (Shopify)
- `oldhouseprovisions.com` (Shopify)

Any `*.myshopify.com` storefront is a candidate.

## Fallback Pipeline (detailed)

### Step 1: Parallel web_search

Run 3-5 parallel `web_search` calls with targeted queries:

```
site:merzbschwanen.com t-shirt collection pricing
site:redcastheritage.com shipping France
"Merz b. Schwanen" sale discount 2026
site:witheredfig.com shipping international policies
site:oldhouseprovisions.com shipping international
```

Use date-stamped queries (`2026`) to filter stale results.

### Step 2: Extract Policy Pages

Policy pages load fine with `web_extract` — they're rarely Shopify-blocked:

```
https://DOMAIN/policies/shipping-policy
https://DOMAIN/pages/shipping
https://DOMAIN/pages/returns
https://DOMAIN/pages/faqs
```

### Step 3: browser_navigate for Product Pages

For product pages with size selectors and stock indicators:

```
browser_navigate("https://DOMAIN/products/PRODUCT-SLUG")
browser_snapshot()          # See interactive elements (@refs)
browser_vision(annotate=true)  # Visual confirmation of stock/status
```

### Step 4: Pagination

Many Shopify stores paginate product lists. For `witheredfig.com`,
the Merz collection spans pages 1-10. Always check additional pages
when a collection has many products.

## When web_extract Works

- Non-Shopify domains
- Plain-text endpoints: `.md`, `.txt`, `.json`, `.yaml`, `.yml`, `.csv`, `.xml`
- `raw.githubusercontent.com` URLs
- Documented API endpoints
- Most blogs, documentation sites, news outlets

## Search Query Patterns That Work

```
# Product catalog search
site:DOMAIN t-shirt collection pricing

# Shipping policy (critical for international)
site:DOMAIN shipping France international
site:DOMAIN policies/shipping

# Sales and promotions
"DOMAIN" sale discount code 2026

# Specific products
"PRODUCT NAME" site:DOMAIN in stock
```

## Common Shopify Page Patterns

```
/collections/PRODUCT-LINE      # Product catalog
/products/PRODUCT-SLUG         # Individual product page
/policies/shipping-policy      # Shipping info
/pages/shipping                # Alternative shipping page
/pages/faqs                    # FAQ
```
