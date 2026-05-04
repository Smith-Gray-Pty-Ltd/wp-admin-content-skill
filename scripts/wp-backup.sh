#!/bin/bash
# WordPress Backup Script
# Usage: ./wp-backup.sh [--remote] [--files] [--no-db] [--retain N]
#
# Creates timestamped backups of database and files.
# --remote: Also upload to remote storage (configure REMOTE_* vars below)
# --files: Include wp-content files backup (off by default for large sites)
# --no-db: Skip database backup (files only)
# --retain N: Keep only the most recent N backups (default: 30)

set -euo pipefail

# ── Configuration ────────────────────
WP_PATH="${WP_PATH:-.}"
BACKUP_DIR="${BACKUP_DIR:-/tmp/wordpress-backups}"
RETAIN_DAYS="${RETAIN_DAYS:-30}"

# Remote storage (optional)
# Supported: s3, gdrive, sftp, rsync
REMOTE_ENABLED="${REMOTE_ENABLED:-false}"
REMOTE_TYPE="${REMOTE_TYPE:-s3}"  # s3 | gdrive | sftp | rsync
REMOTE_PATH="${REMOTE_PATH:-}"
# For S3: set AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY, S3_BUCKET
# For SFTP: set SFTP_HOST, SFTP_USER, SFTP_KEY (or SFTP_PASS)

# ── Parse Args ───────────────────────
DO_FILES=false
DO_DB=true
DO_REMOTE=false

while [ $# -gt 0 ]; do
  case "$1" in
    --remote) DO_REMOTE=true ;;
    --files) DO_FILES=true ;;
    --no-db) DO_DB=false ;;
    --retain) RETAIN_DAYS="$2"; shift ;;
  esac
  shift
done

TIMESTAMP=$(date +%Y%m%d-%H%M%S)
SITE_NAME=$(wp option get blogname --path="$WP_PATH" 2>/dev/null | tr '[:upper:]' '[:lower:]' | tr ' ' '-' | tr -cd 'a-z0-9-') || SITE_NAME="wordpress"
BACKUP_NAME="${SITE_NAME}-${TIMESTAMP}"
BACKUP_PATH="$BACKUP_DIR/$BACKUP_NAME"
mkdir -p "$BACKUP_PATH"

echo "╔══════════════════════════════════╗"
echo "║  WordPress Backup                 ║"
echo "╚══════════════════════════════════╝"
echo ""
echo "  Site: $(wp option get siteurl --path="$WP_PATH" 2>/dev/null || echo 'unknown')"
echo "  Backup: $BACKUP_PATH"
echo ""

# ── 1. Database Backup ───────────────
if $DO_DB; then
  echo "── Database Backup ─────────────────"
  DB_FILE="$BACKUP_PATH/$BACKUP_NAME.sql.gz"

  wp db export - --path="$WP_PATH" 2>/dev/null | gzip > "$DB_FILE"

  DB_SIZE=$(du -h "$DB_FILE" | cut -f1)
  echo "  ✓ Database: $DB_SIZE ($DB_FILE)"
else
  echo "── Database Backup ─────────────────"
  echo "  (skipped — --no-db)"
fi

# ── 2. Files Backup ──────────────────
if $DO_FILES; then
  echo "── Files Backup ────────────────────"

  # Plugins
  PLUGINS_FILE="$BACKUP_PATH/$BACKUP_NAME-plugins.tar.gz"
  tar -czf "$PLUGINS_FILE" -C "$WP_PATH/wp-content" plugins/ 2>/dev/null || true
  PLUGINS_SIZE=$(du -h "$PLUGINS_FILE" | cut -f1)
  echo "  ✓ Plugins: $PLUGINS_SIZE"

  # Themes
  THEMES_FILE="$BACKUP_PATH/$BACKUP_NAME-themes.tar.gz"
  tar -czf "$THEMES_FILE" -C "$WP_PATH/wp-content" themes/ 2>/dev/null || true
  THEMES_SIZE=$(du -h "$THEMES_FILE" | cut -f1)
  echo "  ✓ Themes: $THEMES_SIZE"

  # Uploads
  UPLOADS_FILE="$BACKUP_PATH/$BACKUP_NAME-uploads.tar.gz"
  tar -czf "$UPLOADS_FILE" -C "$WP_PATH/wp-content" uploads/ 2>/dev/null || true
  UPLOADS_SIZE=$(du -h "$UPLOADS_FILE" | cut -f1)
  echo "  ✓ Uploads: $UPLOADS_SIZE"

  # wp-config.php
  cp "$WP_PATH/wp-config.php" "$BACKUP_PATH/wp-config-$TIMESTAMP.php" 2>/dev/null || true
  echo "  ✓ wp-config.php saved"

  # .htaccess
  cp "$WP_PATH/.htaccess" "$BACKUP_PATH/htaccess-$TIMESTAMP.txt" 2>/dev/null || true
  echo "  ✓ .htaccess saved"
fi

