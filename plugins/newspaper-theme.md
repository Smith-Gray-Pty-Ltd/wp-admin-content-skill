# Plugin Module: Newspaper Theme (tagDiv) [newspaper]

## Overview
- **Plugin/Theme**: Newspaper (by tagDiv)
- **Slug**: newspaper, td-composer
- **Website**: https://themeforest.net/item/newspaper/5489609
- **Documentation**: https://forum.tagdiv.com/
- **Primary Interface**: WP Admin AJAX + tagDiv Cloud API + WP-CLI + WP REST API

## What this theme does
Newspaper is a premium WordPress theme designed for news, magazine, and blog sites. It includes the tagDiv Composer (drag-and-drop page builder) and the tagDiv Cloud Library (cloud-hosted templates). It uses custom post types for templates and extensive theme options.

---

## Authentication

Newspaper uses standard WordPress authentication plus a tagDiv Cloud account:

```bash
WP_SITE="https://example.com"
WP_USER="admin"
WP_APP_PASSWORD="abcd EFGH 1234 ijkl MNOP 5678"

# tagDiv Cloud credentials (for template library)
TD_CLOUD_EMAIL="user@example.com"
TD_CLOUD_API_KEY="..."
```

The tagDiv Cloud Library API key is found in: **Newspaper → Theme Panel → Cloud Templates → API Key**.

---

## Database Tables & Options

Newspaper does not create custom database tables. Its data is stored in:

| Storage | Purpose |
|---------|---------|
| `wp_options` (`td_*`, `tdc_*`, `tds_*`) | Theme settings, header/footer styles, composer settings |
| `wp_options` (`td_011`, `td_012`, etc.) | Category-specific settings |
| `wp_postmeta` (`td_*`) | Template assignments, post settings |
| Custom Post Type: `tdb_templates` | tagDiv Cloud Templates (headers, footers, single templates) |
| Custom Post Type: `tdb_cloud_templates` | tagDiv Cloud Library templates |
| Custom Post Type: `tdc-review` | tagDiv Composer reviews |

---

## Key Options (`wp_options` table)

```bash
# Theme Panel settings
wp option get td_theme_options --format=json
wp option get tdc_version
wp option get tds_white_menu            # Site-wide header style
wp option get tds_footer_style          # Site-wide footer style

# Category template assignments
wp option get td_011                     # Category ID 11 settings
wp option get td_category_options --format=json
```

The `td_theme_options` option contains a serialized/JSON array of all theme panel settings including logos, colors, typography, layout, ads, and API keys.

---

## Custom Post Types

### `tdb_templates` (tagDiv Cloud Templates)

These are site-wide templates imported from the tagDiv Cloud Library. They include:
- **Headers**: `tdb_template_type` = `header`
- **Footers**: `tdb_template_type` = `footer`
- **Single post templates**: `tdb_template_type` = `single`
- **Category templates**: `tdb_template_type` = `category`
- **404 page templates**: `tdb_template_type` = `404`

```bash
# List all tagDiv templates
wp post list --post_type=tdb_templates --format=json

# List only headers
wp post list --post_type=tdb_templates --meta_key=tdb_template_type --meta_value=header

# Get template content (stored as JSON with block structure)
wp post get 123 --post_type=tdb_templates --field=post_content
```

### `tdb_cloud_templates` (Cloud Library Templates)

Templates saved to your Cloud Library for reuse across sites.

### `tdc-review` (Reviews)

Product/entity reviews created with the tagDiv Composer review system.

---

## REST API & Admin AJAX

Newspaper primarily uses WordPress admin AJAX (`/wp-admin/admin-ajax.php`) for its page builder operations. The tagDiv Composer save/load operations require nonce-based authentication.

### Admin AJAX Patterns

The tagDiv Composer uses these key AJAX actions:

```bash
# Save a template
action=td_ajax_save_post
# Parameters: post_id, td_post_theme_settings_{post_id}, td_post_video_meta_{post_id}, ...
```

