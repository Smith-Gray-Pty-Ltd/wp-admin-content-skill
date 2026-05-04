#!/bin/bash
# WordPress Security Audit Script
# Usage: ./wp-audit.sh [--fix]
#
# Requires: WP-CLI installed and accessible in the WordPress directory.
# Set SITE_URL for REST API checks (optional -- only needed for XML-RPC and header checks).
#
# Run from within the WordPress root directory or set WP_PATH.

set -euo pipefail

WP_PATH="${WP_PATH:-.}"
SITE_URL="${SITE_URL:-}"
FIX_MODE=false

if [ "${1:-}" = "--fix" ]; then
  FIX_MODE=true
  echo ">>> Running in FIX mode — will apply corrections <<<"
fi

echo ""
echo "╔══════════════════════════════════╗"
echo "║  WordPress Security Audit        ║"
echo "╚══════════════════════════════════╝"
echo ""

PASS=0
FAIL=0
WARN=0
FIXES_APPLIED=0

check() {
  local label="$1"
  local status="$2"
  local detail="${3:-}"
  case "$status" in
    PASS) printf "  \033[32m✓ PASS\033[0m  %s\n" "$label"; PASS=$((PASS+1)) ;;
    FAIL) printf "  \033[31m✗ FAIL\033[0m  %s — %s\n" "$label" "$detail"; FAIL=$((FAIL+1)) ;;
    WARN) printf "  \033[33m⚠ WARN\033[0m  %s — %s\n" "$label" "$detail"; WARN=$((WARN+1)) ;;
  esac
}

fix() {
  local label="$1"
  local command="$2"
  if $FIX_MODE; then
    printf "  \033[36m↻ FIX\033[0m   %s\n" "$label"
    eval "$command" > /dev/null 2>&1 || true
    FIXES_APPLIED=$((FIXES_APPLIED+1))
  fi
}

echo "── WordPress Core ──────────────────"
WP_VER=$(wp core version --path="$WP_PATH" 2>/dev/null) || WP_VER="unknown"
echo "  Version: $WP_VER"

echo "── Debug Mode ──────────────────────"
WP_DEBUG=$(wp config get WP_DEBUG --path="$WP_PATH" 2>/dev/null) || WP_DEBUG="false"
if [ "$WP_DEBUG" = "false" ] || [ -z "$WP_DEBUG" ]; then
  check "WP_DEBUG is off" "PASS"
else
  check "WP_DEBUG is ON (production risk)" "FAIL" "set WP_DEBUG=false in wp-config.php"
fi

WP_DEBUG_LOG=$(wp config get WP_DEBUG_LOG --path="$WP_PATH" 2>/dev/null) || WP_DEBUG_LOG="false"
if [ "$WP_DEBUG_LOG" = "false" ] || [ -z "$WP_DEBUG_LOG" ]; then
  check "WP_DEBUG_LOG is off" "PASS"
else
  check "WP_DEBUG_LOG is ON (debug.log may be publicly accessible)" "FAIL"
fi

WP_DEBUG_DISPLAY=$(wp config get WP_DEBUG_DISPLAY --path="$WP_PATH" 2>/dev/null) || WP_DEBUG_DISPLAY="false"
if [ "$WP_DEBUG_DISPLAY" = "false" ] || [ -z "$WP_DEBUG_DISPLAY" ]; then
  check "WP_DEBUG_DISPLAY is off" "PASS"
else
  check "WP_DEBUG_DISPLAY is ON (errors shown to visitors)" "FAIL"
fi

echo "── File Permissions ────────────────"
DISALLOW_FILE_EDIT=$(wp config get DISALLOW_FILE_EDIT --path="$WP_PATH" 2>/dev/null) || DISALLOW_FILE_EDIT=""
if [ "$DISALLOW_FILE_EDIT" = "true" ]; then
  check "DISALLOW_FILE_EDIT is true" "PASS"
else
  check "DISALLOW_FILE_EDIT is not set" "FAIL" "add: wp config set DISALLOW_FILE_EDIT true --raw"
  fix "Set DISALLOW_FILE_EDIT" "wp config set DISALLOW_FILE_EDIT true --raw"
fi

DISALLOW_FILE_MODS=$(wp config get DISALLOW_FILE_MODS --path="$WP_PATH" 2>/dev/null) || DISALLOW_FILE_MODS=""
if [ "$DISALLOW_FILE_MODS" = "true" ]; then
  check "DISALLOW_FILE_MODS is true" "PASS"
else
  check "DISALLOW_FILE_MODS is not set" "WARN" "prevents admin plugin installs but also blocks WP-CLI installs"
