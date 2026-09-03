# Multi-Retailer Audit — Shipping & URL Patterns

## Key Learnings (2026-08-20 Merz b. Schwanen Audit)

### URL Patterns That Worked

| Retailer | Catalog URL | Shipping URL | Notes |
|---|---|---|---|
| merzbschwanen.com | /collections/mens-t-shirts | /policies/shipping-policy | /pages/shipping returns 404 |
| redcastheritage.com | /collections/merz-b-schwanen | /pages/shipping | Also /pages/shipping-terms |
| witheredfig.com | /collections/merz-b-schwanen | /pages/payment-and-shipping | Intl section at bottom |
| oldhouseprovisions.com | /collections/merz-b-schwanen | N/A | US-only |

### Shipping to France — Summary (updated 2026-09-03)

| Retailer | Origin | Ship to FR? | Free Threshold | Carrier | Transit |
|---|---|---|---|---|---|
| merzbschwanen.com | Germany | Yes | EUR 175 | EU carrier | 2-4 days |
| redcastheritage.com | Spain | Yes | EUR 150 | UPS 48-72h (std), 24h (express €4) | 24-72h business days |
| witheredfig.com | Virginia, US | Yes | USD 500 | DHL (intl) / UPS (dom) | 2-6 / 6-10 days |
| oldhouseprovisions.com | Virginia, US | No | — | — | — |

**Redcast Heritage detail (2026-09-03):** France-specific: under €150 = €7.95 standard / €11.95 express. Over €150 = free standard / €4 express. All VAT included, no EU customs.

**Withered Fig detail:** Free international shipping over $500; flat-rate otherwise. Ships via DHL internationally.

### US-Only Retailer Gotcha

Old House Provisions has no visible "US-only" banner. Collection page loads normally with 22 items. Only discoverable by checking footer/store locator or attempting checkout.

**Rule: Always check footer/store locator and contact pages for shipping scope before declaring a retailer as shipping internationally.**

### "Sale Price" Labeling Caveat

Redcast Heritage displays "Sale price" on items at their standard price. This may be a permanent discount. Flag as "permanently discounted" not "on sale" in reports.

### Sales / Clearance Collections

Some retailers run separate sale collections rather than inline markdowns. Example: merzbschwanen.com has a **"Still Good"** sale collection (`/collections/mens-still-good`) with items at 40-50% off. Always check for dedicated sale pages when asked about discounts.

### Merz Product Line Quick Reference (2026-09-03)

| Model | Weight | Fit | Typical EUR Price | Notes |
|---|---|---|---|---|
| TEE02 Classic Cotton Jersey | 6oz | Classic | ~€80 | **RESTOCKED** 2026-09; also available in cropped (TEE02C) |
| 215 Loopwheeled | 7.2oz | Classic Fit | ~€115 | Classic no-side-seam tee |
| 214 Loopwheeled Relaxed | 7.2oz | Relaxed | ~€116 | Often sold out at Redcast (Ink Blue variant) |
| 2S14 Super Heavyweight | 13.4oz | Relaxed Fit | ~€165 | Also listed as 10.7oz at some retailers |
| 2M15 Sturdy Jersey | 6.8oz | Classic | ~€100 | **RESTOCKED** 2026-09 |
| 2M15C Cropped | 6.8oz | Cropped | ~€100 | Unisex |
| 1950s Loopwheeled | 5.5oz | Classic | ~€90 | Often sold out at Old House Provisions |
| 1940s Loopwheeled | 4.6oz | Relaxed | ~€95 | Often sold out at Old House Provisions |
| 1940sP Loopwheeled Pocket | 4.6oz | Relaxed | ~€95 | With chest pocket |
| 1950sLS Longsleeve | — | Classic | ~€110 | Organic cotton |
| 2M15C Cropped Vintage | 6.8oz | Cropped | ~€105 | Mid-Century Machine Refined |
| TEE03 Authentic Jersey | Standard | Classic | ~€85 | Slim/regular cotton jersey |
| 2M06 Henley | — | — | USD 125 | Vintage Machine Refined, long sleeve |
| Slub Pima Cotton | 4.9oz | Relaxed | ~€80 | Premium soft tee |

### Inventory Change Signals (2026-09-03)

- **RESTOCK** badges on merzbschwanen.com indicate previously unavailable items are back (TEE02, 2M15).
- **NEW** badges indicate new color/variant drops (TEE02 new colors, 2M15C Cropped Vintage).
- AW26 (Autumn/Winter 2026) collection now live on merzbschwanen.com alongside SS26.
- Always compare RESTOCK/NEW flags against prior audit data when available.