### Standard REST API for Templates

Since `tdb_templates` is a WordPress custom post type, the standard REST API works:

```bash
# List templates via REST
GET /wp-json/wp/v2/tdb_templates

# Get a single template
GET /wp-json/wp/v2/tdb_templates/{id}

# Template meta fields
GET /wp-json/wp/v2/tdb_templates/{id}?meta_keys=tdb_template_type,tdb_template_global
```

**Key meta fields for `tdb_templates`**:
- `tdb_template_type` — `header`, `footer`, `single`, `category`, `404`, `author`, `search`, `date`, `tag`, `attachment`
- `tdb_template_global` — template content (JSON/HTML block structure)
- `tdb_template_css` — template-specific CSS

---

## Theme Panel Settings Reference

Access theme settings via `wp option get`:

```bash
# General
wp option get td_theme_options --format=json | python3 -c "
import json,sys
opts=json.load(sys.stdin)
print(f'Logo: {opts.get(\"tds_logo_upload\",\"default\")}')
print(f'Favicon: {opts.get(\"tds_favicon_upload\",\"default\")}')
print(f'Header style: {opts.get(\"tds_header_style\",\"default\")}')
print(f'Footer style: {opts.get(\"tds_footer_style\",\"default\")}')
"

# Category settings (e.g., category ID 5)
wp option get td_005 --format=json

# Theme color settings
wp option get tds_theme_color_palette --format=json

# Mobile theme settings
wp option get tds_mobile_theme --format=json
```

### Common Theme Options (`td_theme_options` keys):

| Key | Purpose |
|-----|---------|
| `tds_logo_upload` | Main logo URL |
| `tds_logo_upload_r` | Retina logo URL |
| `tds_logo_mobile_upload` | Mobile logo URL |
| `tds_favicon_upload` | Favicon URL |
| `tds_header_style` | Site-wide header style number |
| `tds_footer_style` | Site-wide footer style number |
| `tds_smart_sidebar` | Enable/disable smart sidebar |
| `tds_lazy_loading_images` | Lazy load toggle |
| `tds_google_fonts` | Google Fonts selection |
| `tds_custom_css` | Custom CSS code |
| `tds_custom_javascript` | Custom JavaScript |
| `tds_analytics_code` | Analytics/tracking code |
| `tds_ads_header` | Header ad code |
| `tds_ads_footer` | Footer ad code |

---

## Quick Reference: Common Tasks

### Import a Cloud Template

```bash
# tagDiv Cloud templates have a template ID from the library
# Import is typically done via the tagDiv API
TEMPLATE_ID="12345"

# Download the template content from tagDiv Cloud
curl -s -H "Authorization: Bearer $TD_CLOUD_API_KEY" \
  "https://cloud.tagdiv.com/api/v1/templates/$TEMPLATE_ID" | python3 -c "
import json,sys
t=json.load(sys.stdin)
print(f'Template: {t[\"title\"]}')
print(f'Type: {t[\"type\"]}')
print(f'Content length: {len(t[\"content\"])} chars')"

# Create a tdb_templates post with this content
curl -s -X POST -u "$WP_USER:$WP_APP_PASSWORD" \
  -H "Content-Type: application/json" \
  -d "{
    \"title\":\"Imported Header\",
    \"content\":\"\",
    \"status\":\"publish\",
    \"meta\":{
      \"tdb_template_type\":\"header\",
      \"tdb_template_global\":$(echo "$TEMPLATE_CONTENT" | python3 -c 'import json,sys; print(json.dumps(sys.stdin.read()))')
    }
  }" \
  "$WP_SITE/wp-json/wp/v2/tdb_templates"
```

### Assign a Template Globally

