# Plugin Module: WooCommerce [woocommerce]

## Overview
- **Plugin**: WooCommerce
- **Slug**: woocommerce
- **Website**: https://woocommerce.com/
- **Documentation**: https://woocommerce.github.io/woocommerce-rest-api-docs/
- **Primary Interface**: REST API (`/wc/v3/`) + WP-CLI (`wp wc`)

## What this plugin does
WooCommerce is the most popular WordPress ecommerce platform. It handles products, orders, customers, coupons, payment gateways, shipping, taxes, and reports.

---

## Authentication

WooCommerce inherits WordPress authentication. All REST API requests use the same Application Password:

```bash
# Same as core WordPress auth
WP_SITE="https://example.com"
WP_USER="admin"
WP_APP_PASSWORD="abcd EFGH 1234 ijkl MNOP 5678"

# Test WooCommerce API access
curl -s -u "$WP_USER:$WP_APP_PASSWORD" \
  "$WP_SITE/wp-json/wc/v3/products?per_page=5" | python3 -m json.tool
```

For legacy WooCommerce API (v3), a Consumer Key/Secret pair also works via query params or OAuth. Application Passwords are preferred.

WooCommerce also supports **webhooks** for event-driven automation (order created, product updated, etc.).

---

## Database Tables

| Table | Purpose |
|-------|---------|
| `wp_woocommerce_sessions` | Cart session data |
| `wp_woocommerce_api_keys` | Legacy API keys |
| `wp_woocommerce_attribute_taxonomies` | Product attributes |
| `wp_woocommerce_downloadable_product_permissions` | Download tracking |
| `wp_woocommerce_order_items` | Line items for orders |
| `wp_woocommerce_order_itemmeta` | Meta data for line items |
| `wp_woocommerce_tax_rates` | Tax rate definitions |
| `wp_woocommerce_tax_rate_locations` | Tax rate locations |
| `wp_woocommerce_shipping_zones` | Shipping zones |
| `wp_woocommerce_shipping_zone_locations` | Zone location rules |
| `wp_woocommerce_shipping_zone_methods` | Methods per zone |
| `wp_woocommerce_payment_tokens` | Saved payment methods |
| `wp_woocommerce_payment_tokenmeta` | Token metadata |
| `wp_woocommerce_log` | Plugin error/debug log |

---

## REST API Endpoints

Base path: `/wp-json/wc/v3/`

### Products (`/products`)

```bash
GET    /wc/v3/products                              # List all products
GET    /wc/v3/products?per_page=100&page=2          # Paginate
GET    /wc/v3/products?status=publish,draft         # Filter by status
GET    /wc/v3/products?category=15                  # Filter by category
GET    /wc/v3/products?sku=ABC-123                  # Lookup by SKU
GET    /wc/v3/products?type=variable                # Filter by type
GET    /wc/v3/products?featured=true                # Featured products
POST   /wc/v3/products                              # Create product
POST   /wc/v3/products/batch                        # Batch create/update/delete
GET    /wc/v3/products/{id}                         # Get single product
PUT    /wc/v3/products/{id}                         # Update product
DELETE /wc/v3/products/{id}                         # Delete product
DELETE /wc/v3/products/{id}?force=true              # Permanently delete
```

**Product types**: `simple`, `variable`, `grouped`, `external`, `variation`

**Create a simple product**:
```bash
curl -s -X POST -u "$WP_USER:$WP_APP_PASSWORD" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "Premium T-Shirt",
    "type": "simple",
    "regular_price": "29.99",
    "description": "A comfortable cotton t-shirt.",
    "short_description": "Premium cotton tee.",
    "categories": [{"id": 9}],
    "images": [{"src": "https://example.com/image.jpg"}],
    "manage_stock": true,
    "stock_quantity": 100,
    "status": "publish"
  }' \
  "$WP_SITE/wp-json/wc/v3/products"
```