fi

echo "── SSL ─────────────────────────────"
FORCE_SSL_ADMIN=$(wp config get FORCE_SSL_ADMIN --path="$WP_PATH" 2>/dev/null) || FORCE_SSL_ADMIN=""
if [ "$FORCE_SSL_ADMIN" = "true" ]; then
  check "FORCE_SSL_ADMIN is true" "PASS"
else
  check "FORCE_SSL_ADMIN is not set" "WARN" "admin may work over HTTP"
  fix "Set FORCE_SSL_ADMIN" "wp config set FORCE_SSL_ADMIN true --raw"
fi

echo "── Auto Updates ────────────────────"
WP_AUTO_UPDATE_CORE=$(wp config get WP_AUTO_UPDATE_CORE --path="$WP_PATH" 2>/dev/null) || WP_AUTO_UPDATE_CORE=""
if [ -n "$WP_AUTO_UPDATE_CORE" ]; then
  check "WP_AUTO_UPDATE_CORE is '$WP_AUTO_UPDATE_CORE'" "PASS"
else
  check "WP_AUTO_UPDATE_CORE is not set" "WARN" "minor updates won't auto-install"
  fix "Set WP_AUTO_UPDATE_CORE" "wp config set WP_AUTO_UPDATE_CORE minor --raw"
fi

echo "── Core & Plugin Integrity ─────────"
if wp core verify-checksums --path="$WP_PATH" > /dev/null 2>&1; then
  check "Core file checksums OK" "PASS"
else
  check "Core files modified" "FAIL" "core files may be compromised"
fi

PLUGIN_CHECK=$(wp plugin verify-checksums --all --path="$WP_PATH" 2>&1) || true
MODIFIED_PLUGINS=$(echo "$PLUGIN_CHECK" | grep -c "Warning" || echo 0)
if [ "$MODIFIED_PLUGINS" -eq 0 ]; then
  check "Plugin file checksums OK" "PASS"
else
  check "$MODIFIED_PLUGINS plugins have modified files" "FAIL" "review: wp plugin verify-checksums --all"
fi

echo "── Inactive Plugins & Themes ───────"
INACTIVE_PLUGINS=$(wp plugin list --status=inactive --format=count --path="$WP_PATH" 2>/dev/null) || INACTIVE_PLUGINS=0
if [ "$INACTIVE_PLUGINS" -eq 0 ]; then
  check "No inactive plugins" "PASS"
else
  check "$INACTIVE_PLUGINS inactive plugins found" "WARN" "remove with: wp plugin delete \$(wp plugin list --status=inactive --field=name)"
  if $FIX_MODE; then
    INACTIVE_NAMES=$(wp plugin list --status=inactive --field=name --path="$WP_PATH" 2>/dev/null)
    if [ -n "$INACTIVE_NAMES" ]; then
      for plugin in $INACTIVE_NAMES; do
        wp plugin delete "$plugin" --path="$WP_PATH" 2>/dev/null || true
      done
      FIXES_APPLIED=$((FIXES_APPLIED+1))
      echo "         Removed all inactive plugins"
    fi
  fi
fi

INACTIVE_THEMES=$(wp theme list --status=inactive --format=count --path="$WP_PATH" 2>/dev/null) || INACTIVE_THEMES=0
if [ "$INACTIVE_THEMES" -le 1 ]; then
  check "Inactive themes: $INACTIVE_THEMES (≤1 is ok)" "PASS"
else
  check "$INACTIVE_THEMES inactive themes found" "WARN" "keep 1 fallback, delete the rest"
fi

echo "── User Accounts ───────────────────"
ADMIN_COUNT=$(wp user list --role=administrator --format=count --path="$WP_PATH" 2>/dev/null) || ADMIN_COUNT=0
if [ "$ADMIN_COUNT" -gt 0 ] && [ "$ADMIN_COUNT" -le 3 ]; then
  check "Admin users: $ADMIN_COUNT" "PASS"
elif [ "$ADMIN_COUNT" -gt 3 ]; then
  check "High admin count: $ADMIN_COUNT" "WARN" "review and reduce admin users"
else
  check "No admin users?" "FAIL" "something is wrong"
fi

# List all admin users for review
wp user list --role=administrator --format=csv --fields=ID,user_login,user_email --path="$WP_PATH" 2>/dev/null | tail -n +2 | while IFS=',' read -r uid login email; do
  echo "         Admin: $login ($email) [ID:$uid]"
done