```bash
# Assign a header template site-wide
curl -s -X POST -u "$WP_USER:$WP_APP_PASSWORD" \
  "$WP_SITE/wp-json/wp/v2/tdb_templates/{template_id}" \
  -d '{"meta":{"tdb_template_global":"header"}}'

# Alternatively via WP-CLI
wp post meta update {template_id} tdb_template_type header
wp post meta update {template_id} tdb_template_global 1
```

### Update Site Logo

```bash
# Upload the logo
LOGO_ID=$(wp media import /path/to/new-logo.png --porcelain)

# Update theme options
CURRENT_OPTS=$(wp option get td_theme_options --format=json)
NEW_OPTS=$(echo "$CURRENT_OPTS" | python3 -c "
import json,sys
opts=json.load(sys.stdin)
opts['tds_logo_upload']='$WP_SITE/wp-content/uploads/$(wp post get $LOGO_ID --field=guid)'
print(json.dumps(opts))")
wp option update td_theme_options "$NEW_OPTS" --format=json

echo "Logo updated. Clear any cache if needed."
```

### Export All Template Assignments

```bash
wp post list --post_type=tdb_templates --format=json | python3 -c "
import json,sys
templates=json.load(sys.stdin)
for t in templates:
    meta={}
    for m in $(wp post meta list $t['ID'] --format=json): pass
    print(f'ID:{t[\"ID\"]} | {t[\"post_title\"]:30} | Type:{t.get(\"tdb_template_type\",\"none\")}')
"

# Better approach: dump as CSV
wp post list --post_type=tdb_templates --format=csv --fields=ID,post_title,post_status > templates.csv
```

### Change Global Header Style

```bash
# Get current theme options
CURRENT=$(wp option get td_theme_options --format=json)

# Change header style to style 10
UPDATED=$(echo "$CURRENT" | python3 -c "
import json,sys
opts=json.load(sys.stdin)
opts['tds_header_style']='tds_header_style_10'
print(json.dumps(opts))")

wp option update td_theme_options "$UPDATED" --format=json
echo "Header style updated. Flush cache if needed."
```

### Apply Template to a Specific Category

```bash
CATEGORY_ID=5
TEMPLATE_ID=100

# Set category-specific template
wp option update "td_$(printf '%03d' $CATEGORY_ID)" '{"tdc_category_template":"'$TEMPLATE_ID'"}'
```

### Optimize Newspaper Performance

```bash
# Enable lazy loading if not already on
CURRENT=$(wp option get td_theme_options --format=json)
UPDATED=$(echo "$CURRENT" | python3 -c "
import json,sys
opts=json.load(sys.stdin)
opts['tds_lazy_loading_images']='yes'
opts['tds_minify_css']='yes'
opts['tds_minify_js']='yes'
print(json.dumps(opts))")
wp option update td_theme_options "$UPDATED" --format=json

# Clear theme cache
wp option delete td_css_cache
wp option delete td_js_cache

# Regenerate critical CSS
wp eval "do_action('td_css_demo_gen_callback');"

echo "Performance settings updated and caches cleared."
```

### Bulk Update Post Templates

```bash
# Set all posts in category 5 to use template ID 99
POST_IDS=$(wp post list --cat=5 --post_type=post --format=ids)
for PID in $POST_IDS; do
  wp post meta update "$PID" td_post_theme_settings '{"td_post_template":"99"}'
  echo "Updated post $PID"
done
```

---

## Workflows & Patterns

### Complete Header/Footer Setup