**Create a variable product**:
```bash
# Step 1: Create the parent variable product
curl -s -X POST -u "$WP_USER:$WP_APP_PASSWORD" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "Variable T-Shirt",
    "type": "variable",
    "attributes": [
      {
        "name": "Size",
        "visible": true,
        "variation": true,
        "options": ["Small", "Medium", "Large"]
      },
      {
        "name": "Color",
        "visible": true,
        "variation": true,
        "options": ["Red", "Blue"]
      }
    ]
  }' \
  "$WP_SITE/wp-json/wc/v3/products"

# Step 2: Create variations (use the parent ID from step 1)
curl -s -X POST -u "$WP_USER:$WP_APP_PASSWORD" \
  -H "Content-Type: application/json" \
  -d '{
    "regular_price": "29.99",
    "attributes": [
      {"name": "Size", "option": "Small"},
      {"name": "Color", "option": "Red"}
    ],
    "manage_stock": true,
    "stock_quantity": 10
  }' \
  "$WP_SITE/wp-json/wc/v3/products/{parent_id}/variations"
```

### Product Variations (`/products/{id}/variations`)

```bash
GET    /wc/v3/products/{pid}/variations            # List variations
POST   /wc/v3/products/{pid}/variations            # Create variation
GET    /wc/v3/products/{pid}/variations/{vid}       # Get single
PUT    /wc/v3/products/{pid}/variations/{vid}       # Update
DELETE /wc/v3/products/{pid}/variations/{vid}       # Delete
```

### Product Categories (`/products/categories`)

```bash
GET    /wc/v3/products/categories                   # List all
GET    /wc/v3/products/categories?parent=0          # Top-level
POST   /wc/v3/products/categories                   # Create
PUT    /wc/v3/products/categories/{id}               # Update
```

### Product Tags (`/products/tags`)

```bash
GET    /wc/v3/products/tags
POST   /wc/v3/products/tags
```

### Product Attributes (`/products/attributes`)

```bash
GET    /wc/v3/products/attributes                   # List attributes
POST   /wc/v3/products/attributes                   # Create attribute
GET    /wc/v3/products/attributes/{id}/terms        # Attribute terms
POST   /wc/v3/products/attributes/{id}/terms        # Add term
```

### Product Reviews (`/products/reviews`)

```bash
GET    /wc/v3/products/reviews                      # List reviews
GET    /wc/v3/products/reviews?product={id}         # Reviews for product
POST   /wc/v3/products/reviews                      # Create review
PUT    /wc/v3/products/reviews/{id}                 # Update/approve
DELETE /wc/v3/products/reviews/{id}?force=true      # Delete
```

### Orders (`/orders`)

```bash
GET    /wc/v3/orders                                 # List all orders
GET    /wc/v3/orders?status=processing               # Filter by status
GET    /wc/v3/orders?customer=15                     # Customer's orders
GET    /wc/v3/orders?after=2024-01-01T00:00:00       # Date range
GET    /wc/v3/orders?dp={decimal_places}             # Precision for prices
POST   /wc/v3/orders                                 # Create order
POST   /wc/v3/orders/batch                           # Batch operations
GET    /wc/v3/orders/{id}                            # Single order
PUT    /wc/v3/orders/{id}                            # Update order (full)
PATCH  /wc/v3/orders/{id}                            # Update order (partial)
DELETE /wc/v3/orders/{id}?force=true                 # Permanently delete

# Order notes
GET    /wc/v3/orders/{id}/notes                      # List notes
POST   /wc/v3/orders/{id}/notes                      # Add note (customer or private)
```

**Order statuses**: `pending`, `processing`, `on-hold`, `completed`, `cancelled`, `refunded`, `failed`, `checkout-draft`

**Update order status**:
```bash
curl -s -X PUT -u "$WP_USER:$WP_APP_PASSWORD" \
  -H "Content-Type: application/json" \
  -d '{"status":"completed"}' \
  "$WP_SITE/wp-json/wc/v3/orders/123"
```

**Add a private order note**:
```bash
curl -s -X POST -u "$WP_USER:$WP_APP_PASSWORD" \
  -H "Content-Type: application/json" \
  -d '{"note":"Called customer — confirmed shipping address.","customer_note":false}' \
  "$WP_SITE/wp-json/wc/v3/orders/123/notes"
```

### Order Refunds (`/orders/{id}/refunds`)

