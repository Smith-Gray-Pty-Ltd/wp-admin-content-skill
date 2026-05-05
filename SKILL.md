---
name: wp-admin-content
description: Manage WordPress sites via REST API and WP-CLI — administer users, plugins, themes, content, security, and extendable plugin ecosystems including WooCommerce, LifterLMS, and Newspaper theme.
license: MIT
compatibility: opencode
---

## What I do
- Manage WordPress sites via REST API and WP-CLI
- Create, edit, publish, and organize content (posts, pages, media, custom post types)
- Administer users, roles, permissions, and settings
- Install, activate, update, and configure plugins and themes
- Audit and harden WordPress security
- Manage extendable plugin ecosystems: WooCommerce, LifterLMS, Newspaper theme, and more
- Interact with the WordPress admin UI via browser-use for visual builders, settings wizards, and drag-and-drop editors
- Perform site migrations, backups, and health monitoring
- Automate repetitive WordPress administration tasks

## Authentication

WordPress supports two primary programmatic interfaces. Use the right one for the task.

### REST API — Application Passwords (Preferred)

Application Passwords are available in WordPress 5.6+. Generate one per user at:
`Users → Profile → Application Passwords` (or `/wp-admin/profile.php`)

```bash
# Credentials format
WP_SITE="https://example.com"
WP_USER="admin"
WP_APP_PASSWORD="abcd EFGH 1234 ijkl MNOP 5678"

# The password is sent as-is (spaces included) via Basic Auth
# Username: the WordPress username
# Password: the application password (with spaces)

# Test auth
curl -s -u "$WP_USER:$WP_APP_PASSWORD" \
  "$WP_SITE/wp-json/wp/v2/users/me" | python3 -m json.tool
```

Always prompt the user for their site URL, username, and application password. Store these as env vars. Never commit credentials.

#### Auth variants
- **Nonce/Cookie auth** — for plugins that require admin-ajax.php; send a GET to the login page first, extract `_wpnonce`, then POST with cookie + nonce
- **JWT plugins** — if a JWT plugin is active (e.g., "JWT Authentication for WP REST API"), use Bearer tokens instead
- **OAuth2** — some managed WP hosts gate the REST API behind OAuth2; check the hosting provider's API docs

### WP-CLI — SSH Access

WP-CLI requires shell access to the server where WordPress is installed.

```bash
# Connect and verify
ssh user@host "wp --path=/path/to/wordpress core version"

# For local dev
wp core version
```

WP-CLI should be used for bulk operations, database work, and anything the REST API is slow at.

### When to use which

| Task | Use |
|------|-----|
| CRUD posts/pages/media | REST API |
| Bulk database operations | WP-CLI |
| Plugin/theme install | WP-CLI |
| Settings read/write | REST API or WP-CLI |
| User management | REST API or WP-CLI |
| Search-replace URLs during migration | WP-CLI only |
| Cron management | WP-CLI only |
| Content export/import | WP-CLI or REST API |
| Visual builders (tagDiv Composer, Elementor) | browser-use |
| Plugin settings wizards (WooCommerce setup, LifterLMS) | browser-use |
| Admin UI workflows that lack REST endpoints | browser-use |

---

## Browser Automation via browser-use

For tasks that require interacting with the WordPress admin UI — visual page builders, settings wizards, drag-and-drop editors, or any admin screen that lacks a REST API — use **browser-use**, an AI-driven browser automation framework.

```bash
pip install browser-use
python -m playwright install chromium
```

The agent describes what it wants in natural language ("log in to wp-admin, go to WooCommerce > Settings, enable Stripe"). browser-use handles login, navigation, AJAX waits, and error recovery — far more resilient than hardcoded Playwright selectors.

```python
from browser_use import Agent, Browser, ChatBrowserUse
import asyncio

async def main():
    agent = Agent(
        task="Go to https://example.com/wp-login.php, "
             "log in as admin, navigate to Settings > General, "
             "change site title to 'My New Blog', and save.",
        llm=ChatBrowserUse(),
        browser=Browser(),
    )
    await agent.run()

asyncio.run(main())
```