# ── 3. Backup Manifest ────────────────
MANIFEST="$BACKUP_PATH/manifest.json"
cat > "$MANIFEST" << EOF
{
  "site_url": "$(wp option get siteurl --path="$WP_PATH" 2>/dev/null || echo 'unknown')",
  "site_name": "$(wp option get blogname --path="$WP_PATH" 2>/dev/null || echo 'unknown')",
  "timestamp": "$TIMESTAMP",
  "wordpress_version": "$(wp core version --path="$WP_PATH" 2>/dev/null || echo 'unknown')",
  "php_version": "$(wp eval 'echo PHP_VERSION;' --path="$WP_PATH" 2>/dev/null || echo 'unknown')",
  "mysql_version": "$(wp eval 'global \$wpdb; echo \$wpdb->db_version();' --path="$WP_PATH" 2>/dev/null || echo 'unknown')",
  "active_plugins": $(wp plugin list --status=active --format=json --path="$WP_PATH" 2>/dev/null || echo '[]'),
  "active_theme": "$(wp theme list --status=active --field=name --path="$WP_PATH" 2>/dev/null || echo 'unknown')",
  "includes_database": $DO_DB,
  "includes_files": $DO_FILES
}
EOF

echo ""
echo "  ✓ Manifest saved"

# ── 4. Create Combined Archive ────────
echo ""
echo "── Final Archive ───────────────────"
FINAL_ARCHIVE="$BACKUP_DIR/$BACKUP_NAME.tar.gz"
tar -czf "$FINAL_ARCHIVE" -C "$BACKUP_DIR" "$BACKUP_NAME"

# Remove the unarchived directory
rm -rf "$BACKUP_PATH"

FINAL_SIZE=$(du -h "$FINAL_ARCHIVE" | cut -f1)
echo "  ✓ Backup ready: $FINAL_ARCHIVE ($FINAL_SIZE)"

# ── 5. Remote Upload ──────────────────
if $DO_REMOTE; then
  echo ""
  echo "── Remote Upload ───────────────────"

  if [ -z "$REMOTE_PATH" ]; then
    echo "  ✗ REMOTE_PATH not set. Skipping remote upload."
  else
    case "$REMOTE_TYPE" in
      s3)
        S3_BUCKET="${S3_BUCKET:-}"
        if [ -z "$S3_BUCKET" ]; then
          echo "  ✗ S3_BUCKET not set. Skipping S3 upload."
        else
          aws s3 cp "$FINAL_ARCHIVE" "s3://$S3_BUCKET/$REMOTE_PATH/" 2>/dev/null \
            && echo "  ✓ Uploaded to S3: s3://$S3_BUCKET/$REMOTE_PATH/$(basename "$FINAL_ARCHIVE")" \
            || echo "  ✗ S3 upload failed (is aws CLI installed?)"
        fi
        ;;
      sftp)
        SFTP_HOST="${SFTP_HOST:-}"
        SFTP_USER="${SFTP_USER:-}"
        SFTP_KEY="${SFTP_KEY:-}"
        if [ -z "$SFTP_HOST" ] || [ -z "$SFTP_USER" ]; then
          echo "  ✗ SFTP config missing. Set SFTP_HOST, SFTP_USER, SFTP_KEY."
        else
          scp -i "${SFTP_KEY:-~/.ssh/id_rsa}" "$FINAL_ARCHIVE" "$SFTP_USER@$SFTP_HOST:$REMOTE_PATH/" 2>/dev/null \
            && echo "  ✓ Uploaded via SFTP to $SFTP_HOST:$REMOTE_PATH/" \
            || echo "  ✗ SFTP upload failed"
        fi
        ;;
      rsync)
        RSYNC_DEST="${RSYNC_DEST:-}"
        if [ -z "$RSYNC_DEST" ]; then
          echo "  ✗ RSYNC_DEST not set. Skipping rsync."
        else
          rsync -avz "$FINAL_ARCHIVE" "$RSYNC_DEST/$REMOTE_PATH/" 2>/dev/null \
            && echo "  ✓ Synced via rsync to $RSYNC_DEST/$REMOTE_PATH/" \
            || echo "  ✗ rsync failed"
        fi
        ;;
      *)
        echo "  ✗ Unknown REMOTE_TYPE: $REMOTE_TYPE (use s3, sftp, rsync, or gdrive)"
        ;;
    esac
  fi
fi

# ── 6. Cleanup Old Backups ────────────
echo ""
echo "── Cleanup ─────────────────────────"
DELETED=$(find "$BACKUP_DIR" -name "*.tar.gz" -mtime +"$RETAIN_DAYS" -delete -print 2>/dev/null | wc -l)
echo "  Removed $DELETED backups older than $RETAIN_DAYS days"
echo "  Remaining: $(find "$BACKUP_DIR" -name "*.tar.gz" | wc -l) backups"

echo ""
echo "╔══════════════════════════════════╗"
echo "║  Backup Complete!                 ║"
echo "╚══════════════════════════════════╝"
echo ""
echo "  File: $FINAL_ARCHIVE"
echo "  Size: $FINAL_SIZE"

# Print restore instructions
if $DO_DB; then
  echo ""
  echo "  To restore database:"
  echo "    gunzip < $BACKUP_NAME/$BACKUP_NAME.sql.gz | wp db import -"
fi

echo ""
