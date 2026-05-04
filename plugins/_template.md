# Plugin Module: {Plugin Name} [{slug}]

## Overview
- **Plugin**: {Plugin Name}
- **Slug**: {plugin-slug}
- **Website**: {URL}
- **Documentation**: {API docs URL}
- **Primary Interface**: REST API / WP-CLI / Admin AJAX / Custom Endpoint

## What this plugin does
{Brief 1-2 sentence description}

---

## Authentication

{Describe any additional auth needed beyond WordPress — API keys, OAuth, webhook secrets, etc.}

```bash
export PLUGIN_API_KEY="..."
export PLUGIN_API_SECRET="..."
```

---

## Database Tables

{List custom tables the plugin creates, with column descriptions}

| Table | Purpose |
|-------|---------|
| `wp_{prefix}_table` | Description of what this table stores |

---

## REST API / Endpoints

Base path: `/wp-json/{plugin-namespace}/v{1,2,3}/`

### {Resource Name}

```bash
GET    /wp-json/{ns}/v1/{resource}          # List
POST   /wp-json/{ns}/v1/{resource}          # Create
GET    /wp-json/{ns}/v1/{resource}/{id}     # Get single
PUT    /wp-json/{ns}/v1/{resource}/{id}     # Update
DELETE /wp-json/{ns}/v1/{resource}/{id}     # Delete
```

**Request/Response shape**:
```json
{
  "id": 1,
  "field": "value"
}
```

---

## WP-CLI Commands

```bash
wp {plugin-slug} {command} ...

# Common commands:
wp {plugin-slug} list --format=json
wp {plugin-slug} create ...
wp {plugin-slug} update ...
wp {plugin-slug} delete ...
```

---

## Quick Reference: Common Tasks

```bash
# Task: {description}
wp {plugin-slug} {command} ...

# Task: {description}
curl -s -u "$WP_USER:$WP_APP_PASSWORD" \
  -H "Content-Type: application/json" \
  -d '{...}' \
  "$WP_SITE/wp-json/{ns}/v1/{resource}"
```

---

## Workflows & Patterns

### {Workflow Name}
{Step-by-step instructions for a common multi-step operation}

```bash
# Step 1: ...
# Step 2: ...
# Step 3: ...
```

---

## Troubleshooting

- **Common error**: {Error message} → {Solution}
- **Common error**: {Error message} → {Solution}