To avoid re-authentication on every run, reuse a Chrome profile:

```python
from browser_use import BrowserProfile
profile = BrowserProfile(storage_state_from_browser='chrome')
browser = Browser(profile=profile)
```

See `guides/browser-automation.md` for the full browser-use reference, WordPress-specific recipe patterns, the Playwright fallback guide, and the decision table for when to use browser-use vs REST API vs WP-CLI.

---

## Quick Reference: Common Operations

```bash
# === Posts ===
curl -s -u "$WP_USER:$WP_APP_PASSWORD" \
  "$WP_SITE/wp-json/wp/v2/posts?per_page=5&status=publish"

curl -s -X POST -u "$WP_USER:$WP_APP_PASSWORD" \
  -H "Content-Type: application/json" \
  -d '{"title":"Hello World","content":"<!-- wp:paragraph --><p>Content here</p><!-- /wp:paragraph -->","status":"draft"}' \
  "$WP_SITE/wp-json/wp/v2/posts"

# === Pages ===
curl -s -u "$WP_USER:$WP_APP_PASSWORD" \
  "$WP_SITE/wp-json/wp/v2/pages?per_page=10&parent=0"

# === Media upload ===
curl -s -X POST -u "$WP_USER:$WP_APP_PASSWORD" \
  -F "file=@/path/to/image.jpg" \
  -F "title=My Image" \
  -F "alt_text=Description of image" \
  "$WP_SITE/wp-json/wp/v2/media"

# === Users ===
curl -s -u "$WP_USER:$WP_APP_PASSWORD" \
  "$WP_SITE/wp-json/wp/v2/users?roles=administrator"

# === Settings ===
curl -s -u "$WP_USER:$WP_APP_PASSWORD" \
  "$WP_SITE/wp-json/wp/v2/settings"

curl -s -X POST -u "$WP_USER:$WP_APP_PASSWORD" \
  -H "Content-Type: application/json" \
  -d '{"title":"New Site Title","timezone":"America/New_York"}' \
  "$WP_SITE/wp-json/wp/v2/settings"

# === Plugins (WP-CLI) ===
wp plugin list --format=json
wp plugin install woocommerce --activate
wp plugin update --all
wp plugin deactivate broken-plugin && wp plugin delete broken-plugin

# === Themes (WP-CLI) ===
wp theme list --format=json
wp theme install generatepress --activate
wp theme update --all
```

---

## Core WordPress REST API — Endpoint Reference

Base path: `/wp-json/wp/v2/`

### Posts (`/posts`)

```bash
GET    /wp/v2/posts                           # List posts
GET    /wp/v2/posts?per_page=100&page=2       # Paginate
GET    /wp/v2/posts?status=draft,future       # Filter by status
GET    /wp/v2/posts?categories=5,12           # Filter by category
GET    /wp/v2/posts?search=keyword            # Search title + content
GET    /wp/v2/posts?after=2024-01-01T00:00:00 # Date range
GET    /wp/v2/posts?slug=my-post-slug         # Lookup by slug
POST   /wp/v2/posts                           # Create post
GET    /wp/v2/posts/{id}                      # Get single post
PUT    /wp/v2/posts/{id}                      # Update post (full replace)
PATCH  /wp/v2/posts/{id}                      # Update post (partial)
DELETE /wp/v2/posts/{id}                      # Trash post
DELETE /wp/v2/posts/{id}?force=true           # Permanently delete
```

**Post object shape** (create/update):
```json
{
  "title": "Post Title",
  "content": "<!-- wp:paragraph --><p>Content</p><!-- /wp:paragraph -->",
  "excerpt": "Short description",
  "status": "draft|publish|pending|future|private",
  "date": "2024-06-15T09:00:00",
  "slug": "custom-url-slug",
  "categories": [5, 12],
  "tags": [3, 7],
  "featured_media": 456,
  "meta": {},
  "template": ""
}
```

### Pages (`/pages`)