```bash
POST   /wc/v3/orders/{id}/refunds                   # Create refund
GET    /wc/v3/orders/{id}/refunds                   # List refunds
GET    /wc/v3/orders/{id}/refunds/{rid}             # Single refund
DELETE /wc/v3/orders/{id}/refunds/{rid}?force=true  # Delete
```

**Create a partial refund**:
```bash
curl -s -X POST -u "$WP_USER:$WP_APP_PASSWORD" \
  -H "Content-Type: application/json" \
  -d '{
    "amount": "15.00",
    "reason": "Customer returned damaged item",
    "line_items": [
      {"id": 45, "quantity": 1, "refund_total": 15.00}
    ]
  }' \
  "$WP_SITE/wp-json/wc/v3/orders/123/refunds"
```

### Customers (`/customers`)

```bash
GET    /wc/v3/customers                               # List customers
GET    /wc/v3/customers?role=all                      # Include guests
GET    /wc/v3/customers?search=email@example.com      # Search by email
POST   /wc/v3/customers                               # Create customer
PUT    /wc/v3/customers/{id}                          # Update
DELETE /wc/v3/customers/{id}?force=true               # Delete
```

**Create a customer**:
```bash
curl -s -X POST -u "$WP_USER:$WP_APP_PASSWORD" \
  -H "Content-Type: application/json" \
  -d '{
    "email": "john@example.com",
    "first_name": "John",
    "last_name": "Doe",
    "username": "johndoe",
    "billing": {
      "first_name": "John",
      "last_name": "Doe",
      "company": "",
      "address_1": "123 Main St",
      "city": "Portland",
      "state": "OR",
      "postcode": "97201",
      "country": "US",
      "email": "john@example.com",
      "phone": "555-555-5555"
    },
    "shipping": {
      "first_name": "John",
      "last_name": "Doe",
      "address_1": "123 Main St",
      "city": "Portland",
      "state": "OR",
      "postcode": "97201",
      "country": "US"
    }
  }' \
  "$WP_SITE/wp-json/wc/v3/customers"
```

### Coupons (`/coupons`)

```bash
GET    /wc/v3/coupons                                # List
POST   /wc/v3/coupons                                # Create
PUT    /wc/v3/coupons/{id}                           # Update
DELETE /wc/v3/coupons/{id}?force=true                # Delete
```

**Coupon types**: `percent`, `fixed_cart`, `fixed_product`

**Create a coupon**:
```bash
curl -s -X POST -u "$WP_USER:$WP_APP_PASSWORD" \
  -H "Content-Type: application/json" \
  -d '{
    "code": "SUMMER20",
    "discount_type": "percent",
    "amount": "20",
    "individual_use": true,
    "exclude_sale_items": true,
    "minimum_amount": "50.00",
    "date_expires": "2024-12-31T23:59:59"
  }' \
  "$WP_SITE/wp-json/wc/v3/coupons"
```

### Reports (`/reports`)

```bash
GET    /wc/v3/reports                                 # List report types
GET    /wc/v3/reports/sales                           # Sales report
GET    /wc/v3/reports/sales?period=last_month         # Last month
GET    /wc/v3/reports/sales?date_min=2024-01-01&date_max=2024-01-31
GET    /wc/v3/reports/top_sellers                     # Top selling products
GET    /wc/v3/reports/top_sellers?period=last_week
GET    /wc/v3/reports/coupons/totals                  # Coupon usage
GET    /wc/v3/reports/customers/totals                # Customer stats
GET    /wc/v3/reports/orders/totals                   # Order stats
GET    /wc/v3/reports/products/totals                 # Product stats
```

### Payment Gateways (`/payment_gateways`)

```bash
GET    /wc/v3/payment_gateways                        # List gateways
GET    /wc/v3/payment_gateways/{id}                   # Single gateway
PUT    /wc/v3/payment_gateways/{id}                   # Update settings
```

### Shipping Zones (`/shipping/zones`)