```bash
# 1. Import a header template from Cloud Library
# (Get template from tagDiv Cloud via their API)
HEADER_CONTENT='{...json block structure...}'

HEADER_ID=$(curl -s -X POST -u "$WP_USER:$WP_APP_PASSWORD" \
  -H "Content-Type: application/json" \
  -d "{
    \"title\":\"Main Header\",
    \"status\":\"publish\",
    \"type\":\"tdb_templates\",
    \"meta\":{
      \"tdb_template_type\":\"header\",
      \"tdb_template_global\":$(echo "$HEADER_CONTENT" | python3 -c 'import json,sys; print(json.dumps(sys.stdin.read()))')
    }
  }" \
  "$WP_SITE/wp-json/wp/v2/tdb_templates" | python3 -c "import json,sys; print(json.load(sys.stdin)['id'])")

echo "Created header template: $HEADER_ID"

# 2. Import a footer template
FOOTER_CONTENT='{...json block structure...}'

FOOTER_ID=$(curl -s -X POST -u "$WP_USER:$WP_APP_PASSWORD" \
  -H "Content-Type: application/json" \
  -d "{
    \"title\":\"Main Footer\",
    \"status\":\"publish\",
    \"type\":\"tdb_templates\",
    \"meta\":{
      \"tdb_template_type\":\"footer\",
      \"tdb_template_global\":$(echo "$FOOTER_CONTENT" | python3 -c 'import json,sys; print(json.dumps(sys.stdin.read()))')
    }
  }" \
  "$WP_SITE/wp-json/wp/v2/tdb_templates" | python3 -c "import json,sys; print(json.load(sys.stdin)['id'])")

echo "Created footer template: $FOOTER_ID"

# 3. Set them as site-wide defaults
CURRENT=$(wp option get td_theme_options --format=json)
UPDATED=$(echo "$CURRENT" | python3 -c "
import json,sys
opts=json.load(sys.stdin)
opts['tds_header_template_id']='$HEADER_ID'
opts['tds_footer_template_id']='$FOOTER_ID'
print(json.dumps(opts))")
wp option update td_theme_options "$UPDATED" --format=json

echo "Header and footer assigned site-wide."
```

### Migrate Newspaper Theme Settings Between Sites

```bash
# SOURCE: Export theme settings
wp option get td_theme_options --format=json > td_theme_options.json
wp post list --post_type=tdb_templates --format=json > tdb_templates.json
wp post list --post_type=tdc-review --format=json > tdc_reviews.json

# Copy exported files to destination server

# DESTINATION: Import theme settings
wp option update td_theme_options "$(cat td_theme_options.json)" --format=json

# Import templates
python3 -c "
import json
with open('tdb_templates.json') as f:
    templates=json.load(f)
for t in templates:
    print(f'ID:{t[\"ID\"]} Title:{t[\"post_title\"]}')"

# Then recreate each template via REST API
```

### Mobile-Specific Setup

```bash
CURRENT=$(wp option get td_theme_options --format=json)

# Configure mobile theme
UPDATED=$(echo "$CURRENT" | python3 -c "
import json,sys
opts=json.load(sys.stdin)
opts['tds_mobile_theme']='tds_mobile'
opts['tds_mobile_logo']='$MOBILE_LOGO_URL'
opts['tds_mobile_menu_style']='tds_mobile_menu_style_1'
opts['tds_mobile_search']='yes'
opts['tds_mobile_social_icons']='yes'
print(json.dumps(opts))")

wp option update td_theme_options "$UPDATED" --format=json
```

---

## Troubleshooting

- **"Template not applying"**: Check that the template `post_status` is `publish` and the `tdb_template_type` meta is set correctly. Also verify the template is assigned in `td_theme_options` under the correct key.
- **"Composer not loading"**: This often means the nonce is expired or user is not logged in. The tagDiv Composer requires admin-level authentication. Use cookie-based auth for admin AJAX if using the Composer programmatically.
- **"Cloud Library connection failed"**: Verify the API key in `td_theme_options` → `tds_cloud_api_key`. The tagDiv Cloud API key must be valid and the subscription active.
- **Performance issues after import**: Run `wp transient delete --all` and clear the theme CSS cache (`wp option delete td_css_cache`). Regenerate critical CSS via the Theme Panel.
- **"White screen after updating theme options"**: If manually editing `td_theme_options`, ensure the JSON is valid. An invalid serialized array will break the theme panel. Always validate with `wp option get td_theme_options --format=json | python3 -m json.tool` before saving.