```bash
GET    /wp/v2/pages                    # List pages
GET    /wp/v2/pages?parent=0           # Top-level pages only
GET    /wp/v2/pages?parent={id}        # Children of a page
POST   /wp/v2/pages                    # Create page
PUT    /wp/v2/pages/{id}               # Update page
```

### Media (`/media`)

```bash
GET    /wp/v2/media                     # List media items
GET    /wp/v2/media?media_type=image    # Images only
GET    /wp/v2/media?search=filename     # Search by name
POST   /wp/v2/media                     # Upload file (multipart/form-data)
PUT    /wp/v2/media/{id}                # Update metadata (alt text, caption)
DELETE /wp/v2/media/{id}?force=true     # Permanently delete
```

**Image sizes**: After upload, the response includes `media_details.sizes` (thumbnail, medium, large, full, and any custom sizes registered by themes/plugins).

### Categories (`/categories`)

```bash
GET    /wp/v2/categories                 # List all categories
GET    /wp/v2/categories?parent=0        # Top-level only
GET    /wp/v2/categories?search=term     # Search categories
POST   /wp/v2/categories                 # Create category
PUT    /wp/v2/categories/{id}            # Update category
```

### Tags (`/tags`)

```bash
GET    /wp/v2/tags                       # List all tags
POST   /wp/v2/tags                       # Create tag
```

### Users (`/users`)

```bash
GET    /wp/v2/users                       # List users
GET    /wp/v2/users?roles=administrator   # Filter by role
GET    /wp/v2/users?search=email_or_name  # Search users
GET    /wp/v2/users/me                    # Current user
POST   /wp/v2/users                       # Create user
PUT    /wp/v2/users/{id}                  # Update user
DELETE /wp/v2/users/{id}?reassign={uid}   # Delete user, reassign content
```

**User roles**: `administrator`, `editor`, `author`, `contributor`, `subscriber`, plus any custom roles.

### Comments (`/comments`)

```bash
GET    /wp/v2/comments                     # List comments
GET    /wp/v2/comments?post={id}           # Comments on a post
GET    /wp/v2/comments?status=hold         # Pending moderation
POST   /wp/v2/comments                     # Create comment
PUT    /wp/v2/comments/{id}                # Update/approve
DELETE /wp/v2/comments/{id}?force=true     # Permanently delete
```

### Settings (`/settings`)

```bash
GET    /wp/v2/settings                    # Read all settings
POST   /wp/v2/settings                    # Update settings
```

**Common settings**: `title`, `description`, `timezone`, `date_format`, `time_format`, `start_of_week`, `use_smilies`, `default_category`, `default_post_format`, `posts_per_page`, `show_on_front`, `page_on_front`, `page_for_posts`.

### Taxonomy & Post Type Discovery

```bash
GET    /wp/v2/taxonomies                  # All registered taxonomies
GET    /wp/v2/taxonomies/{taxonomy}        # Single taxonomy details
GET    /wp/v2/types                       # All registered post types
GET    /wp/v2/types/{post_type}            # Single post type details
```

This is how you discover custom post types (e.g., `product`, `course`, `lesson`) and their REST routes.

### Blocks (`/blocks`)

```bash
GET    /wp/v2/blocks                      # List reusable blocks
POST   /wp/v2/blocks                      # Create reusable block
PUT    /wp/v2/blocks/{id}                 # Update reusable block

GET    /wp/v2/block-renderer              # Render a block server-side
POST   /wp/v2/block-renderer?name=core/paragraph&post_id=1&context=view
```

### Search

```bash
GET    /wp/v2/search?search=keyword&type=post&subtype=post,page,product
```

Returns posts, pages, and custom post types matching the keyword.

### Site Health

```bash
GET    /wp-json/wp-site-health/v1/tests/{slug}
GET    /wp-json/wp-site-health/v1/directory-sizes
```

---

## WP-CLI — Command Reference

### Core Management

```bash
wp core version                          # WordPress version
wp core version --extra                  # WP + DB + PHP versions
wp core update                           # Update to latest
wp core update --version=6.4.3 --force   # Update to specific version
wp core update-db                        # Run database upgrade
wp core verify-checksums                 # Verify core file integrity
wp core is-installed                     # Check if WP is installed
wp core install --url=example.com --title="Site" --admin_user=admin --admin_password=pass --admin_email=admin@example.com
wp core multisite-install ...
```

