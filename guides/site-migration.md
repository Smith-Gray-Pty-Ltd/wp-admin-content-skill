# WordPress Site Migration Guide

## Overview

Migrating a WordPress site involves three components:
1. **Database** — posts, pages, settings, users, plugin data
2. **Files** — wp-content (uploads, plugins, themes), wp-config.php
3. **Configuration** — domain name, SSL, server settings

---

## Standard Migration (Source → Destination)

### Step 1: Export from Source

```bash
# On the source server
SOURCE_PATH="/var/www/source-site"

# 1a. Export the database
wp db export /tmp/migration-$(date +%Y%m%d).sql

# 1b. Export the files (uploads, plugins, themes)
tar -czf /tmp/migration-files-$(date +%Y%m%d).tar.gz \
  -C "$SOURCE_PATH/wp-content" \
  uploads plugins themes

# 1c. Copy wp-config.php (will need editing on destination)
cp "$SOURCE_PATH/wp-config.php" /tmp/wp-config-source.php

echo "Export complete:"
ls -lh /tmp/migration-*
```

### Step 2: Prepare Destination

```bash
# On the destination server
DEST_PATH="/var/www/destination-site"

# 2a. Ensure WordPress is installed (use the same version as source)
wp core download --path="$DEST_PATH" --version=6.5.0

# 2b. Create wp-config.php with NEW database credentials
wp config create \
  --path="$DEST_PATH" \
  --dbname=new_database \
  --dbuser=new_user \
  --dbpass=new_password \
  --dbhost=localhost

# 2c. Install WordPress (creates tables)
wp core install \
  --path="$DEST_PATH" \
  --url="https://new-domain.com" \
  --title="Temporary Title" \
  --admin_user=tempadmin \
  --admin_password=temppass123 \
  --admin_email=temp@example.com

echo "Base WordPress installed at $DEST_PATH"
```

### Step 3: Transfer Files

```bash
# 3a. Copy the database export
scp user@source:/tmp/migration-*.sql "$DEST_PATH/"
cp /tmp/migration-*.sql "$DEST_PATH/"

# 3b. Copy and extract the files archive
scp user@source:/tmp/migration-files-*.tar.gz "$DEST_PATH/"
cp /tmp/migration-files-*.tar.gz "$DEST_PATH/"
tar -xzf "$DEST_PATH/migration-files-"*.tar.gz -C "$DEST_PATH/wp-content/"

# 3c. Set correct permissions
find "$DEST_PATH" -type d -exec chmod 755 {} \;
find "$DEST_PATH" -type f -exec chmod 644 {} \;
chmod 600 "$DEST_PATH/wp-config.php"
# Adjust ownership if necessary
# chown -R www-data:www-data "$DEST_PATH"

echo "Files transferred and permissions set"
```

### Step 4: Import Database

```bash
# 4a. Drop the temporary WordPress tables
wp db reset --path="$DEST_PATH" --yes

# 4b. Import the migration database
wp db import "$DEST_PATH/migration-"*.sql --path="$DEST_PATH"

# 4c. Update wp-config.php with the correct table prefix
# (check what prefix the imported database uses)
wp config set table_prefix "wp_" --path="$DEST_PATH"

echo "Database imported"
```

### Step 5: Search-Replace URLs

```bash
# 5a. Replace the old domain with the new one
wp search-replace \
  'https://old-domain.com' \
  'https://new-domain.com' \
  --path="$DEST_PATH" \
  --all-tables \
  --precise \
  --dry-run  # Remove --dry-run after reviewing

# 5b. Execute the actual replacement
wp search-replace \
  'https://old-domain.com' \
  'https://new-domain.com' \
  --path="$DEST_PATH" \
  --all-tables \
  --precise

# 5c. Also replace http:// if the old site wasn't fully HTTPS
wp search-replace \
  'http://old-domain.com' \
  'https://new-domain.com' \
  --path="$DEST_PATH" \
  --all-tables \
  --precise

echo "URLs updated"
```

