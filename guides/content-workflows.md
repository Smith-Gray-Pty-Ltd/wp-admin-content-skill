# Content Management Workflows

## Publishing Workflows

### Create and Schedule a Post

```bash
# Create a draft
POST_ID=$(curl -s -X POST -u "$WP_USER:$WP_APP_PASSWORD" \
  -H "Content-Type: application/json" \
  -d '{
    "title": "My Upcoming Article",
    "content": "<!-- wp:paragraph --><p>Full article content here.</p><!-- /wp:paragraph -->",
    "excerpt": "A short preview of the article.",
    "status": "draft",
    "categories": [3, 7],
    "tags": [5, 9]
  }' \
  "$WP_SITE/wp-json/wp/v2/posts" | python3 -c "import json,sys; print(json.load(sys.stdin)['id'])")

echo "Created draft post: $POST_ID"

# Schedule it for future publication
curl -s -X PUT -u "$WP_USER:$WP_APP_PASSWORD" \
  -H "Content-Type: application/json" \
  -d '{"status":"future","date":"2024-06-15T09:00:00"}' \
  "$WP_SITE/wp-json/wp/v2/posts/$POST_ID"

echo "Scheduled post $POST_ID for June 15, 2024 at 9:00 AM"
```

### Upload and Attach a Featured Image

```bash
# Step 1: Upload image
IMAGE_RESPONSE=$(curl -s -X POST -u "$WP_USER:$WP_APP_PASSWORD" \
  -F "file=@/path/to/featured-image.jpg" \
  -F "title=Featured Image" \
  -F "alt_text=Description for accessibility" \
  "$WP_SITE/wp-json/wp/v2/media")

IMAGE_ID=$(echo "$IMAGE_RESPONSE" | python3 -c "import json,sys; print(json.load(sys.stdin)['id'])")
IMAGE_URL=$(echo "$IMAGE_RESPONSE" | python3 -c "import json,sys; print(json.load(sys.stdin)['source_url'])")

echo "Uploaded image ID: $IMAGE_ID"
echo "Image URL: $IMAGE_URL"

# Step 2: Attach as featured image
curl -s -X PUT -u "$WP_USER:$WP_APP_PASSWORD" \
  -H "Content-Type: application/json" \
  -d "{\"featured_media\":$IMAGE_ID}" \
  "$WP_SITE/wp-json/wp/v2/posts/$POST_ID"

echo "Attached featured image to post $POST_ID"
```

### Create a Post with Gutenberg Blocks

When creating content programmatically, use Gutenberg block comment syntax:

```bash
# Helper: escape block content for JSON
build_blocks() {
  # Usage: build_blocks "paragraph" "Content here" "{}"
  echo "<!-- wp:$1 $3 -->$2<!-- /wp:$1 -->"
}

# Build a rich post
BLOCKS=""
BLOCKS+=$(build_blocks "paragraph" "<p>Opening paragraph introducing the topic.</p>" "{}")
BLOCKS+="\n\n"
BLOCKS+=$(build_blocks "heading" "<h2>A Key Section</h2>" '{"level":2}')
BLOCKS+="\n\n"
BLOCKS+=$(build_blocks "paragraph" "<p>Detailed explanation under the heading.</p>" "{}")
BLOCKS+="\n\n"
BLOCKS+=$(build_blocks "image" "<figure class=\"wp-block-image\"><img src=\"https://example.com/image.jpg\" alt=\"Alt text\"/></figure>" '{"id":123,"sizeSlug":"large"}')
BLOCKS+="\n\n"
BLOCKS+=$(build_blocks "list" "<ul><li>Point one</li><li>Point two</li><li>Point three</li></ul>" "{}")
BLOCKS+="\n\n"
BLOCKS+=$(build_blocks "quote" "<blockquote class=\"wp-block-quote\"><p>Important quote.</p><cite>Author Name</cite></blockquote>" "{}")
BLOCKS+="\n\n"
BLOCKS+=$(build_blocks "paragraph" "<p>Closing thoughts and call to action.</p>" "{}")

# Escape for JSON
CONTENT_JSON=$(echo -e "$BLOCKS" | python3 -c 'import json,sys; print(json.dumps(sys.stdin.read()))')

# Create the post
curl -s -X POST -u "$WP_USER:$WP_APP_PASSWORD" \
  -H "Content-Type: application/json" \
  -d "{
    \"title\":\"Complete Guide to WordPress Automation\",
    \"content\":$CONTENT_JSON,
    \"excerpt\":\"Learn how to automate your WordPress content workflow.\",
    \"status\":\"publish\",
    \"categories\":[5],
    \"tags\":[3,8,12]
  }" \
  "$WP_SITE/wp-json/wp/v2/posts"
```