```bash
GET    /wc/v3/shipping/zones                          # All zones
POST   /wc/v3/shipping/zones                          # Create zone
PUT    /wc/v3/shipping/zones/{id}                     # Update zone
DELETE /wc/v3/shipping/zones/{id}?force=true          # Delete zone

# Zone methods
GET    /wc/v3/shipping/zones/{id}/methods             # Methods in zone
POST   /wc/v3/shipping/zones/{id}/methods             # Add method
PUT    /wc/v3/shipping/zones/{id}/methods/{mid}       # Update method
DELETE /wc/v3/shipping/zones/{id}/methods/{mid}?force=true

# Zone locations
GET    /wc/v3/shipping/zones/{id}/locations
PUT    /wc/v3/shipping/zones/{id}/locations
```

### Shipping Methods (`/shipping_methods`)

```bash
GET    /wc/v3/shipping_methods                        # Available methods
GET    /wc/v3/shipping_methods/{id}                   # Single method
```

### Shipping Classes (`/products/shipping_classes`)

```bash
GET    /wc/v3/products/shipping_classes
POST   /wc/v3/products/shipping_classes
PUT    /wc/v3/products/shipping_classes/{id}
DELETE /wc/v3/products/shipping_classes/{id}?force=true
```

### Tax Rates & Classes (`/taxes`, `/taxes/classes`)

```bash
GET    /wc/v3/taxes                                  # Tax rates
POST   /wc/v3/taxes                                  # Create rate
PUT    /wc/v3/taxes/{id}                             # Update rate
DELETE /wc/v3/taxes/{id}?force=true

GET    /wc/v3/taxes/classes                          # Tax classes
POST   /wc/v3/taxes/classes                          # Create class
DELETE /wc/v3/taxes/classes/{slug}?force=true        # Delete class
```

### Webhooks (`/webhooks`)

```bash
GET    /wc/v3/webhooks                                # List webhooks
POST   /wc/v3/webhooks                                # Create webhook
PUT    /wc/v3/webhooks/{id}                           # Update
DELETE /wc/v3/webhooks/{id}?force=true                # Delete
```

**Create a webhook**:
```bash
curl -s -X POST -u "$WP_USER:$WP_APP_PASSWORD" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "Order Created",
    "topic": "order.created",
    "delivery_url": "https://my-app.com/webhooks/woocommerce",
    "secret": "my_webhook_secret",
    "status": "active"
  }' \
  "$WP_SITE/wp-json/wc/v3/webhooks"
```

**Webhook topics** (common ones):
- `order.created`, `order.updated`, `order.deleted`
- `product.created`, `product.updated`, `product.deleted`
- `customer.created`, `customer.updated`, `customer.deleted`
- `coupon.created`, `coupon.updated`, `coupon.deleted`

### Settings (`/settings`)

```bash
GET    /wc/v3/settings                                # All setting groups
GET    /wc/v3/settings/general                        # General settings
GET    /wc/v3/settings/products                       # Product settings
GET    /wc/v3/settings/tax                            # Tax settings
GET    /wc/v3/settings/shipping                       # Shipping settings
GET    /wc/v3/settings/checkout                       # Checkout settings
GET    /wc/v3/settings/account                        # Account settings
GET    /wc/v3/settings/advanced                       # Advanced settings
PUT    /wc/v3/settings/general/{id}                    # Update a setting
POST   /wc/v3/settings/general/batch                  # Batch update
```

### System Status (`/system_status`)

```bash
GET    /wc/v3/system_status                           # Full system report
GET    /wc/v3/system_status/tools                     # Available tools
PUT    /wc/v3/system_status/tools/{id}                 # Execute a tool
```

### Data (Import/Export)

```bash
GET    /wc/v3/data                                    # Available data types
GET    /wc/v3/data/countries                          # Country/state list
GET    /wc/v3/data/continents                         # Continents
GET    /wc/v3/data/currencies                         # Currencies
```

---

## WP-CLI Commands