### Database Management

```bash
wp db export                             # Export database (writes to STDOUT or file)
wp db export backup.sql                  # Export to file
wp db import backup.sql                  # Import from file
wp db optimize                           # Optimize all tables
wp db repair                             # Repair all tables
wp db check                              # Check tables for errors
wp db search <search> [<replace>]        # Search the database
wp search-replace 'http://old.com' 'https://new.com' --dry-run
wp search-replace 'http://old.com' 'https://new.com' --all-tables
wp search-replace 'http://old.com' 'https://new.com' --all-tables --precise --export=result.sql
```

### Options (`wp_options` table)

```bash
wp option list                           # List all options
wp option list --search=woocommerce      # Filter by key
wp option get siteurl                    # Get a single option
wp option get blogname                   # Site title
wp option get admin_email                # Admin email
wp option get active_plugins --format=json
wp option get timezone_string
wp option update blogname "New Title"
wp option update permalink_structure "/%postname%/"
wp option delete transient_option_name
wp transient list
wp transient delete --all
```

### Users

```bash
wp user list --format=json
wp user list --role=administrator
wp user create jsmith jsmith@example.com --role=editor --user_pass=generated_password
wp user update 3 --role=administrator
wp user update 3 --display_name="John Smith"
wp user reset-password 3
wp user delete 3 --reassign=1
wp user meta list 3
wp user meta get 3 wp_capabilities
wp user meta update 3 custom_field "value"
wp user session list <user>
wp user session destroy <user> --all
```

### Posts & Content

```bash
wp post list --format=json
wp post list --post_type=page --post_status=publish
wp post list --category_name=news --posts_per_page=20
wp post create --post_type=post --post_title="Title" --post_content="Content" --post_status=draft
wp post update 123 --post_status=publish
wp post delete 123 --force
wp post meta list 123
wp post meta get 123 _thumbnail_id
wp post meta update 123 custom_field "value"
wp post generate --count=50 --post_type=post    # Generate lorem ipsum test content
```

### Media

```bash
wp media import /path/to/image.jpg --title="My Image" --alt="Description"
wp media import /path/to/image.jpg --post_id=123 --featured_image
wp media list --format=json
wp media regenerate --only-missing            # Regenerate thumbnails
wp media regenerate --yes                     # Regenerate all thumbnails
```

### Plugins

```bash
wp plugin list --format=json
wp plugin list --status=active
wp plugin list --status=inactive
wp plugin search woocommerce
wp plugin install woocommerce --activate
wp plugin install https://example.com/plugin.zip
wp plugin update --all
wp plugin update woocommerce akismet
wp plugin deactivate plugin-name
wp plugin activate plugin-name
wp plugin delete plugin-name
wp plugin verify-checksums --all
wp plugin get plugin-name                   # Plugin details
```

### Themes

```bash
wp theme list --format=json
wp theme search generatepress
wp theme install generatepress --activate
wp theme update --all
wp theme delete twentytwentythree
wp scaffold child-theme my-child --parent=generatepress --theme_name="My Child Theme"
```

### Cron Events

```bash
wp cron event list
wp cron event run wp_privacy_delete_old_export_files
wp cron event run --due-now
wp cron event schedule --hook=my_custom_hook --when="+1 hour"
wp cron event delete my_custom_hook
```

### Rewrite Rules

```bash
wp rewrite flush              # Flush permalinks (important after CPT registration)
wp rewrite structure '/%postname%/'
wp rewrite list
```

### Maintenance Mode

```bash
wp maintenance-mode status
wp maintenance-mode activate
wp maintenance-mode deactivate
```

### Transients & Cache

```bash
wp cache flush
wp cache type
wp transient list
wp transient delete --all
wp transient delete --expired
```

### Config Generation