### Batch Create Pages from a Template

```bash
# Create multiple pages from a JSON definition
PAGES_JSON='[
  {"title":"About Us","slug":"about","parent":0,"template":"page-full-width.php"},
  {"title":"Contact","slug":"contact","parent":0,"template":"page-contact.php"},
  {"title":"Privacy Policy","slug":"privacy","parent":0,"template":""},
  {"title":"Terms of Service","slug":"terms","parent":0,"template":""},
  {"title":"Our Team","slug":"team","parent":0,"template":""},
  {"title":"Careers","slug":"careers","parent":0,"template":""}
]'

echo "$PAGES_JSON" | python3 -c "
import json,sys,subprocess
pages=json.load(sys.stdin)
for p in pages:
    cmd=f'curl -s -X POST -u \"$WP_USER:$WP_APP_PASSWORD\" -H \"Content-Type: application/json\" -d {json.dumps(p)} \"$WP_SITE/wp-json/wp/v2/pages\"'
    result=subprocess.run(cmd,shell=True,capture_output=True,text=True)
    data=json.loads(result.stdout)
    print(f'Created page: {data.get(\"id\",\"ERROR\")} - {p[\"title\"]}')"
```

---

## Category & Taxonomy Management

### Create Category Hierarchy

```bash
# Create parent category
PARENT_ID=$(curl -s -X POST -u "$WP_USER:$WP_APP_PASSWORD" \
  -H "Content-Type: application/json" \
  -d '{"name":"Technology","slug":"technology","description":"Tech news and reviews"}' \
  "$WP_SITE/wp-json/wp/v2/categories" | python3 -c "import json,sys; print(json.load(sys.stdin)['id'])")

echo "Created parent category ID: $PARENT_ID"

# Create child categories
for child in "Gadgets" "Software" "AI" "Mobile"; do
  SLUG=$(echo "$child" | tr '[:upper:]' '[:lower:]')
  CHILD_ID=$(curl -s -X POST -u "$WP_USER:$WP_APP_PASSWORD" \
    -H "Content-Type: application/json" \
    -d "{\"name\":\"$child\",\"slug\":\"$SLUG\",\"parent\":$PARENT_ID}" \
    "$WP_SITE/wp-json/wp/v2/categories" | python3 -c "import json,sys; print(json.load(sys.stdin)['id'])")
  echo "  Created: $child (ID: $CHILD_ID)"
done
```

### Bulk Tag Management

```bash
# Create multiple tags
for tag in "wordpress" "automation" "security" "plugins" "performance"; do
  curl -s -X POST -u "$WP_USER:$WP_APP_PASSWORD" \
    -H "Content-Type: application/json" \
    -d "{\"name\":\"$tag\"}" \
    "$WP_SITE/wp-json/wp/v2/tags" > /dev/null
  echo "Created tag: $tag"
done

# Merge duplicate tags (delete one, reassign its posts)
# Use WP-CLI for this
wp post list --tag_id=5 --format=ids
# Manually re-tag those posts to tag 8, then:
wp term delete post_tag 5
```

---

## Media Management

### Bulk Media Upload

```bash
UPLOAD_DIR="/path/to/images"

for file in "$UPLOAD_DIR"/*.{jpg,jpeg,png,webp}; do
  [ -f "$file" ] || continue
  FILENAME=$(basename "$file")
  ALT="${FILENAME%.*}"  # Use filename without extension as alt text
  ALT="${ALT//-/ }"      # Replace hyphens with spaces

  ATTACHMENT_ID=$(wp media import "$file" --title="$FILENAME" --alt="$ALT" --porcelain)
  echo "Uploaded: $FILENAME (ID: $ATTACHMENT_ID)"
done
```

