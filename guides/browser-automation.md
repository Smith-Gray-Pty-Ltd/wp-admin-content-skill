# WordPress Admin UI Automation via browser-use

## Why Browser Automation

Some WordPress tasks cannot be done via the REST API or WP-CLI:

- **tagDiv Composer** (Newspaper theme) — the drag-and-drop page builder is entirely JavaScript-driven
- **Customizer** — live preview, widget placement, menu editing
- **Plugin setup wizards** — WooCommerce onboarding, LifterLMS setup, multi-step wizards
- **Settings pages with dynamic JS** — many plugins render settings with React/Vue
- **Any admin screen you'd normally click through** — no REST endpoint, no WP-CLI command

## Recommended: browser-use (AI-Driven)

**[browser-use](https://github.com/browser-use/browser-use)** is purpose-built for AI agents. Instead of hardcoded CSS selectors that break when a plugin updates its UI, you describe the task in natural language and browser-use handles it — including login, navigation, form filling, AJAX waits, and error recovery.

It uses Playwright under the hood, but the AI-driven layer makes it dramatically more resilient to WordPress's notoriously flaky admin UI.

### Installation

```bash
# Python >= 3.11 required
pip install browser-use

# Install Chromium (one-time)
playwright install chromium
# or if playwright isn't on PATH:
# python -m playwright install chromium
```

### Quickstart

```python
from browser_use import Agent, Browser, ChatBrowserUse
import asyncio

async def main():
    browser = Browser()

    agent = Agent(
        task="Go to https://example.com/wp-login.php, "
             "log in with username 'admin' and password 'your-password', "
             "then go to Settings > General and change the site title to 'My New Blog'.",
        llm=ChatBrowserUse(),
        browser=browser,
    )

    await agent.run()

    # Get the result
    result = await agent.get_result()
    print(result)

asyncio.run(main())
```

### LLM Providers

browser-use supports multiple LLM backends. `ChatBrowserUse()` is optimized for browser tasks, but you can also use:

```python
from browser_use import ChatOpenAI, ChatAnthropic, ChatGoogle

llm=ChatOpenAI(model='gpt-4o')
# llm=ChatAnthropic(model='claude-sonnet-4-6')
# llm=ChatGoogle(model='gemini-3-flash-preview')
```

For local models: `ChatOllama(model='qwen3')`

### Using Real Browser Profiles (Stay Logged In)

The most reliable approach for WordPress: reuse your existing Chrome profile so the agent is already logged in. This avoids re-authentication and 2FA issues.

```python
from browser_use import Browser, BrowserProfile, Agent, ChatBrowserUse
import asyncio

async def main():
    # Use your existing Chrome profile (already logged into wp-admin)
    profile = BrowserProfile(
        storage_state_from_browser='chrome',  # Uses ~/Library/Application Support/Google/Chrome
        # Or specify a path:
        # storage_state='./wp-auth-state.json',
        headless=False,  # Set True once you've confirmed it works
    )

    browser = Browser(profile=profile)

    agent = Agent(
        task="In wp-admin, go to WooCommerce > Settings > Payments, "
             "enable Stripe and set it to test mode.",
        llm=ChatBrowserUse(),
        browser=browser,
    )

    await agent.run()

asyncio.run(main())
```

**Alternative: save auth state for reuse**

```python
# First run: log in and save state
profile = BrowserProfile(
    storage_state='./wp-auth-state.json',
)
agent = Agent(
    task="Go to https://example.com/wp-login.php, log in with username 'admin' "
         "and password 'your-password', then close.",
    llm=ChatBrowserUse(),
    browser=Browser(profile=profile),
)
await agent.run()
# The auth state is saved to wp-auth-state.json

# Subsequent runs: reuse the saved auth
profile = BrowserProfile(
    storage_state='./wp-auth-state.json',
)
agent = Agent(
    task="Go to wp-admin, navigate to Posts > All Posts, "
         "and publish the draft titled 'My Draft Post'",
    llm=ChatBrowserUse(),
    browser=Browser(profile=profile),
)
await agent.run()
```

### Cloud Browser (No Local Chrome Needed)

For production or when you don't want to run a local browser:

```python
from browser_use import Agent, Browser, ChatBrowserUse
import asyncio

async def main():
    browser = Browser(use_cloud=True)  # Requires BROWSER_USE_API_KEY env var

    agent = Agent(
        task="Go to https://example.com/wp-admin, log in as admin, "
             "navigate to Users > Add New, create a user 'editor1' with role Editor.",
        llm=ChatBrowserUse(),
        browser=browser,
    )

    await agent.run()

asyncio.run(main())
```

Get an API key at [cloud.browser-use.com](https://cloud.browser-use.com/settings?tab=api-keys&new=1). Cloud browsers provide stealth detection avoidance, CAPTCHA solving, and proxy rotation.

---

## WordPress-Specific Workflow Recipes

### Recipe 1: Log In and Change a Setting

```python
from browser_use import Agent, Browser, ChatBrowserUse, BrowserProfile
import asyncio

async def change_setting(site_url, username, password, setting_page, setting_name, new_value):
    browser = Browser()

    agent = Agent(
        task=f"""
        Go to {site_url}/wp-login.php.
        Log in with username '{username}' and password '{password}'.
        If WordPress shows a 2FA prompt, ask for help (you cannot complete 2FA).
        Once you see the admin dashboard, navigate to {setting_page}.
        Find the setting labeled '{setting_name}' and change it to '{new_value}'.
        Click Save Changes.
        Verify the setting was saved by checking for a success notice.
        """,
        llm=ChatBrowserUse(),
        browser=browser,
    )

    await agent.run()
    return await agent.get_result()

# Usage
asyncio.run(change_setting(
    'https://example.com',
    'admin',
    'your-password',
    'Settings > General',
    'Site Title',
    'My Awesome Blog'
))
```

### Recipe 2: Create a Post in Gutenberg

```python
async def create_gutenberg_post(site_url, username, password, title, content, category=None):
    browser = Browser()

    task = f"""
    Go to {site_url}/wp-login.php and log in as '{username}' with password '{password}'.
    Navigate to Posts > Add New.
    Wait for the Gutenberg editor to fully load (you should see 'Add title' placeholder).
    Click the title area and type: {title}
    Click in the main content area (below the title) and type: {content}
    """
    if category:
        task += f"\nIn the right sidebar, find the Categories panel. Check the box for '{category}'."
    task += """
    Click the Publish button (blue button, top right).
    In the pre-publish panel that appears, click the second Publish button to confirm.
    Wait for the post-publish confirmation to appear.
    Report the URL of the published post.
    """

    agent = Agent(task=task, llm=ChatBrowserUse(), browser=browser)
    await agent.run()
    return await agent.get_result()
```

### Recipe 3: tagDiv Composer — Edit a Post with the Page Builder

This is exactly where browser-use shines — the Composer is pure JavaScript with no REST API.

```python
async function composer_edit_post(site_url, username, password, post_id, instructions):
    browser = Browser()

    agent = Agent(
        task=f"""
        Go to {site_url}/wp-login.php and log in as '{username}' with password '{password}'.
        Navigate to the post editor for post ID {post_id}: {site_url}/wp-admin/post.php?post={post_id}&action=edit.
        Click the 'tagDiv Composer' button to open the page builder.
        Wait for the Composer interface to fully load (you should see the drag-and-drop canvas).
        {instructions}
        Click the Save button in the Composer.
        Wait for the save confirmation notification.
        Close the Composer and confirm the changes are reflected.
        """,
        llm=ChatBrowserUse(),
        browser=browser,
    )

    await agent.run()
    return await agent.get_result()

# Usage
asyncio.run(composer_edit_post(
    'https://example.com', 'admin', 'your-password', 123,
    "Add a new text block at the top of the page with the heading 'Breaking News'. "
    "Add a new image block below it and insert the image with URL https://example.com/news.jpg."
))
```

### Recipe 4: WooCommerce Onboarding Wizard

```python
async function run_woocommerce_wizard(site_url, username, password, store_config):
    browser = Browser()

    agent = Agent(
        task=f"""
        Go to {site_url}/wp-login.php and log in as '{username}' with password '{password}'.
        Navigate to WooCommerce > Settings > Help > Setup Wizard.
        If the wizard has already been completed, look for a 'Run Setup Wizard Again' option.
        Step through the wizard:
        - Store Details: set address to '{store_config.get("address")}', city '{store_config.get("city")}', country '{store_config.get("country")}'
        - Industry: select '{store_config.get("industry", "Other")}'
        - Product Types: select '{", ".join(store_config.get("product_types", ["Physical products"]))}'
        - Business Details: fill in the form with the business information provided
        Continue through all steps until the wizard is complete.
        Confirm you see a success/completion screen.
        """,
        llm=ChatBrowserUse(),
        browser=browser,
    )

    await agent.run()
    return await agent.get_result()
```

### Recipe 5: Customizer — Change Site Identity

```python
async function update_customizer(site_url, username, password, changes):
    browser = Browser()

    descriptions = "\n".join(f"- {k}: {v}" for k, v in changes.items())
    agent = Agent(
        task=f"""
        Go to {site_url}/wp-login.php and log in as '{username}' with password '{password}'.
        Navigate to Appearance > Customize.
        Wait for the Customizer to fully load (left panel + preview iframe).
        Make the following changes in the Customizer:
        {descriptions}
        Click the Publish button at the top of the Customizer panel.
        Wait for the save confirmation.
        Close the Customizer.
        """,
        llm=ChatBrowserUse(),
        browser=browser,
    )

    await agent.run()
    return await agent.get_result()

# Usage
asyncio.run(update_customizer(
    'https://example.com', 'admin', 'your-password',
    {
        'Site Title': 'My New Site',
        'Tagline': 'Just another awesome blog',
    }
))
```

### Recipe 6: Bulk Assign Categories to Posts

```python
async def bulk_categorize(site_url, username, password, category_name, post_ids):
    browser = Browser()

    ids_str = ', '.join(str(pid) for pid in post_ids)
    agent = Agent(
        task=f"""
        Go to {site_url}/wp-login.php and log in as '{username}' with password '{password}'.
        Navigate to Posts > All Posts.
        For each of these post IDs, check the checkbox next to it: {ids_str}
        Once all are checked, use the Bulk Actions dropdown at the top, select 'Edit'.
        Click Apply.
        In the bulk edit panel that appears, find the Categories section.
        Check the box for '{category_name}'.
        Click Update.
        Wait for the success notice confirming the posts were updated.
        """,
        llm=ChatBrowserUse(),
        browser=browser,
    )

    await agent.run()
    return await agent.get_result()
```

---

## Using Custom Tools with browser-use

For WordPress-specific operations that need precise DOM interaction, register custom tools:

```python
from browser_use import Tools, Agent, Browser, ChatBrowserUse
import asyncio

tools = Tools()

@tools.action(description='Get the current WordPress nonce from the page for AJAX requests.')
def get_wp_nonce() -> str:
    """Returns JavaScript to extract a nonce from the page."""
    return """
    const nonceInput = document.querySelector('#_wpnonce, input[name="_wpnonce"]');
    if (nonceInput) return nonceInput.value;
    // Check for wpApiSettings (Gutenberg)
    if (window.wpApiSettings && window.wpApiSettings.nonce) return window.wpApiSettings.nonce;
    return null;
    """

@tools.action(description='Check for WordPress admin notices (success, error, warning).')
def check_admin_notices() -> str:
    """Returns JavaScript to extract visible admin notices."""
    return """
    const notices = document.querySelectorAll('.notice, .updated, .error');
    return Array.from(notices).map(n => ({
        type: n.classList.contains('notice-success') || n.classList.contains('updated') ? 'success'
            : n.classList.contains('notice-error') || n.classList.contains('error') ? 'error'
            : 'info',
        text: n.textContent.trim().substring(0, 200)
    }));
    """

async def main():
    browser = Browser()
    agent = Agent(
        task="Log into wp-admin and check for any pending updates.",
        llm=ChatBrowserUse(),
        browser=browser,
        tools=tools,
    )
    await agent.run()

asyncio.run(main())
```

---

## CLI Mode

browser-use also has a CLI for quick one-off operations:

```bash
pip install browser-use
browser-use open https://example.com/wp-login.php
browser-use state          # See clickable elements
browser-use click 5        # Click element by index
browser-use type "admin"   # Type text
browser-use screenshot wp-dashboard.png
browser-use close
```

---

## When browser-use Is Not Available (Playwright Fallback)

If the user cannot install browser-use (no Python, or restricted environment), fall back to raw Playwright in Node.js.

See the table at the end of this guide for browser-use vs Playwright tradeoffs. For raw Playwright patterns (login, selectors, AJAX handling, Gutenberg, Customizer, tagDiv Composer), refer to the patterns below in the **Playwright Fallback Reference** section.

---

## Troubleshooting

| Issue | Likely Cause | Fix |
|-------|-------------|-----|
| Agent gets stuck on login | WordPress redirects or 2FA | Use `BrowserProfile(storage_state_from_browser='chrome')` to reuse an already-logged-in session |
| Agent can't find an element | Dynamic UI loaded after page | Add "Wait for the page to fully load" to the task description |
| tagDiv Composer doesn't open | The button label changed | Use a profile with an already-logged-in session; describe the button by color ("orange tagDiv Composer button") |
| Gutenberg blocks not appearing | Editor still initializing | Add "Wait for the Gutenberg editor to fully load (you should see the block toolbar)" |
| Customizer iframe broken | Cross-origin restrictions | Cloud browsers handle this; for local, use `headless=False` |
| Cloud connection fails | API key not set | `export BROWSER_USE_API_KEY=your_key` |
| Rate limited by WordPress | Too many rapid actions | Add pauses: "Wait 2 seconds between each action" in task description |
| "Are you sure you want to do this?" | Nonce expired | Tell the agent: "If you see a confirmation dialog, go back to the previous page and try again" |

---

## Decision: browser-use vs Playwright vs REST API vs WP-CLI

| Task | Best Tool | Why |
|------|-----------|-----|
| Create posts (text content) | REST API | Fast, reliable, no browser overhead |
| Install/update plugins | WP-CLI | Single command, no UI |
| Bulk database operations | WP-CLI | Only tool that can do this |
| Upload media | REST API | Simple multipart upload |
| Change site settings | REST API or WP-CLI | Structured, atomic |
| **tagDiv Composer editing** | **browser-use** | No API exists, pure JS UI |
| **Plugin setup wizards** | **browser-use** | Multi-step JavaScript wizards |
| **Customizer changes** | **browser-use** | Iframe-based live preview, no REST endpoint for all controls |
| **Gutenberg with complex blocks** | **browser-use** | Drag-and-drop block placement, column layouts, reusable blocks |
| **WooCommerce onboarding** | **browser-use** | Wizard with conditional steps |
| **Bulk category assignment** | **browser-use or WP-CLI** | WP-CLI is faster, browser-use is simpler for non-technical users |
| **Menu management** | **browser-use** | Drag-and-drop interface, no practical REST API for all operations |
| **Widget placement** | **browser-use** | Drag-and-drop widget areas |

### When to Fall Back to Raw Playwright

Use raw Playwright only when:
- Python is not available and you need Node.js
- You need precise control over a single DOM operation that browser-use over-engineers
- You're in a CI pipeline that already has Playwright set up
- The task is so simple (click one button, verify one element) that browser-use is overkill

---

## Playwright Fallback Reference

If browser-use is unavailable, these raw Playwright (Node.js) patterns provide the minimum needed for wp-admin automation. **These are less reliable than browser-use** — selectors may break when plugins update.

### Setup

```bash
npm install playwright
npx playwright install chromium
```

### Login

```javascript
const { chromium } = require('playwright');

async function wpLogin(siteUrl, username, password) {
  const browser = await chromium.launch({
    headless: true,
    args: ['--no-sandbox', '--disable-setuid-sandbox']
  });
  const context = await browser.newContext({
    viewport: { width: 1440, height: 900 },
    ignoreHTTPSErrors: true,
  });
  const page = await context.newPage();

  await page.goto(`${siteUrl}/wp-login.php`);
  await page.fill('#user_login', username);
  await page.fill('#user_pass', password);

  await Promise.all([
    page.waitForNavigation({ waitUntil: 'networkidle' }),
    page.click('#wp-submit')
  ]);

  const adminBar = await page.$('#wpadminbar');
  if (!adminBar) throw new Error('Login failed');
  return { browser, context, page };
}
```

### AJAX Wait Helper

```javascript
async function waitForAjax(page, timeoutMs = 10000) {
  await page.waitForFunction(
    () => typeof jQuery !== 'undefined' && jQuery.active <= 1,
    { timeout: timeoutMs }
  );
}
```

### Common Selectors

| Element | Selector |
|---------|----------|
| Admin menu item | `#adminmenu a:has-text("Menu Name")` |
| Settings form | `form[action="options.php"]` |
| Success notice | `.notice-success` |
| Error notice | `.notice-error` |
| Save button | `#submit, input[type="submit"]` |
| Gutenberg title | `h1[aria-label="Add title"]` |
| Gutenberg content | `.block-editor-rich-text__editable` |
| Publish button | `button.editor-post-publish-button__button` |
| Customizer panel | `#customize-controls` |
| tagDiv Composer btn | `#td-composer-edit-btn` |
| Media modal | `.media-modal` |