```bash
wp wc product list --format=json
wp wc product list --per_page=100
wp wc product get 123
wp wc product create --name="T-Shirt" --regular_price="29.99" --type=simple
wp wc product update 123 --regular_price="24.99"
wp wc product delete 123 --force

wp wc shop_order list --status=processing
wp wc shop_order get 123
wp wc shop_order update 123 --status=completed

wp wc customer list
wp wc customer list --search=email@example.com
wp wc customer create --email=john@example.com --first_name=John --last_name=Doe
wp wc customer update 5 --first_name=Jonathan
wp wc customer delete 5 --force

wp wc coupon list
wp wc coupon create --code=SAVE10 --discount_type=percent --amount=10
wp wc coupon delete 123 --force

wp wc product review list
wp wc product variation list 123
wp wc product attribute list
wp wc product category list

wp wc shipping_zone list
wp wc shipping_zone_method list 1
wp wc tax list
wp wc payment_gateway list

# Reports
wp wc report sales --period=last_month
wp wc report top-sellers --period=last_week
wp wc report orders --date_min=2024-01-01 --date_max=2024-01-31

# Tools
wp wc tool clear_transients
wp wc tool clear_expired_transients
wp wc tool clear_customer_sessions
wp wc tool recount_terms
wp wc tool update_db
wp wc tool verify_db
```

---

## Quick Reference: Common Tasks

### Bulk Update Product Prices

```bash
# Increase all prices by 10%
for PRODUCT_ID in $(wp wc product list --status=publish --field=id); do
  CURRENT_PRICE=$(wp wc product get "$PRODUCT_ID" --field=regular_price --format=json)
  NEW_PRICE=$(echo "$CURRENT_PRICE * 1.10" | bc)
  wp wc product update "$PRODUCT_ID" --regular_price="$NEW_PRICE"
  echo "Updated product $PRODUCT_ID price to $NEW_PRICE"
done
```

### Process Refunds in Batch

```bash
# Refund all cancelled orders from a specific date
ORDER_IDS=$(wp wc shop_order list --status=cancelled --after=2024-01-01 --field=id)
for id in $ORDER_IDS; do
  curl -s -X POST -u "$WP_USER:$WP_APP_PASSWORD" \
    -H "Content-Type: application/json" \
    -d "{\"amount\":\"0.00\",\"reason\":\"Order cancelled — full refund processed\"}" \
    "$WP_SITE/wp-json/wc/v3/orders/$id/refunds"
  echo "Refunded order $id"
done
```

### Import Products from CSV

```bash
# WP-CLI has built-in CSV import
wp wc product csv_import /path/to/products.csv

# CSV format: name,type,regular_price,description,short_description,categories,images,stock_quantity
# "T-Shirt",simple,29.99,"Full description","Short desc","Clothing > Tees","https://img.url/tshirt.jpg",100
```

### Export Orders for Accounting

```bash
wp wc shop_order list --format=csv --fields=id,date_created,billing_first_name,billing_last_name,total,status > orders.csv
```

### Clear WooCommerce Transients (Performance Fix)

```bash
wp wc tool clear_transients
wp wc tool clear_expired_transients
wp wc tool clear_customer_sessions
```

### Regenerate Product Lookup Tables

```bash
wp wc tool regenerate_product_lookup_tables
wp wc tool recount_terms
```

### Find Products Without Images

```bash
curl -s -u "$WP_USER:$WP_APP_PASSWORD" \
  "$WP_SITE/wp-json/wc/v3/products?per_page=100" | python3 -c "
import json,sys
products=json.load(sys.stdin)
for p in products:
    if not p.get('images'):
        print(f'No image: {p[\"id\"]} - {p[\"name\"]}')"
```

### Update Stock Quantities

```bash
# Set all out-of-stock items to 0
for id in $(wp wc product list --stock_status=outofstock --field=id); do
  wp wc product update "$id" --stock_quantity=0
done
```

---

## Workflows & Patterns

### Set Up a Complete Store