```bash
wp config create --dbname=mydb --dbuser=root --dbpass=password --dbhost=localhost
wp config get DB_NAME
wp config set WP_DEBUG true --raw
wp config set WP_DEBUG_LOG true --raw
wp config set WP_DEBUG_DISPLAY false --raw
wp config set DISALLOW_FILE_EDIT true --raw
wp config set DISALLOW_FILE_MODS true --raw
```

### Import / Export

```bash
wp export --dir=/tmp/exports/             # Export all content to WXR
wp export --post_type=post --author=3     # Export specific content
wp import example.wordpress.2016-06-21.xml --authors=create
```

### Scaffolding

```bash
wp scaffold plugin my-plugin
wp scaffold child-theme my-child --parent=twentytwentyfour
wp scaffold post-type my-cpt --theme=my-theme
wp scaffold taxonomy genre --post_type=book
wp scaffold block my-block --title="My Block"
```

### Server / Diagnostics

```bash
wp eval 'echo PHP_VERSION;'
wp eval 'echo ini_get("memory_limit");'
wp eval-file diagnose.php
```

---

## Plugin & Theme Management Patterns

### Installing and Activating

```bash
# WP-CLI (preferred)
wp plugin install woocommerce --activate
wp plugin install lifterlms --version=7.5.0 --activate

# Via REST API — note: install is WP-CLI only.
# REST API can only activate/deactivate already-installed plugins
curl -s -X PUT -u "$WP_USER:$WP_APP_PASSWORD" \
  -H "Content-Type: application/json" \
  -d '{"status":"active"}' \
  "$WP_SITE/wp-json/wp/v2/plugins/woocommerce/woocommerce"
```

### Auditing Plugins

```bash
# 1. List all plugins with versions
wp plugin list --format=json | python3 -c "
import json,sys
plugins=json.load(sys.stdin)
for p in plugins:
    print(f'{p[\"name\"]:30} v{p[\"version\"]:10} {\"ACTIVE\" if p[\"status\"]==\"active\" else \"INACTIVE\"} {\"UPDATE AVAIL\" if p[\"update\"]==\"available\" else \"up to date\"}')"

# 2. Verify file integrity
wp plugin verify-checksums --all

# 3. Check for abandoned plugins (no update in 2+ years)
# Compare 'last_updated' from wp plugin list --fields=name,last_updated

# 4. Find orphaned plugin data
wp option list --search=plugin_prefix --format=json
```

### Auto-Update Policy

```bash
# Enable auto-updates for all plugins
wp plugin auto-updates enable --all

# Enable for specific plugins only
wp plugin auto-updates enable woocommerce

# Disable for a specific plugin
wp plugin auto-updates disable plugin-name

# Core auto-update policy
wp config set WP_AUTO_UPDATE_CORE minor --raw
```

### Theme Customization

```bash
# Theme mods (customizer settings)
wp theme mod get custom_logo
wp theme mod set primary_color "#1a73e8"

# Custom CSS
wp post create --post_type=custom_css --post_title="My CSS" --post_content="body { font-family: sans-serif; }"

# Menus
wp menu list
wp menu create "Main Menu"
wp menu item add-post "Main Menu" 123
wp menu location assign "Main Menu" primary
```

---

## Content Management Workflows

### Creating a Post with Gutenberg Blocks

Gutenberg stores content as HTML with block comments. When creating content via the REST API, use the block comment format:

```bash
BLOCK_CONTENT='<!-- wp:paragraph -->
<p>First paragraph of the post.</p>
<!-- /wp:paragraph -->

<!-- wp:heading {"level":2} -->
<h2>A Section Heading</h2>
<!-- /wp:heading -->

<!-- wp:paragraph -->
<p>More content under the heading.</p>
<!-- /wp:paragraph -->

<!-- wp:image {"id":456,"sizeSlug":"large"} -->
<figure class="wp-block-image size-large"><img src="https://example.com/wp-content/uploads/image.jpg" alt=""/></figure>
<!-- /wp:image -->

<!-- wp:list -->
<ul><li>Item one</li><li>Item two</li></ul>
<!-- /wp:list -->'

curl -s -X POST -u "$WP_USER:$WP_APP_PASSWORD" \
  -H "Content-Type: application/json" \
  -d "{\"title\":\"My Post\",\"content\":$(echo "$BLOCK_CONTENT" | python3 -c 'import json,sys; print(json.dumps(sys.stdin.read()))'),\"status\":\"draft\",\"categories\":[5],\"tags\":[3]}" \
  "$WP_SITE/wp-json/wp/v2/posts"
```

