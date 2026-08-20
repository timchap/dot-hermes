---
name: web-research
description: Conduct web research with a fallback pipeline — when web_extract fails (Shopify stores, bot-detected pages), use web_search + browser tools systematically. Covers product availability checks, pricing comparisons, retailer stock audits, and shipping policy lookups.
version: 1.0.0
author: Hermes Agent
license: MIT
platforms: [linux, macos, windows]
metadata:
  hermes:
    tags: [web, research, extraction, fallback, ecommerce, products, pricing]
---

# Web Research

## Overview

This skill provides a systematic approach to web research when content extraction encounters blockers. The primary challenge is that `web_extract` fails on Shopify-based storefronts with `ERR_BLOCKED_BY_CLIENT`.

## Fallback Pipeline

When `web_extract` fails with `ERR_BLOCKED_BY_CLIENT` or returns empty/blank content:

### Step 1: Site-Specific Search Queries

Run parallel `web_search` calls with targeted queries:

```
# Product catalog
site:DOMAIN t-shirt collection pricing stock 2026

# Shipping policies (critical for international buyers)
site:DOMAIN shipping France international

# Sales/promotions
"DOMAIN" sale discount code 2026

# Specific products
"PRODUCT NAME" site:DOMAIN in stock
```

Use date-stamped queries (`2026`) to filter stale results.

### Step 2: Extract Policy/Info Pages

Policy pages (shipping, returns, FAQ) typically load fine with `web_extract` — they're rarely on Shopify cart blocks:

```
https://DOMAIN/policies/shipping-policy
https://DOMAIN/pages/shipping
https://DOMAIN/pages/faqs
```

### Step 3: Browser Tool Fallback

For product detail pages with size selectors and stock indicators:

```
browser_navigate("https://DOMAIN/products/PRODUCT-SLUG")
browser_snapshot()          # See interactive elements
browser_vision(annotate=true)  # Visual confirmation of stock status
```

### Step 4: Save Results

Cache structured results to `~/.hermes/cache/web/` for cross-session reference.

## Confirmed Blocker Domains

- `merzbschwanen.com` (Shopify)
- `redcastheritage.com` (Shopify)
- `witheredfig.com` (Shopify)
- `oldhouseprovisions.com` (Shopify)
- Any `*.myshopify.com` storefront

## Multi-Retailer Product Availability Audit

For tasks like "check availability of PRODUCT across RETAILERS, focusing on FR shipping":

1. **Parallel initial sweep**: `web_search` on each retailer + brand name simultaneously.
2. **Official site first**: Always check the brand's own store — usually has the freshest stock data and best shipping terms for EU customers.
3. **Extract policy pages** with `web_extract` (works on most, rarely Shopify-blocked).
4. **Browser navigation** for product listings that need size/stock detail.
5. **Verify each retailer's shipping scope** — not all boutiques ship internationally even if they appear to (e.g., Old House Provisions is US-only; no visible warning banner).
6. **Flag "sale price" mislabels** — some retailers (Redcast Heritage) display "Sale price" on items at their regular price. Note this distinction in the report.
7. **Output format**: Use structured tables per retailer with columns: Style, Price, Size/Stock, Shipping to target country, Notable flags.

## When web_extract Works

- Non-Shopify domains
- Plain-text endpoints: `.md`, `.txt`, `.json`, `.yaml`, `.yml`, `.csv`, `.xml`
- `raw.githubusercontent.com` URLs
- Documented API endpoints
- Most blogs, documentation sites, news outlets

## Best Practices

1. **Batch independent searches** — run 3-5 site queries in parallel.
2. **Always check shipping early** — international buyers need this before comparing prices.
3. **Capture size/stock data** — `web_search` snippets rarely show sizes; use `browser_snapshot` for product pages.
4. **Note "Sale price" vs list price** — Shopify sites often label current pricing as "Sale price" even during normal operations.
5. **Verify retailer shipping scope** — many boutique stores (e.g., Old House Provisions) ship US-only despite having no obvious "US only" banner.

## Reference Files

- `references/web-extraction.md` — Detailed fallback pipeline, blocked domains list, working search query patterns.
- `references/multi-retailer-audit.md` — Multi-retailer audit patterns, URL patterns per retailer, shipping summaries, "sale price" labeling caveat, US-only retailer gotcha, product line quick reference.
