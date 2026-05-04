# WordPress Security Hardening Guide

## Quick Audit (Run First)

```bash
# Full security audit in one script
echo "=== WordPress Security Audit ==="
echo ""

echo "1. Core file integrity:"
wp core verify-checksums 2>&1 || echo "  WARNING: Core files modified!"
echo ""

echo "2. Plugin file integrity:"
wp plugin verify-checksums --all 2>&1
echo ""

echo "3. WordPress version:"
wp core version
echo ""

echo "4. Inactive plugins (remove these):"
wp plugin list --status=inactive --format=csv --fields=name,version
echo ""

echo "5. Inactive themes (keep 1 fallback, remove rest):"
wp theme list --status=inactive --format=csv --fields=name,version
echo ""

echo "6. Admin users:"
wp user list --role=administrator --format=csv --fields=ID,user_login,user_email,display_name
echo ""

echo "7. Debug mode:"
wp config get WP_DEBUG 2>/dev/null || echo "  Not set (defaults to false)"
echo ""

echo "8. File editing:"
DISALLOW=$(wp config get DISALLOW_FILE_EDIT 2>/dev/null || echo "not set")
echo "  DISALLOW_FILE_EDIT = $DISALLOW (should be true)"
echo ""

echo "9. XML-RPC status:"
curl -s -o /dev/null -w "%{http_code}" "$WP_SITE/xmlrpc.php"
echo " (anything but 405 indicates XML-RPC is accessible)"
echo ""

echo "10. Auto-update status:"
wp config get WP_AUTO_UPDATE_CORE 2>/dev/null || echo "  Not set"
echo ""
```

## wp-config.php Hardening

### Required Constants

```bash
# Disable file editing from admin panel
wp config set DISALLOW_FILE_EDIT true --raw

# Force SSL for admin and login
wp config set FORCE_SSL_ADMIN true --raw

# Only auto-update minor/core versions (not plugins/themes by default)
wp config set WP_AUTO_UPDATE_CORE minor --raw

# Limit post revisions
wp config set WP_POST_REVISIONS 5 --raw

# Increase autosave interval (reduce DB writes)
wp config set AUTOSAVE_INTERVAL 300 --raw

# Empty trash after 30 days
wp config set EMPTY_TRASH_DAYS 30 --raw
```

### Optional Security Constants

```bash
# Disable plugin/theme install/update from admin (manage via WP-CLI)
wp config set DISALLOW_FILE_MODS true --raw

# Force SSL for the whole site (if you have SSL)
wp config set FORCE_SSL_LOGIN true --raw

# Disable WP-Cron — use system cron instead (better performance)
wp config set DISABLE_WP_CRON true --raw
# Then set up system cron: */5 * * * * wp cron event run --due-now
```

### Block Access to Sensitive Files (.htaccess)

```apache
# Protect wp-config.php
<Files wp-config.php>
    Order allow,deny
    Deny from all
</Files>

# Protect .htaccess itself
<Files .htaccess>
    Order allow,deny
    Deny from all
</Files>

# Block PHP execution in uploads
<Directory "/wp-content/uploads">
    <Files "*.php">
        Order allow,deny
        Deny from all
    </Files>
</Directory>

# Disable directory listing
Options -Indexes

# Block XML-RPC (if not using the mobile app or Jetpack)
<Files "xmlrpc.php">
    Order allow,deny
    Deny from all
</Files>
```

### Nginx Equivalent

```nginx
# Block access to sensitive files
location ~* /wp-config.php { deny all; }
location ~* /xmlrpc.php { deny all; }
location ~* ^/wp-content/uploads/.*\.php$ { deny all; }

# Disable directory listing
autoindex off;
```

## File Permissions

```bash
# Recommended permissions
# Directories: 755
# Files: 644
# wp-config.php: 600 or 640

# Set all directories to 755
find /path/to/wordpress -type d -exec chmod 755 {} \;

# Set all files to 644
find /path/to/wordpress -type f -exec chmod 644 {} \;

# Lock down wp-config.php
chmod 600 /path/to/wordpress/wp-config.php

# Lock down .htaccess
chmod 644 /path/to/wordpress/.htaccess

# Secure wp-content (if web server runs as different user)
chown -R www-data:www-data /path/to/wordpress/wp-content/uploads
```

## WordPress Salts & Keys

```bash
# Generate new salts (use the WordPress.org secret-key service)
curl -s https://api.wordpress.org/secret-key/1.1/salt/

# Update salts via WP-CLI
wp config shuffle-salts
```

This invalidates all existing login cookies — users will need to log in again. Use when you suspect a compromise.

## Two-Factor Authentication

```bash
# Install 2FA plugin
wp plugin install two-factor --activate

# Check if 2FA is available for users
wp eval "var_dump(class_exists('Two_Factor_Core'));"

# The Two-Factor plugin makes 2FA available in user profiles.
# Users enable it at: Users > Profile > Two-Factor Options

# Force 2FA for all admin users (requires custom code or plugin)
# Consider: wp plugin install wp-2fa --activate
wp plugin install wp-2fa --activate
# Then configure who must use 2FA (e.g., admins only)
```

## Login Protection