### Find and Delete Unused Media

```bash
# Find unattached media items
UNUSED_MEDIA=$(wp post list --post_type=attachment --post_parent=0 --format=ids)

echo "Found $(echo $UNUSED_MEDIA | wc -w) unattached media items"

# Check if they're used in post content before deleting
for MID in $UNUSED_MEDIA; do
  URL=$(wp post get "$MID" --field=guid)
  USAGE_COUNT=$(wp db query "SELECT COUNT(*) FROM wp_posts WHERE post_content LIKE '%$URL%' AND post_type='post'" --silent)
  if [ "$USAGE_COUNT" -eq 0 ]; then
    echo "Deleting unused media ID $MID: $URL"
    # wp post delete "$MID" --force  # Uncomment to actually delete
  else
    echo "Keeping media ID $MID (used in $USAGE_COUNT posts): $URL"
  fi
done
```

### Regenerate Thumbnails

```bash
# After changing themes or image sizes, regenerate all thumbnails
wp media regenerate --yes

# Only regenerate missing sizes (faster)
wp media regenerate --only-missing
```

---

## User & Role Management

### Create Content Team Users

```bash
# Create users in bulk from a CSV
# CSV format: username,email,display_name,role
while IFS=',' read -r username email display_name role; do
  # Skip header line
  [[ "$username" == "username" ]] && continue

  wp user create "$username" "$email" \
    --display_name="$display_name" \
    --role="$role" \
    --send-email

  echo "Created $role: $display_name ($username)"
done < team-users.csv
```

### Audit and Clean Up User Accounts

```bash
# List admins
echo "=== Administrators ==="
wp user list --role=administrator --format=csv --fields=ID,user_login,user_email,display_name,user_registered

# Find users with no posts
echo "=== Users with 0 posts ==="
wp user list --format=json | python3 -c "
import json,sys
users=json.load(sys.stdin)
for u in users:
    count=int(subprocess.check_output(f'wp user session list {u[\"id\"]} --format=count',shell=True).strip())
    print(f'{u[\"user_login\"]:20} {count} sessions')"

# Remove stale users with no activity in 2+ years
# (Use with caution — review the list first)
TWO_YEARS_AGO=$(date -v-2y +%Y-%m-%d)
wp user list --format=json | python3 -c "
import json,sys
users=json.load(sys.stdin)
for u in users:
    last_seen=u.get('registered_date','')
    if last_seen < '$TWO_YEARS_AGO':
        print(f'STALE: {u[\"user_login\"]:20} {u[\"user_email\"]:30} {last_seen}')"
```

---

## Comment Management

### Bulk Comment Moderation

```bash
# Approve all pending comments
PENDING=$(wp comment list --status=hold --format=ids)
for CID in $PENDING; do
  wp comment approve "$CID"
  echo "Approved comment $CID"
done

# Move spam comments to trash
SPAM=$(wp comment list --status=spam --format=ids)
for CID in $SPAM; do
  wp comment trash "$CID"
  echo "Trashed spam comment $CID"
done

# Delete all trashed comments
wp comment delete $(wp comment list --status=trash --format=ids) --force
```

### Close Comments on Old Posts

```bash
# Close comments on posts older than 90 days
CUTOFF=$(date -v-90d +%Y-%m-%d)

POST_IDS=$(wp post list --post_type=post --date_before="$CUTOFF" --format=ids)
for PID in $POST_IDS; do
  wp post update "$PID" --comment_status=closed
  echo "Closed comments on post $PID"
done
```

---

## SEO & Metadata

### Bulk Update Yoast SEO Meta

```bash
# Add SEO title and description to all posts missing them
POST_IDS=$(wp post list --post_type=post --format=ids)
for PID in $POST_IDS; do
  CURRENT_TITLE=$(wp post meta get "$PID" _yoast_wpseo_title 2>/dev/null)
  if [ -z "$CURRENT_TITLE" ]; then
    POST_TITLE=$(wp post get "$PID" --field=post_title)
    wp post meta update "$PID" _yoast_wpseo_title "$POST_TITLE"
    wp post meta update "$PID" _yoast_wpseo_metadesc "$(wp post get "$PID" --field=post_excerpt 2>/dev/null | head -c 156)..."
    echo "Updated SEO for post $PID: $POST_TITLE"
  fi
done
```

