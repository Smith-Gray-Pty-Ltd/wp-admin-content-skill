# wp-admin-content-skill

An agent skill for AI coding agents (openclaw, Hermes, LangGraph, etc.) that teaches them to manage WordPress like a human administrator — via WP-CLI, the REST API, and plugin-specific interfaces.

## What Agents Can Do With This Skill

- **Content Management** — Create, edit, publish, and schedule posts/pages with Gutenberg blocks
- **Administration** — Manage users, roles, settings, updates, and site health
- **Plugin & Theme Management** — Install, activate, update, audit, and configure plugins/themes
- **Security** — Audit and harden WordPress against common vulnerabilities
- **eCommerce** — Full WooCommerce store management (products, orders, coupons, reports)
- **LMS** — Full LifterLMS course management (courses, lessons, quizzes, enrollments)
- **News/Media Themes** — Newspaper theme (tagDiv) template management
- **Migrations** — Site migrations, database search-replace, staging ↔ production sync
- **Automation** — Bulk operations, scheduled tasks, content imports
- **Browser Automation** — browser-use-powered admin UI interaction for page builders, setup wizards, and drag-and-drop editors

## Architecture

```
wp-admin-content-skill/
├── SKILL.md                     # Core skill: auth, REST API, WP-CLI, content, admin
├── plugins/                     # Extendable plugin modules
│   ├── _template.md             # Template for adding new plugins
│   ├── woocommerce.md           # WooCommerce ecommerce module
│   ├── lifterlms.md             # LifterLMS learning management module
│   └── newspaper-theme.md       # Newspaper theme (tagDiv) module
├── guides/                      # Detailed workflow guides
│   ├── security-hardening.md    # Full security hardening checklist
│   ├── content-workflows.md     # Content management patterns
│   ├── site-migration.md        # Site migration guide
│   └── browser-automation.md    # Playwright wp-admin UI automation
├── scripts/                     # Helper scripts
│   ├── wp-audit.sh              # Security audit with auto-fix
│   └── wp-backup.sh             # Automated backup with remote upload
├── README.md                    # This file
└── LICENSE                      # MIT License
```

## Installation

### For openclaw / Hermes / OpenCode

Copy the skill to your skills directory:

```bash
# Clone the repo
git clone https://github.com/smithandgray/wp-admin-content-skill.git

# Symlink or copy into your agent's skills directory
ln -s "$(pwd)/wp-admin-content-skill" ~/.config/opencode/skills/wp-admin-content
# or for Hermes
# ln -s "$(pwd)/wp-admin-content-skill" ~/.hermes/skills/wp-admin-content
```

### For LangGraph / Custom Agents

Use `SKILL.md` as a system prompt or knowledge base. Load plugin modules on-demand:

```python
# Load core skill
with open("SKILL.md") as f:
    core_skill = f.read()

# Load plugin modules dynamically
def load_plugin(plugin_name: str) -> str:
    with open(f"plugins/{plugin_name}.md") as f:
        return f.read()
```

## Prerequisites (What the User Needs)

The skill requires the user to provide:
- **WordPress site URL** (e.g., `https://example.com`)
- **WordPress username** + **Application Password** (generated at Users → Profile → Application Passwords)
- **SSH access** to the server (for WP-CLI operations — optional but recommended)

The agent will prompt for these when needed. No credentials are stored in this repo.

For **browser automation** (browser-use), the user also needs **Python >= 3.11**:
```bash
pip install browser-use
python -m playwright install chromium
```
The agent will prompt for these if a task requires UI automation. browser-use describes tasks in natural language — far more reliable than raw Playwright selectors for WordPress's dynamic admin UI.

If Python is unavailable, a Playwright (Node.js) fallback is documented in `guides/browser-automation.md`.

## Adding New Plugin Support

This skill is designed to be extendable. To add a new plugin module:

1. Copy `plugins/_template.md` to `plugins/{plugin-slug}.md`
2. Fill in the sections:
   - Overview & authentication
   - Database tables
   - REST API endpoints or WP-CLI commands
   - Common tasks and workflows
   - Troubleshooting
3. Add the plugin to the "Currently Supported" table in `SKILL.md`

See `plugins/_template.md` for the full template structure.

## Contributing

Submit a PR to add support for more plugins/themes. Follow the `_template.md` pattern.

## License

MIT — see [LICENSE](LICENSE)
