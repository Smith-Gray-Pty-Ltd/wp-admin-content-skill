# Plugin Module: Newspaper Theme (tagDiv) [newspaper]

## Overview
- **Plugin/Theme**: Newspaper (by tagDiv)
- **Slug**: newspaper, td-composer
- **Website**: https://themeforest.net/item/newspaper/5489609
- **Documentation**: https://forum.tagdiv.com/
- **Primary Interface**: tagDiv Composer UI + Theme Panel (via browser-use) — NOT REST API or WP-CLI
- **Documentation**: https://forum.tagdiv.com/ — all theme settings changes should follow the documented UI path

## What this theme does
Newspaper is a premium WordPress theme designed for news, magazine, and blog sites. It includes the tagDiv Composer (drag-and-drop page builder) and the tagDiv Cloud Library (cloud-hosted templates). It uses custom post types for templates and extensive theme options.

## CRITICAL: How to Modify Newspaper Theme Settings

**Always use the tagDiv UI via browser-use for theme settings changes.** Never attempt to directly manipulate `td_theme_options` or other theme options via `wp option update` or the REST API. The Newspaper theme stores settings as complex nested JSON — hand-editing it will almost certainly corrupt the data.

| Task | Correct Method | Wrong Method |
|------|---------------|--------------|
| Change logo | tagDiv Composer UI (browser-use) | `wp option update td_theme_options` |
| Change header/footer style | Theme Panel → Header/Footer (browser-use) | `wp option update` |
| Change theme colors | Theme Panel → Theme Colors (browser-use) | `wp option update` |
| Change fonts | Theme Panel → Theme Fonts (browser-use) | `wp option update` |
| Import/export theme settings | Theme Panel → Import/Export (browser-use) | Raw DB manipulation |
| Category-specific settings | Theme Panel → Categories (browser-use) | `wp option update td_XXX` |
| Install pre-built website | Theme Panel → Pre-built Websites (browser-use) | N/A |
| Inspect current settings (read-only) | `wp option get td_theme_options --format=json` | N/A |
| Manage templates (tdb_templates CPT) | REST API or WP-CLI | N/A |
| Edit page layouts with Composer | tagDiv Composer UI (browser-use) | N/A |

**For the agent**: When a user asks to change anything in the Newspaper theme (logo, colors, fonts, header style, footer, ads, etc.), your first question should be: "Is this something configured in the tagDiv Composer or Theme Panel?" If yes, use browser-use to navigate the UI. The tagDiv documentation at https://forum.tagdiv.com/ is the authoritative guide for all UI operations.

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

## Key Options (Read-Only Inspection)

Use `wp option get` **only for inspecting/diagnosing** the current theme state. Never use `wp option update` to modify theme settings.

```bash
# INSPECTION ONLY — use these to check current state, not to modify
wp option get td_theme_options --format=json
wp option get tdc_version
wp option get tds_white_menu            # Site-wide header style
wp option get tds_footer_style          # Site-wide footer style

# Category template assignments (inspect only)
wp option get td_011                     # Category ID 11 settings
wp option get td_category_options --format=json
```

The `td_theme_options` option contains a deeply nested JSON blob of all theme panel settings. Modifying this directly is error-prone and can break the theme. **To change any of these settings, use browser-use to navigate the tagDiv Theme Panel or Composer UI instead.**

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

## Quick Reference: Common Tasks (browser-use)

All Newspaper theme settings changes use browser-use to navigate the tagDiv UI. Follow the tagDiv documentation at https://forum.tagdiv.com/ for the exact UI steps. Below are browser-use task templates for common operations.

### Update Site Logo

Use browser-use to navigate the tagDiv Composer and modify the header logo element. The documented method is at https://forum.tagdiv.com/add-logo-newspaper/