### Generate and Submit Sitemaps

```bash
# If using Yoast SEO
wp eval "do_action('wpseo_sitemaps_cache_clear');"
wp eval "do_action('wpseo_do_sitemap');"

# If using Rank Math
wp eval "do_action('rank_math/sitemap/regenerate');"

# Verify sitemap is accessible
curl -sI "$WP_SITE/sitemap_index.xml" | head -1  # Should be 200

# Ping search engines (Yoast does this automatically on publish)
# Manual ping:
curl -s "https://www.google.com/ping?sitemap=$WP_SITE/sitemap_index.xml"
```

---

## Content Audit & Maintenance

### Find and Fix Broken Internal Links

```bash
# Export all post URLs
wp post list --post_type=post,page --post_status=publish --format=csv --fields=ID,post_title,guid > all-urls.csv

# Find posts with short content (thin content)
wp post list --post_type=post --format=json | python3 -c "
import json,sys
posts=json.load(sys.stdin)
for p in posts:
    content=subprocess.check_output(f'wp post get {p[\"id\"]} --field=post_content',shell=True).decode()
    word_count=len(content.split())
    if word_count < 300:
        print(f'THIN: ID:{p[\"id\"]} {p[\"title\"][\"rendered\"]:50} ({word_count} words)')"

# Find duplicate titles
wp post list --post_type=post --format=json | python3 -c "
import json,sys
from collections import Counter
posts=json.load(sys.stdin)
titles=[p['title']['rendered'].lower().strip() for p in posts]
dupes=[t for t,c in Counter(titles).items() if c>1]
for t in dupes:
    print(f'DUPLICATE TITLE: {t}')"
```

### Orphaned Content (no internal links pointing to it)

This requires a more sophisticated approach, but a simple check:

```bash
for PID in $(wp post list --post_type=post --format=ids); do
  SLUG=$(wp post get "$PID" --field=post_name)
  BACKLINKS=$(wp db query "SELECT COUNT(*) FROM wp_posts WHERE post_content LIKE '%/$SLUG%' AND ID != $PID AND post_type='post'" --silent)
  if [ "$BACKLINKS" -eq 0 ]; then
    TITLE=$(wp post get "$PID" --field=post_title)
    echo "ORPHAN: Post $PID ($TITLE) has no internal backlinks"
  fi
done
```

---

## Content Import & Export

### Export Specific Content

```bash
# Export only posts from a specific category
wp export --post_type=post --category=technology --dir="./exports/"

# Export only pages
wp export --post_type=page --dir="./exports/pages/"

# Export all content including media descriptions
wp export --dir="./exports/full-$(date +%Y%m%d)/"
```

### Import from Another WordPress Site

```bash
# 1. On source site: export
ssh user@source "wp export --dir=/tmp/export/"
scp user@source:/tmp/export/*.xml ./imports/

# 2. On destination site: import
wp import ./imports/source.wordpress.*.xml --authors=create

# 3. Update URLs if domains differ
wp search-replace 'https://source.com' 'https://destination.com' --all-tables
```

### Import from CSV

```bash
# CSV format for imports:
# post_title,post_content,post_excerpt,post_status,categories,tags

while IFS=',' read -r title content excerpt status cats tags; do
  # Skip header
  [[ "$title" == "post_title" ]] && continue

  wp post create \
    --post_type=post \
    --post_title="$title" \
    --post_content="$content" \
    --post_excerpt="$excerpt" \
    --post_status="$status" \
    --porcelain

  POST_ID=$?
  echo "Imported: $title (ID: $POST_ID)"

  # Add categories
  if [ -n "$cats" ]; then
    echo "$cats" | tr '|' '\n' | while read cat; do
      CAT_ID=$(wp term list category --field=term_id --name="$cat")
      [ -n "$CAT_ID" ] && wp post term add "$POST_ID" category "$CAT_ID"
    done
  fi
done < content-import.csv
```