### Step 6: Finalize

```bash
# 6a. Flush permalinks
wp rewrite flush --path="$DEST_PATH"

# 6b. Clear all caches
wp cache flush --path="$DEST_PATH"
wp transient delete --all --path="$DEST_PATH"

# 6c. Verify the site is working
curl -sI "https://new-domain.com" | head -5
curl -s "https://new-domain.com/wp-json/" | python3 -c "import json,sys; d=json.load(sys.stdin); print(f'WordPress {d.get(\"namespaces\",[\"unknown\"])}')"

# 6d. Clean up
rm "$DEST_PATH/migration-"*.sql "$DEST_PATH/migration-files-"*.tar.gz

echo "Migration complete. Visit https://new-domain.com to verify."
```

---

## Migration with Plugin Data (WooCommerce, LifterLMS)

When migrating sites with heavy plugin data:

```bash
# 1. Before export: clear plugin-specific transients
wp wc tool clear_transients
wp wc tool clear_expired_transients
wp wc tool clear_customer_sessions

# 2. Export with extended flags
wp db export /tmp/migration.sql --tables=$(wp db tables --all-tables-with-prefix | tr '\n' ',')

# 3. After import: rebuild plugin indexes
wp wc tool regenerate_product_lookup_tables
wp wc tool recount_terms
wp wc tool update_db

# For LifterLMS:
wp llms db update
```

---

## Multisite Migration

For WordPress multisite migrations, standard search-replace isn't enough. The domain mapping is stored in `wp_blogs` and `wp_site` tables.

```bash
# 1. Export the full multisite database
wp db export /tmp/multisite-migration.sql

# 2. Import on destination
wp db import /tmp/multisite-migration.sql

# 3. Search-replace (include all subsites)
wp search-replace 'old-domain.com' 'new-domain.com' --all-tables --network

# 4. Update site URLs in the network tables
wp site list --field=url | while read url; do
  NEW_URL=$(echo "$url" | sed 's/old-domain.com/new-domain.com/')
  wp site update $(wp site list --field=blog_id --url="$url") --url="$NEW_URL"
done

# 5. Rebuild network
wp core update-db --network
```

---

## Database-Only Migration (Same Files)

If you only need to move the database (e.g., staging → production with same files):

```bash
# Source: Export only the database
wp db export /tmp/prod-to-stage.sql

# Source: Transfer
scp /tmp/prod-to-stage.sql user@staging:/tmp/

# Destination: Import
wp db import /tmp/prod-to-stage.sql

# Destination: Search-replace
wp search-replace 'https://production.com' 'https://staging.com' --all-tables --precise

# Destination: Flush
wp rewrite flush
wp cache flush
wp transient delete --all
```

---

## Migration via Backup Plugins

### UpdraftPlus

```bash
# Trigger a manual backup
wp eval "do_action('updraftplus_backup');"

# List existing backups
wp updraftplus list-backups

# Restore from a specific backup set
wp updraftplus restore <backup_timestamp>

# Export backup files to remote storage
wp updraftplus existing_backups
```

### All-in-One WP Migration

```bash
# Export via WP-CLI (if supported by the plugin version)
wp ai1wm backup

# Or trigger via REST API / admin AJAX
curl -s -X POST -u "$WP_USER:$WP_APP_PASSWORD" \
  -d "action=ai1wm_export" \
  "$WP_SITE/wp-admin/admin-ajax.php"
```

### WP Migrate DB Pro

```bash
# Pull from remote to local
wp migratedb pull https://production.com <connection_key>

# Push from local to remote
wp migratedb push https://production.com <connection_key>

# Find and replace over a migration
wp migratedb find-replace --find="//old.com" --replace="//new.com"
```

---

## Post-Migration Checklist

Run this after every migration:

```bash
echo "=== Post-Migration Verification ==="

# 1. Site loads
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" "$WP_SITE")
echo "1. Site HTTP status: $HTTP_CODE (should be 200)"

# 2. Admin panel accessible
ADMIN_CODE=$(curl -s -o /dev/null -w "%{http_code}" -u "$WP_USER:$WP_APP_PASSWORD" "$WP_SITE/wp-json/wp/v2/users/me")
echo "2. Admin access: $ADMIN_CODE (should be 200)"

# 3. Permalinks working
curl -s -o /dev/null -w "%{http_code}" "$WP_SITE/sample-page"
echo "3. Permalinks: check a known page URL"

# 4. Plugins active as expected
ACTIVE_COUNT=$(wp plugin list --status=active --format=count)
echo "4. Active plugins: $ACTIVE_COUNT"

# 5. Theme active
wp theme list --status=active --field=name
echo "5. Active theme: $(wp theme list --status=active --field=name)"

# 6. Check for hardcoded old URLs
wp db query "SELECT COUNT(*) as count FROM wp_options WHERE option_value LIKE '%old-domain.com%'" --silent
echo "6. Old URL remnants in options: check above"

# 7. Site URL correct
echo "7. Site URL: $(wp option get siteurl)"
echo "   Home URL: $(wp option get home)"

# 8. Media files accessible
curl -s -o /dev/null -w "%{http_code}" "$WP_SITE/wp-content/uploads/"
echo "8. Uploads directory accessible"

# 9. SSL working (if applicable)
curl -sI "$WP_SITE" 2>&1 | grep -i "HTTP/2\|HTTP/1.1"
echo "9. SSL check"

# 10. Remove the temp admin if you created one
# wp user delete tempadmin --reassign=1

echo "=== Verification Complete ==="
```

---

## Rollback Plan

If the migration fails, have a rollback ready:

```bash
# Before migrating, create a rollback script
cat > rollback.sh << 'ROLLBACK'
#!/bin/bash
DEST_PATH="/var/www/destination-site"
BACKUP_DIR="/var/www/backups/pre-migration"

# Restore database
wp db import "$BACKUP_DIR/pre-migration.sql"

# Restore files
rm -rf "$DEST_PATH/wp-content/uploads" "$DEST_PATH/wp-content/plugins" "$DEST_PATH/wp-content/themes"
cp -r "$BACKUP_DIR/uploads" "$DEST_PATH/wp-content/"
cp -r "$BACKUP_DIR/plugins" "$DEST_PATH/wp-content/"
cp -r "$BACKUP_DIR/themes" "$DEST_PATH/wp-content/"

# Restore wp-config
cp "$BACKUP_DIR/wp-config.php" "$DEST_PATH/"

# Flush
wp rewrite flush
wp cache flush

echo "Rollback complete."
ROLLBACK

chmod +x rollback.sh
```

---

## Common Migration Issues

### Serialized Data

`wp search-replace` with `--all-tables` handles serialized data. If you use regular SQL find-and-replace, you'll corrupt serialized arrays. Always use WP-CLI.

### Large Databases

For databases over 1GB:

```bash
# Export in chunks
wp db export - | gzip > migration.sql.gz

# Import
gunzip < migration.sql.gz | wp db import -

# Or use mysqldump directly for more control
mysqldump -u user -p database_name --single-transaction --quick | gzip > migration.sql.gz
```

### Mixed HTTP/HTTPS

If the old site had mixed HTTP/HTTPS content:

```bash
# Replace all variations
wp search-replace 'http://old-domain.com' 'https://new-domain.com' --all-tables
wp search-replace 'https://old-domain.com' 'https://new-domain.com' --all-tables
wp search-replace '//old-domain.com' '//new-domain.com' --all-tables
```

### Different Table Prefix

If the source uses `wp_` but the destination uses `xyz_`:

```bash
# After import, rename tables first
wp db query "RENAME TABLE wp_posts TO xyz_posts" # repeat for all tables
# Then update the prefix
wp config set table_prefix "xyz_"
```