### Batch Operations

```bash
# Publish all drafts that meet criteria
POST_IDS=$(wp post list --post_status=draft --post_type=post --format=ids)
for id in $POST_IDS; do
  wp post update "$id" --post_status=publish
  echo "Published post $id"
done

# Add a category to all posts without one
for id in $(wp post list --post_type=post --format=ids); do
  CATEGORIES=$(wp post term list "$id" category --format=ids)
  if [ -z "$CATEGORIES" ]; then
    wp post term add "$id" category 1
    echo "Added default category to post $id"
  fi
done
```

### Media Management

```bash
# Bulk upload images and attach to posts
for img in /path/to/images/*.jpg; do
  ATTACHMENT_ID=$(wp media import "$img" --porcelain)
  echo "Uploaded $img as attachment $ATTACHMENT_ID"
done

# Find unused media (not attached to any post)
wp db query "SELECT ID, post_title FROM wp_posts WHERE post_type='attachment' AND post_parent=0 AND post_mime_type LIKE 'image/%'"

# Regenerate thumbnails after changing theme/sizes
wp media regenerate --yes
```

### SEO Metadata (Yoast / Rank Math)

```bash
# Yoast SEO meta fields
curl -s -X POST -u "$WP_USER:$WP_APP_PASSWORD" \
  -H "Content-Type: application/json" \
  -d '{"meta":{"_yoast_wpseo_title":"Custom SEO Title","_yoast_wpseo_metadesc":"Custom meta description","_yoast_wpseo_focuskw":"target keyword"}}' \
  "$WP_SITE/wp-json/wp/v2/posts/123"

# Rank Math meta fields use rank_math_ prefix
# meta: { "rank_math_title": "...", "rank_math_description": "...", "rank_math_focus_keyword": "..." }
```

---

## Plugin Modules (Extendable)

This skill supports an extendable set of major plugins/themes. Each lives in `plugins/{slug}.md` and follows a standard template. See `plugins/_template.md` for the full template.

### Currently Supported

| Plugin/Theme | File | Slug |
|---|---|---|
| WooCommerce | `plugins/woocommerce.md` | woocommerce |
| LifterLMS | `plugins/lifterlms.md` | lifterlms |
| Newspaper Theme (tagDiv) | `plugins/newspaper-theme.md` | newspaper |

### Adding a New Plugin Module

1. Copy `plugins/_template.md` to `plugins/{slug}.md`
2. Fill in: authentication, REST endpoints, WP-CLI commands, common workflows, database tables
3. Add it to the table above
4. Load the module when the user mentions that plugin

---

## Security & Hardening

### Quick Security Audit

```bash
# 1. Verify core file integrity
wp core verify-checksums

# 2. Verify plugin file integrity
wp plugin verify-checksums --all

# 3. Check for inactive plugins (remove them)
wp plugin list --status=inactive

# 4. Check for inactive themes (keep only one fallback)
wp theme list --status=inactive

# 5. Check user accounts
wp user list --role=administrator

# 6. Check that DISALLOW_FILE_EDIT is set
wp config get DISALLOW_FILE_EDIT

# 7. Check debug mode is off in production
wp config get WP_DEBUG
```

### Recommended wp-config.php Constants

```bash
wp config set DISALLOW_FILE_EDIT true --raw
wp config set DISALLOW_FILE_MODS true --raw   # Only if you manage plugins via WP-CLI
wp config set FORCE_SSL_ADMIN true --raw
wp config set WP_AUTO_UPDATE_CORE minor --raw
wp config set WP_POST_REVISIONS 5 --raw        # Limit revisions (or false to disable)
```

### Two-Factor Authentication