```bash
# 1. Install login protection plugin (Wordfence or Limit Login Attempts)
wp plugin install limit-login-attempts-reloaded --activate

# 2. Change login URL (hide wp-login.php)
wp plugin install wps-hide-login --activate
# Then: Settings > Permalinks, the new login URL appears

# 3. Check login page is not enumerating users
curl -s "$WP_SITE/?author=1" -o /dev/null -w "%{redirect_url}"
# If it redirects to /author/admin/, user enumeration is possible
```

## Database Security

```bash
# 1. Change the table prefix from wp_ (must be done at install time)
# If already installed, use:
# wp search-replace 'wp_' 'newprefix_' --all-tables --dry-run
# WARNING: This affects everything — backup first

# 2. Check for orphaned user meta
wp user list --format=ids | while read uid; do
  echo "User $uid capabilities:"
  wp user meta get "$uid" wp_capabilities
done

# 3. Remove unused user roles/capabilities
wp role list

# 4. Check for suspicious admin users
wp db query "SELECT ID, user_login, user_email, user_registered FROM wp_users ORDER BY ID"
```

## Plugin Security

```bash
# 1. Remove all inactive plugins
wp plugin delete $(wp plugin list --status=inactive --field=name)

# 2. Keep only one default theme (for fallback)
wp theme list --status=inactive --field=name
# Keep twenty* latest, delete the rest
wp theme delete twentytwentythree

# 3. Check plugins for vulnerabilities
# Use WPScan (requires API token)
wpscan --url "$WP_SITE" --api-token "$WPSCAN_TOKEN" --plugins-detection aggressive

# 4. Enable auto-updates for security-only releases
wp plugin update --all
```

## API & REST Protection

```bash
# 1. Check what REST endpoints are publicly accessible
curl -s "$WP_SITE/wp-json/" | python3 -m json.tool

# 2. Check if user list is exposed
curl -s "$WP_SITE/wp-json/wp/v2/users" | python3 -c "
import json,sys
users=json.load(sys.stdin)
if len(users)>0:
    print(f'WARNING: {len(users)} users exposed via REST API')
    for u in users:
        print(f'  - {u[\"name\"]} ({u[\"slug\"]})')
else:
    print('OK: No users exposed')"

# 3. Disable REST user endpoints (requires code or plugin)
# Plugin: wp plugin install disable-json-api --activate
# Custom: add_filter('rest_endpoints', function($endpoints) {
#   if (isset($endpoints['/wp/v2/users'])) {
#     unset($endpoints['/wp/v2/users']);
#   }
#   return $endpoints;
# });
```

## Headers & HSTS

Add or verify these response headers:

```bash
curl -sI "$WP_SITE" | grep -iE "x-frame|x-content|x-xss|strict-transport|referrer-policy|x-powered"

# Expected:
# X-Frame-Options: SAMEORIGIN
# X-Content-Type-Options: nosniff
# X-XSS-Protection: 1; mode=block
# Strict-Transport-Security: max-age=31536000
# Referrer-Policy: no-referrer-when-downgrade
# No X-Powered-By header (hide PHP version)
```

To add headers, configure them in .htaccess, nginx config, or use a security plugin like Wordfence.

## Backup Verification

```bash
# 1. Ensure backups exist and are recent
ls -la /path/to/backups/

# 2. Test that a DB export works
wp db export /tmp/test-backup-$(date +%Y%m%d).sql
echo "Backup size: $(wc -c < /tmp/test-backup-$(date +%Y%m%d).sql) bytes"

# 3. Check if backup plugin is active and configured
wp plugin list | grep -iE "updraft|backup|backupbuddy|blogvault"

# 4. Verify backup file integrity
gzip -t /path/to/backup.sql.gz 2>/dev/null && echo "Backup valid" || echo "INVALID BACKUP"
```

## Incident Response Checklist

If a site is suspected of being compromised:

```bash
# 1. Take the site offline (maintenance mode)
wp maintenance-mode activate

# 2. Export the current state for forensics
wp db export "forensics-$(date +%Y%m%d-%H%M%S).sql"
tar -czf "files-forensics-$(date +%Y%m%d-%H%M%S).tar.gz" /path/to/wordpress

# 3. Check for recently modified files
find /path/to/wordpress -type f -mtime -7 -ls

# 4. Check for suspicious user accounts
wp user list --format=json | python3 -c "
import json,sys
users=json.load(sys.stdin)
for u in users:
    if 'administrator' in u['roles']:
        print(f'ADMIN: {u[\"user_login\"]} ({u[\"user_email\"]}) registered {u[\"registered_date\"]}')"

# 5. Check for unknown admin users
wp db query "SELECT * FROM wp_users WHERE user_registered > DATE_SUB(NOW(), INTERVAL 30 DAY)"

# 6. Check for unknown files in wp-content
find /path/to/wordpress/wp-content -name "*.php" | while read f; do
  # check if filename looks suspicious
  basename "$f" | grep -qiE "^(admin|wp-|config|class-|index|xmlrpc|readme)" || echo "SUSPICIOUS: $f"
done

# 7. Verify checksums
wp core verify-checksums
wp plugin verify-checksums --all

# 8. Reset all user passwords
wp user list --field=ID | while read uid; do
  wp user reset-password "$uid"
done

# 9. Rotate salts
wp config shuffle-salts

# 10. Update everything
wp core update
wp plugin update --all
wp theme update --all
```