echo "── User Enumeration Prevention ─────"
if [ -n "$SITE_URL" ]; then
  ENUM_CHECK=$(curl -s -o /dev/null -w "%{http_code}" "$SITE_URL/?author=1" 2>/dev/null) || ENUM_CHECK="000"
  if [ "$ENUM_CHECK" != "301" ] && [ "$ENUM_CHECK" != "200" ]; then
    check "User enumeration blocked" "PASS"
  else
    check "User enumeration possible" "FAIL" "?author=1 redirects to a user archive"
  fi
fi

echo "── REST API User Exposure ──────────"
if [ -n "$SITE_URL" ]; then
  USER_COUNT=$(curl -s "$SITE_URL/wp-json/wp/v2/users" 2>/dev/null | python3 -c "import json,sys; print(len(json.load(sys.stdin)))" 2>/dev/null) || USER_COUNT="?"
  if [ "$USER_COUNT" = "0" ] || [ "$USER_COUNT" = "?" ]; then
    check "REST users endpoint restricted" "PASS"
  else
    check "REST users endpoint exposes $USER_COUNT users" "FAIL" "install a REST restriction plugin"
  fi
fi

echo "── XML-RPC ─────────────────────────"
if [ -n "$SITE_URL" ]; then
  XMLRPC_CODE=$(curl -s -o /dev/null -w "%{http_code}" -X POST "$SITE_URL/xmlrpc.php" -d '<methodCall><methodName>demo.sayHello</methodName></methodCall>' 2>/dev/null) || XMLRPC_CODE="000"
  if [ "$XMLRPC_CODE" = "405" ] || [ "$XMLRPC_CODE" = "403" ] || [ "$XMLRPC_CODE" = "404" ]; then
    check "XML-RPC blocked or not found" "PASS"
  else
    check "XML-RPC is accessible (HTTP $XMLRPC_CODE)" "WARN" "disable if not using Jetpack or mobile apps"
  fi
fi

echo "── Database ────────────────────────"
PREFIX=$(wp config get table_prefix --path="$WP_PATH" 2>/dev/null) || PREFIX="wp_"
if [ "$PREFIX" != "wp_" ]; then
  check "Table prefix is custom: $PREFIX" "PASS"
else
  check "Table prefix is default 'wp_'" "WARN" "harder to exploit with a custom prefix, but must be set at install"
fi

DB_TABLES=$(wp db tables --path="$WP_PATH" 2>/dev/null | wc -l) || DB_TABLES=0
echo "  Database tables: $DB_TABLES"

echo "── Spam Comments & Revisions ───────"
SPAM_COUNT=$(wp comment list --status=spam --format=count --path="$WP_PATH" 2>/dev/null) || SPAM_COUNT="0"
if [ "$SPAM_COUNT" -eq 0 ]; then
  check "No spam comments" "PASS"
else
  check "$SPAM_COUNT spam comments" "WARN" "delete with: wp comment delete \$(wp comment list --status=spam --format=ids) --force"
  if $FIX_MODE; then
    SPAM_IDS=$(wp comment list --status=spam --format=ids --path="$WP_PATH" 2>/dev/null)
    if [ -n "$SPAM_IDS" ]; then
      wp comment delete $SPAM_IDS --force --path="$WP_PATH" 2>/dev/null || true
      FIXES_APPLIED=$((FIXES_APPLIED+1))
    fi
  fi
fi

echo "── Site Health ─────────────────────"
if [ -n "$SITE_URL" ]; then
  HEALTH=$(curl -s "$SITE_URL/wp-json/wp-site-health/v1" 2>/dev/null) || HEALTH=""
  if [ -n "$HEALTH" ]; then
    echo "  Site Health endpoint: available"
  else
    echo "  Site Health endpoint: not available"
  fi
fi

echo ""
echo "╔══════════════════════════════════╗"
printf "║  Results: %2d PASS  %2d WARN  %2d FAIL  ║\n" $PASS $WARN $FAIL
echo "╚══════════════════════════════════╝"

if $FIX_MODE; then
  echo ""
  echo "Fixes applied: $FIXES_APPLIED"
fi

TOTAL=$((PASS + WARN + FAIL))
SCORE=$(( PASS * 100 / TOTAL ))
echo ""
echo "Security Score: $SCORE% ($PASS/$TOTAL checks passed)"

if [ "$FAIL" -gt 0 ]; then
  echo ""
  echo ">>> $FAIL critical issues need attention. Fix them now. <<<"
  exit 1
elif [ "$WARN" -gt 0 ]; then
  echo ""
  echo ">>> $WARN warnings to review. Run with --fix for auto-fixes. <<<"
  exit 0
else
  echo ""
  echo ">>> All checks passed. Site is well-hardened. <<<"
  exit 0
fi