```python
from browser_use import Agent, Browser, ChatBrowserUse, BrowserProfile
import asyncio

async def update_newspaper_logo(site_url, logo_image_path):
    profile = BrowserProfile(storage_state_from_browser='chrome')
    browser = Browser(profile=profile)

    agent = Agent(
        task=f"""
        Go to {site_url}/wp-admin.
        Navigate to the homepage and click 'Edit with tagDiv Composer'.
        Wait for the tagDiv Composer to fully load.
        In the header area, click on the existing logo element.
        The Header Logo settings panel should appear on the left.
        Under the 'General' tab, click 'Upload' for the Logo Image field.
        Upload the image file at path: {logo_image_path}
        If there's a Retina Logo field, also upload the same image at 2x resolution.
        Make sure 'Show Image' is selected in the dropdown.
        If there's an SVG tab, check it and clear any SVG logo that might override the image.
        Click the Save button in the Composer toolbar.
        Wait for the save confirmation notification.
        Close the Composer and verify the new logo appears on the site.
        """,
        llm=ChatBrowserUse(),
        browser=browser,
    )
    await agent.run()
    return await agent.get_result()

asyncio.run(update_newspaper_logo('https://example.com', '/Users/john/Desktop/new-logo.png'))
```

### Change Global Header Style

Navigate to the Theme Panel via the admin menu. Documented at https://forum.tagdiv.com/header-manager/

```python
agent = Agent(
    task=f"""
    Go to {site_url}/wp-admin.
    Hover over 'Newspaper' in the left admin menu, then click 'Theme Panel'.
    In the Theme Panel, find the 'Header' or 'Header Style' section.
    Select the desired header style from the available options.
    Click the 'Save Settings' button at the bottom.
    Wait for the success confirmation message.
    Clear any cache if prompted.
    """,
    llm=ChatBrowserUse(),
    browser=browser,
)
```

### Change Theme Colors

Documented at https://forum.tagdiv.com/theme-colors-introduction/

```python
agent = Agent(
    task=f"""
    Go to {site_url}/wp-admin.
    Navigate to Newspaper > Theme Panel.
    Find the 'Theme Colors' section.
    Locate the color picker for the element you want to change
    (e.g., 'Accent Color', 'Header Background', 'Text Color').
    Click the color picker and enter the new hex color value.
    Click Save Settings.
    Wait for confirmation.
    """,
    llm=ChatBrowserUse(),
    browser=browser,
)
```

### Change Fonts

Documented at https://forum.tagdiv.com/font-customization/

```python
agent = Agent(
    task=f"""
    Go to {site_url}/wp-admin.
    Navigate to Newspaper > Theme Panel > Theme Fonts.
    Select the desired font family and weights for each text element
    (Body text, Headings, Menu, etc.).
    Click Save Settings and wait for confirmation.
    """,
    llm=ChatBrowserUse(),
    browser=browser,
)
```

### Import a Pre-Built Website

```python
agent = Agent(
    task=f"""
    Go to {site_url}/wp-admin.
    Navigate to Newspaper > Theme Panel.
    Find the 'Pre-built Websites' or 'Demos' section.
    Browse or search for the demo you want to install.
    Click 'Install' or 'Import' on the selected pre-built website.
    Wait for the installation to complete (this may take several minutes).
    Confirm the installation was successful.
    WARNING: Installing a pre-built website will overwrite existing theme settings.
    """,
    llm=ChatBrowserUse(),
    browser=browser,
)
```

### Export/Import Theme Settings

Documented at https://forum.tagdiv.com/import-export-theme-settings/

```python
agent = Agent(
    task=f"""
    Go to {site_url}/wp-admin.
    Navigate to Newspaper > Theme Panel > Import/Export.
    To export: click inside the 'Export Theme Settings' box, select all (Ctrl+A),
    then copy (Ctrl+C). Save the copied text to a file.
    To import: paste the settings text into the 'Import Theme Settings' box,
    then click the 'Import Theme Settings' button.
    Wait for the import confirmation message.
    """,
    llm=ChatBrowserUse(),
    browser=browser,
)
```

### Inspect Current Theme Settings (Read-Only)

For diagnostics only — these DON'T modify settings:

```bash
# Read current theme state (inspection-only, not for modification)
wp option get td_theme_options --format=json | python3 -m json.tool
wp option get tdc_version
wp option get tds_white_menu
wp option get tds_footer_style
```

### Manage Cloud Templates (tdb_templates CPT)

Template management via REST API is OK — templates are WordPress custom post types, not theme settings:

```bash
# List templates
wp post list --post_type=tdb_templates --format=json

# Get template by type
wp post list --post_type=tdb_templates --meta_key=tdb_template_type --meta_value=header

# Export template assignments
wp post list --post_type=tdb_templates --format=csv --fields=ID,post_title,post_status > templates.csv
```