```bash
# Install and configure 2FA plugin
wp plugin install two-factor --activate

# Force 2FA for administrators only
wp option update two_factor_forced_roles '["administrator"]'

# Check which users have 2FA configured
wp user list --format=json | python3 -c "
import json,sys
users=json.load(sys.stdin)
for u in users:
    print(f'{u[\"user_login\"]:20} {u[\"roles\"]}')"
```

### XML-RPC

```bash
# Check if XML-RPC is enabled
curl -s -X POST "$WP_SITE/xmlrpc.php" -d '<methodCall><methodName>demo.sayHello</methodName></methodCall>'

# Disable via WP-CLI (if plugin available)
wp plugin install disable-xml-rpc --activate

# Or disable via functions.php / .htaccess
```

### User Enumeration Prevention

Check: `GET /wp-json/wp/v2/users` — this endpoint lists users by default. To restrict, use a security plugin or custom code.

### Backup Strategy

```bash
# Quick database backup
wp db export "$(date +%Y%m%d)-backup.sql"

# Full content export (WXR)
wp export --dir="./exports/$(date +%Y%m%d)/"

# Restore from backup
wp db import backup.sql
wp search-replace 'https://old-domain.com' 'https://new-domain.com' --all-tables
wp rewrite flush
wp cache flush
```

See `guides/security-hardening.md` for the full hardening guide.

---

## Browser Automation (browser-use)

For tasks that require the WordPress admin UI (tagDiv Composer, Customizer, settings wizards), use browser-use — an AI-driven framework that handles login, navigation, AJAX waits, and error recovery from natural language descriptions. See `guides/browser-automation.md` for the full guide with WordPress recipe patterns and the Playwright fallback reference.

---

## Site Migration Workflow

```bash
# SOURCE SERVER
# 1. Export database
wp db export migration-source.sql

# 2. Export files (rsync or download wp-content)
rsync -avz /path/to/wp-content/uploads/ user@destination:/path/to/wp-content/uploads/
rsync -avz /path/to/wp-content/plugins/ user@destination:/path/to/wp-content/plugins/
rsync -avz /path/to/wp-content/themes/ user@destination:/path/to/wp-content/themes/

# DESTINATION SERVER
# 3. Copy wp-config.php (update DB credentials)
# 4. Import database
wp db import migration-source.sql

# 5. Search-replace URLs
wp search-replace 'https://old-domain.com' 'https://new-domain.com' --all-tables --precise

# 6. Flush caches and permalinks
wp rewrite flush
wp cache flush
wp transient delete --all

# 7. Verify
wp core version
wp plugin list --status=active
wp option get siteurl
```

See `guides/site-migration.md` for full migration guide.

---

## Health Monitoring

```bash
# Quick health check
wp core version
wp core verify-checksums
wp db check
wp option get siteurl
wp option get home

# PHP info
wp eval 'echo "PHP: " . PHP_VERSION . "\nMemory: " . ini_get("memory_limit") . "\nMax Upload: " . ini_get("upload_max_filesize") . "\n";'

# Check for stuck crons
wp cron event list

# Disk usage for uploads
wp eval 'echo size_format(disk_total_space(WP_CONTENT_DIR . "/uploads")) . " total, " . size_format(disk_free_space(WP_CONTENT_DIR . "/uploads")) . " free\n";'

# Site Health via REST API
curl -s -u "$WP_USER:$WP_APP_PASSWORD" \
  "$WP_SITE/wp-json/wp-site-health/v1/tests/background-updates"
```

---

## When to use me
- User asks to create, edit, publish, or manage WordPress content
- User wants to install, update, activate, or audit plugins/themes
- User needs to manage users, roles, permissions, or settings
- User asks about WordPress security, hardening, or vulnerability scanning
- User is migrating a site, backing up, or restoring from backup
- User wants to automate repetitive WordPress tasks
- User mentions WooCommerce, LifterLMS, Newspaper theme, or any supported plugin
- User says anything about "WordPress admin," "WP dashboard," or "WP backend"

Base directory for this skill: `plugins/`, `guides/`, `scripts/`
Relative paths in this skill are relative to the skill's base directory.