```bash
# 1. Configure store basics
curl -s -X PUT -u "$WP_USER:$WP_APP_PASSWORD" \
  -H "Content-Type: application/json" \
  -d '{
    "woocommerce_store_address": "123 Main St",
    "woocommerce_store_city": "Portland",
    "woocommerce_default_country": "US:OR",
    "woocommerce_currency": "USD",
    "woocommerce_weight_unit": "lbs",
    "woocommerce_dimension_unit": "in"
  }' \
  "$WP_SITE/wp-json/wc/v3/settings/general/batch"

# 2. Set up payment gateways
curl -s -X PUT -u "$WP_USER:$WP_APP_PASSWORD" \
  -H "Content-Type: application/json" \
  -d '{"enabled":true,"title":"Credit Card"}' \
  "$WP_SITE/wp-json/wc/v3/payment_gateways/stripe"

# 3. Create shipping zone
SHIPPING_ZONE=$(curl -s -X POST -u "$WP_USER:$WP_APP_PASSWORD" \
  -H "Content-Type: application/json" \
  -d '{"name":"United States"}' \
  "$WP_SITE/wp-json/wc/v3/shipping/zones")
ZONE_ID=$(echo "$SHIPPING_ZONE" | python3 -c "import json,sys; print(json.load(sys.stdin)['id'])")

# 4. Add free shipping method to zone
curl -s -X POST -u "$WP_USER:$WP_APP_PASSWORD" \
  -H "Content-Type: application/json" \
  -d '{"method_id":"free_shipping","settings":{"title":"Free Shipping"}}' \
  "$WP_SITE/wp-json/wc/v3/shipping/zones/$ZONE_ID/methods"

# 5. Add flat rate with minimum
curl -s -X POST -u "$WP_USER:$WP_APP_PASSWORD" \
  -H "Content-Type: application/json" \
  -d '{"method_id":"flat_rate","settings":{"title":"Standard Shipping","cost":"5.00"}}' \
  "$WP_SITE/wp-json/wc/v3/shipping/zones/$ZONE_ID/methods"
```

### Seasonal Sale Setup

```bash
# 1. Create a coupon
curl -s -X POST -u "$WP_USER:$WP_APP_PASSWORD" \
  -H "Content-Type: application/json" \
  -d '{
    "code":"SUMMER2024",
    "discount_type":"percent",
    "amount":"25",
    "date_expires":"2024-08-31T23:59:59",
    "usage_limit":1000,
    "usage_limit_per_user":1
  }' \
  "$WP_SITE/wp-json/wc/v3/coupons"

# 2. Set sale prices on products
for id in $(wp wc product list --category=14 --field=id); do
  REGULAR=$(wp wc product get "$id" --field=regular_price)
  SALE=$(echo "$REGULAR * 0.75" | bc)  # 25% off
  wp wc product update "$id" --sale_price="$SALE" --date_on_sale_from="2024-06-01" --date_on_sale_to="2024-08-31"
  echo "Set sale price for product $id: $REGULAR -> $SALE"
done
```

### Troubleshoot an Order

```bash
# 1. Get full order details
curl -s -u "$WP_USER:$WP_APP_PASSWORD" \
  "$WP_SITE/wp-json/wc/v3/orders/123" | python3 -m json.tool

# 2. Check order notes (customer communication trail)
curl -s -u "$WP_USER:$WP_APP_PASSWORD" \
  "$WP_SITE/wp-json/wc/v3/orders/123/notes" | python3 -m json.tool

# 3. Check payment gateway
wp option get woocommerce_stripe_settings --format=json

# 4. Check for stuck webhooks
curl -s -u "$WP_USER:$WP_APP_PASSWORD" \
  "$WP_SITE/wp-json/wc/v3/webhooks" | python3 -c "
import json,sys
webhooks=json.load(sys.stdin)
for w in webhooks:
    print(f'{w[\"name\"]:30} {w[\"topic\"]:30} {w[\"status\"]}')"
```

---

## Troubleshooting

- **"woocommerce_rest_cannot_view"**: The application password user needs `manage_woocommerce` or `read_woocommerce` capabilities. Usually this means the user must be at least a Shop Manager.
- **"Product not found" with SKU lookup**: SKU lookups via `?sku=` are case-sensitive. Try both cases.
- **Orders not showing in reports**: Run `wp wc tool clear_transients` and `wp wc tool recount_terms`.
- **Slow product queries**: Check `wp_woocommerce_product_attributes_lookup` — run `wp wc tool regenerate_product_attributes_lookup_tables`.
- **Webhooks not firing**: Check Action Scheduler: `wp action-scheduler list --status=failed`. Clear: `wp action-scheduler clean`.