---

## Workflows & Patterns (browser-use)

### Complete Header/Footer Setup

1. Import header/footer templates from tagDiv Cloud Library via Theme Panel (browser-use)
2. Set as global defaults in the Theme Panel (browser-use)
3. Customize via tagDiv Composer (browser-use)

```python
agent = Agent(
    task=f"""
    Go to {site_url}/wp-admin.
    Navigate to Newspaper > Theme Panel.
    If you need templates from the Cloud Library:
      - Go to the 'Cloud Templates' tab
      - Browse or search for a header template
      - Click 'Import' on the desired template
      - Repeat for a footer template if needed
    To assign them globally:
      - Go to the 'Templates' or 'Website Manager' section
      - Set the imported header as the Global Header
      - Set the imported footer as the Global Footer
      - Save changes
    To further customize:
      - Go to the homepage
      - Click 'Edit with tagDiv Composer'
      - Modify elements in the header/footer as needed
      - Save
    """,
    llm=ChatBrowserUse(),
    browser=browser,
)
```

### Migrate Newspaper Theme Settings Between Sites

```python
agent = Agent(
    task=f"""
    On the SOURCE site ({source_url}/wp-admin):
      - Go to Newspaper > Theme Panel > Import/Export
      - In the 'Export Theme Settings' box, select all text and copy it
      - Save to a file

    On the DESTINATION site ({dest_url}/wp-admin):
      - Go to Newspaper > Theme Panel > Import/Export
      - Paste the settings text into the 'Import Theme Settings' box
      - Click 'Import Theme Settings'
      - Wait for confirmation
      - If using Cloud Library templates, re-import them:
        - Go to the 'Cloud Templates' or 'Cloud Library' section
        - Re-import any custom templates from Cloud Library
      - Verify the site looks correct
    """,
    llm=ChatBrowserUse(),
    browser=browser,
)
```

### Mobile-Specific Setup

Use the Theme Panel for mobile configuration:

```python
agent = Agent(
    task=f"""
    Go to {site_url}/wp-admin.
    Navigate to Newspaper > Theme Panel.
    Find the 'Mobile Theme' or 'Responsive' settings section.
    Configure:
      - Enable/disable mobile theme if desired
      - Set mobile-specific logo (upload a smaller version)
      - Configure mobile menu style
      - Enable/disable mobile search and social icons
    Save settings.
    Verify on a mobile viewport or by resizing the browser.
    """,
    llm=ChatBrowserUse(),
    browser=browser,
)
```

### Optimize Newspaper Performance

Use the Theme Panel for performance toggles:

```python
agent = Agent(
    task=f"""
    Go to {site_url}/wp-admin.
    Navigate to Newspaper > Theme Panel.
    Find performance-related settings:
      - Enable lazy loading for images
      - Enable CSS minification
      - Enable JS minification
      - Configure cache settings
    Save settings.
    If available, use the 'Clear Cache' or 'Regenerate CSS' option.
    Also clear any WordPress transients:
      wp transient delete --all
    """,
    llm=ChatBrowserUse(),
    browser=browser,
)
```

---

## Troubleshooting

- **"Template not applying"**: Check that the template `post_status` is `publish` and the `tdb_template_type` meta is set correctly. Assign it properly via the Theme Panel UI (browser-use). Avoid modifying `td_theme_options` directly.
- **"Composer not loading"**: This often means the nonce is expired or user is not logged in. The tagDiv Composer requires admin-level authentication. Use `BrowserProfile(storage_state_from_browser='chrome')` to reuse an already-logged-in session.
- **"Cloud Library connection failed"**: Verify the API key in Theme Panel → Cloud Templates. The API key is stored in `td_theme_options` → `tds_cloud_api_key` (read-only via `wp option get`).
- **"Logo not appearing after change"**: Check if an SVG logo is overriding the image — in the Header Logo settings, check the SVG tab and clear it if needed. Use browser-use to navigate the Composer and inspect the logo element settings.
- **Performance issues after import**: Clear all caches via Theme Panel, then run `wp transient delete --all`.
- **"White screen after updating theme options"**: This almost always happens when `td_theme_options` was edited directly via WP-CLI. Restore from a Theme Panel backup: go to Theme Panel > Import/Export and restore a previous version. Never hand-edit `td_theme_options`.
