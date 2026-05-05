# WordPress Admin UI Automation via Playwright

## Why Browser Automation

Some WordPress tasks cannot be done via the REST API or WP-CLI:

- **tagDiv Composer** (Newspaper theme) — the drag-and-drop page builder is entirely JavaScript-driven and saves via AJAX
- **Customizer** — live preview, widget placement, menu editing
- **Plugin setup wizards** — WooCommerce onboarding, LifterLMS setup, most multi-step wizards
- **Settings pages with dynamic JS** — many plugins render settings with React/Vue and save via admin-ajax.php
- **Admin screens with no REST endpoint** — any screen you'd normally click through

Playwright is the recommended tool. It's faster than Puppeteer, has better auto-waiting, and handles iframes (WordPress uses them heavily in the post editor and customizer).

---

## Setup

```bash
# Install Playwright
npm install playwright

# Install a browser (chromium is sufficient for wp-admin)
npx playwright install chromium

# For CI or headless servers
npx playwright install-deps chromium
```

**When the agent needs Playwright**: the agent should check if Playwright is available, and if not, guide the user to install it with the commands above. Playwright scripts can be written inline by the agent and executed via `node`.

---

## Login & Session Management

### Pattern 1: Login via wp-login.php (fresh session)

```javascript
const { chromium } = require('playwright');

async function wpLogin(siteUrl, username, password) {
  const browser = await chromium.launch({ headless: true });
  const context = await browser.newContext();
  const page = await context.newPage();

  // Navigate to login page
  await page.goto(`${siteUrl}/wp-login.php`);

  // Fill credentials
  await page.fill('#user_login', username);
  await page.fill('#user_pass', password);

  // Submit and wait for redirect to wp-admin
  await Promise.all([
    page.waitForNavigation({ waitUntil: 'networkidle' }),
    page.click('#wp-submit')
  ]);

  // Verify we're logged in
  const adminBar = await page.$('#wpadminbar');
  if (!adminBar) {
    throw new Error('Login failed — no admin bar found');
  }

  return { browser, context, page };
}

// Usage
const { browser, page } = await wpLogin('https://example.com', 'admin', 'app-password');
```

### Pattern 2: Login via Application Password (stateless)

WordPress Application Passwords work with Basic Auth for REST API but NOT for wp-admin cookie auth. For wp-admin, you must log in through the login form.

If you need both REST API and wp-admin access in the same script, log in via the form first, then use the cookies for subsequent REST calls:

```javascript
async function wpLoginAndGetCookies(siteUrl, username, password) {
  const browser = await chromium.launch({ headless: true });
  const context = await browser.newContext();
  const page = await context.newPage();

  await page.goto(`${siteUrl}/wp-login.php`);
  await page.fill('#user_login', username);
  await page.fill('#user_pass', password);
  await Promise.all([
    page.waitForNavigation({ waitUntil: 'networkidle' }),
    page.click('#wp-submit')
  ]);

  // Extract cookies for REST API use
  const cookies = await context.cookies();
  const cookieHeader = cookies
    .map(c => `${c.name}=${c.value}`)
    .join('; ');

  await browser.close();

  return cookieHeader;
}

// Use cookies with curl
const cookieHeader = await wpLoginAndGetCookies('https://example.com', 'admin', 'mypass');
// curl -H "Cookie: $cookieHeader" https://example.com/wp-json/wp/v2/posts
```

### Pattern 3: Reuse Session (avoid login each time)

For repeated automation, save and reuse the browser state:

```javascript
const path = require('path');
const fs = require('fs');

const STATE_FILE = path.join(__dirname, 'wp-auth-state.json');

async function getAuthenticatedPage(siteUrl, username, password) {
  const browser = await chromium.launch({ headless: true });

  let context;
  if (fs.existsSync(STATE_FILE)) {
    // Reuse existing session
    context = await browser.newContext({
      storageState: STATE_FILE
    });
    const page = await context.newPage();
    await page.goto(`${siteUrl}/wp-admin`);

    // Check if session still valid
    const adminBar = await page.$('#wpadminbar');
    if (adminBar) {
      return { browser, context, page };
    }
    // Session expired — delete state and re-login
    fs.unlinkSync(STATE_FILE);
    await context.close();
  }

  // Fresh login
  context = await browser.newContext();
  const page = await context.newPage();

  await page.goto(`${siteUrl}/wp-login.php`);
  await page.fill('#user_login', username);
  await page.fill('#user_pass', password);
  await Promise.all([
    page.waitForNavigation({ waitUntil: 'networkidle' }),
    page.click('#wp-submit')
  ]);

  // Save state for next run
  await context.storageState({ path: STATE_FILE });

  return { browser, context, page };
}
```

### Pattern 4: Bypass Login via WP-CLI Auth Cookie

For maximum reliability, generate a valid auth cookie via WP-CLI and inject it into Playwright:

```bash
# Generate an auth cookie valid for 48 hours
AUTH_COOKIE=$(wp eval "
  \$user = get_user_by('login', 'admin');
  wp_set_auth_cookie(\$user->ID, true);
  " --skip-plugins=two-factor 2>/dev/null)
# The cookie name is based on the site URL hash
```

Then in Playwright:

```javascript
async function loginWithWpCliCookie(siteUrl, browserContext) {
  // WP-CLI generates cookies that Playwright can use directly
  // The user runs this command and passes the cookie value
  const cookieValue = process.env.WP_AUTH_COOKIE;
  const siteHash = crypto.createHash('md5').update(siteUrl).digest('hex');

  await browserContext.addCookies([{
    name: `wordpress_logged_in_${siteHash}`,
    value: cookieValue,
    domain: new URL(siteUrl).hostname,
    path: '/',
    httpOnly: true,
    secure: siteUrl.startsWith('https'),
    sameSite: 'Lax'
  }]);
}
```

---

## WordPress Admin Navigation & Selectors

### Common CSS Selectors

WordPress admin is built on jQuery UI and has stable class names:

| Element | Selector |
|---------|----------|
| Admin menu item | `#adminmenu .menu-top a[href*="page=menu-slug"]` |
| Left sidebar submenu | `#adminmenu .wp-submenu a[href*="sub-page"]` |
| Post list table | `#the-list tr` or `.wp-list-table tr` |
| Bulk action dropdown | `#bulk-action-selector-top` |
| "Apply" button | `#doaction` |
| "Add New" button (top) | `.page-title-action` |
| Save/Publish button | `#publish`, `#save-post`, `input[name="save"]` |
| Settings form | `form[action="options.php"]` |
| Tab navigation | `.nav-tab-wrapper .nav-tab` |
| Metaboxes | `.postbox` or `.meta-box-sortables` |
| Admin notice | `.notice` or `.updated` or `.error` |
| WP Editor (Classic) | `#wp-content-wrap` (textarea mode: `#content`, TinyMCE: `#tinymce`) |
| Media library button | `#insert-media-button` or `.insert-media` |
| Media modal | `#__wp-uploader-id-0` or `.media-modal` |

### Navigation Helpers

```javascript
// Navigate to any admin page
async function goToAdminPage(page, siteUrl, pagePath) {
  await page.goto(`${siteUrl}/wp-admin/${pagePath}`, {
    waitUntil: 'networkidle'
  });
  // WordPress admin pages often load via AJAX — wait for the main content
  await page.waitForSelector('#wpbody-content', { state: 'visible' });
}

// Click an admin menu item
async function clickAdminMenu(page, menuText) {
  // Menu items are links in #adminmenu
  await page.click(`#adminmenu a:has-text("${menuText}")`);
  await page.waitForLoadState('networkidle');
}

// Fill a wp-admin form field (handles both plain inputs and TinyMCE)
async function fillWpField(page, fieldId, value) {
  // Check if it's a textarea (post content)
  const isTextarea = await page.$(`#${fieldId}`);
  if (isTextarea) {
    // Classic editor textarea
    await page.fill(`#${fieldId}`, value);
  } else {
    // Regular input
    await page.fill(`input[name="${fieldId}"]`, value);
  }
}
```

---

## Handling WordPress AJAX (Critical)

WordPress admin makes heavy use of `admin-ajax.php`. Many operations trigger background XHR requests that must complete before the next action.

### Wait for AJAX to Complete

```javascript
// Generic helper: wait until no active AJAX requests
async function waitForAjax(page, timeoutMs = 10000) {
  // jQuery's $.active tracks pending requests
  await page.waitForFunction(
    () => typeof jQuery !== 'undefined' && jQuery.active === 0,
    { timeout: timeoutMs }
  );
}

// Wait for a specific admin notice to appear (success or error)
async function waitForAdminNotice(page, textContains = '') {
  const selector = textContains
    ? `.notice:has-text("${textContains}")`
    : '.notice';
  await page.waitForSelector(selector, { timeout: 15000 });
  return await page.textContent(selector);
}

// Click a button that triggers AJAX, then wait
async function clickAndWaitForAjax(page, selector) {
  await Promise.all([
    waitForAjax(page),
    page.click(selector)
  ]);
}

// Fill a field that triggers autosave/AJAX, then wait
async function fillAndWaitForAjax(page, selector, value) {
  await page.fill(selector, value);
  await waitForAjax(page);
}
```

### Handling Heartbeat API

WordPress sends periodic heartbeat requests. These count as active AJAX. Ignore them:

```javascript
async function waitForAjaxExcludingHeartbeat(page, timeoutMs = 10000) {
  await page.waitForFunction(
    () => typeof jQuery !== 'undefined' &&
      jQuery.active <= 1,  // Allow 1 for heartbeat
    { timeout: timeoutMs }
  );
}
```

### Handling Nonces

WordPress nonces appear in admin forms as hidden `_wpnonce` fields and in AJAX calls. Playwright handles these automatically since it operates through the browser — the nonce is part of the page's HTML.

If you need to extract a nonce:

```javascript
async function getWpNonce(page, action = '') {
  // Common nonce fields
  const selectors = [
    `#_wpnonce`,
    `#_wpnonce_${action}`,
    `input[name="_wpnonce"]`,
    `input[name="_wp_http_referer"]`
  ];
  for (const sel of selectors) {
    const el = await page.$(sel);
    if (el) {
      return await el.getAttribute('value');
    }
  }
  return null;
}
```

---

## Common Workflow Patterns

### Workflow 1: Navigate to a Plugin Settings Page and Save

```javascript
async function updatePluginSettings(page, siteUrl, pluginSlug, settings) {
  // Navigate to the plugin's settings page
  await page.goto(`${siteUrl}/wp-admin/admin.php?page=${pluginSlug}`, {
    waitUntil: 'networkidle'
  });

  // Fill each setting
  for (const [key, value] of Object.entries(settings)) {
    const input = await page.$(`[name="${key}"]`);
    if (!input) continue;

    const tagName = await input.evaluate(el => el.tagName);
    const type = await input.evaluate(el => el.type);

    if (tagName === 'SELECT') {
      await page.selectOption(`[name="${key}"]`, value);
    } else if (type === 'checkbox') {
      if (value) await page.check(`[name="${key}"]`);
      else await page.uncheck(`[name="${key}"]`);
    } else if (type === 'radio') {
      await page.check(`[name="${key}"][value="${value}"]`);
    } else {
      await page.fill(`[name="${key}"]`, String(value));
    }
  }

  // Save
  await Promise.all([
    page.waitForNavigation({ waitUntil: 'networkidle' }),
    page.click('input[type="submit"], button[type="submit"], #submit')
  ]);

  // Check for success notice
  const notice = await page.$('.notice-success');
  return notice !== null;
}
```

### Workflow 2: Create a Post in the Gutenberg Editor

```javascript
async function createGutenbergPost(page, siteUrl, { title, content }) {
  await page.goto(`${siteUrl}/wp-admin/post-new.php`, {
    waitUntil: 'networkidle'
  });

  // Wait for Gutenberg to fully load
  await page.waitForSelector('.block-editor-writing-flow', { timeout: 15000 });

  // Fill the title (Gutenberg uses a contenteditable h1)
  const titleBlock = await page.$('h1[aria-label="Add title"]');
  if (titleBlock) {
    await titleBlock.click();
    await page.keyboard.type(title);
  }

  // Fill content in the default paragraph block
  const contentBlock = await page.$('.block-editor-rich-text__editable');
  if (contentBlock) {
    await contentBlock.click();
    await page.keyboard.type(content);
  }

  // Publish
  await page.click('button.editor-post-publish-button__button');
  await page.waitForSelector('.editor-post-publish-panel');

  // Confirm publish
  await page.click('button.editor-post-publish-button');
  await page.waitForSelector('.post-publish-panel__postpublish-header', {
    timeout: 20000
  });

  // Get the published post URL
  const postUrl = await page.$eval('.post-publish-panel__postpublish-header a', el => el.href);
  return postUrl;
}
```

### Workflow 3: Interact with the Customizer

The Customizer is an iframe-based live preview. Navigate carefully:

```javascript
async function updateCustomizerSetting(page, siteUrl, settingId, value) {
  await page.goto(`${siteUrl}/wp-admin/customize.php`, {
    waitUntil: 'networkidle'
  });

  // Wait for the customizer to fully load
  await page.waitForSelector('#customize-controls', { timeout: 20000 });

  // Customizer panels are often collapsed — expand if needed
  // Settings are in left panel, preview is in iframe

  // Find and expand the relevant section
  const section = await page.$(`#accordion-section-${settingId}`);
  if (section) {
    const isExpanded = await section.evaluate(el =>
      el.classList.contains('open')
    );
    if (!isExpanded) {
      await section.click();
      await page.waitForTimeout(500);
    }
  }

  // Fill the setting (this varies by control type)
  const control = await page.$(`[data-customize-setting-link="${settingId}"]`);
  if (control) {
    await control.fill(String(value));

    // Trigger change event (customizer listens for this)
    await control.evaluate(el => {
      el.dispatchEvent(new Event('change', { bubbles: true }));
    });

    // Wait for the iframe preview to update
    await page.waitForTimeout(1000);
  }

  // Save & Publish
  await page.click('#save');
  await page.waitForSelector('.saved', { timeout: 15000 });

  return true;
}
```

### Workflow 4: tagDiv Composer (Newspaper Theme)

The tagDiv Composer is notoriously difficult to automate. Key patterns:

```javascript
async function openTagDivComposer(page, siteUrl, postId) {
  // Navigate to the post edit screen
  await page.goto(`${siteUrl}/wp-admin/post.php?post=${postId}&action=edit`, {
    waitUntil: 'networkidle'
  });

  // Wait for tagDiv Composer button
  await page.waitForSelector('#td-composer-edit-btn', { timeout: 15000 });

  // Click the tagDiv Composer button
  await page.click('#td-composer-edit-btn');

  // The composer opens in a full-screen overlay or new iframe
  // Wait for the composer interface to load
  await page.waitForSelector('.tdc-header, .tdc-sidebar, .tdc-main-content', {
    timeout: 30000
  });

  console.log('tagDiv Composer loaded');
}

async function saveTagDivComposer(page) {
  // The save button in tagDiv Composer
  await page.click('.tdc-save-btn, button[title="Save"]');

  // Wait for save confirmation
  // tagDiv shows a green notification
  await page.waitForSelector('.tdc-saved-notification, .tdc-success-msg', {
    timeout: 15000
  });

  // Wait for AJAX to finish (the composer saves via admin-ajax.php)
  await waitForAjax(page, 20000);

  console.log('tagDiv Composer saved');
}

// Add a block/element in the composer
async function addTagDivBlock(page, blockType) {
  // Click the "+" or "Add Element" button
  await page.click('.tdc-add-element-btn, .tdc-add-block');

  // Wait for the block library to open
  await page.waitForSelector('.tdc-block-library, .tdc-elements-panel', {
    timeout: 10000
  });

  // Click the desired block type
  await page.click(`.tdc-element[data-block="${blockType}"], .tdc-block-item:has-text("${blockType}")`);

  // Block is added — wait for it to render
  await page.waitForTimeout(2000);
}
```

### Workflow 5: WooCommerce Setup Wizard

```javascript
async function runWooCommerceSetupWizard(page, siteUrl, config) {
  await page.goto(`${siteUrl}/wp-admin/admin.php?page=wc-admin&path=%2Fsetup-wizard`, {
    waitUntil: 'networkidle'
  });

  // Step 1: Store Details
  await page.waitForSelector('.woocommerce-profile-wizard__container');
  await page.fill('#woocommerce-store-address', config.address);
  await page.fill('#woocommerce-store-city', config.city);
  await page.selectOption('#woocommerce-store-country', config.country);

  await page.click('.woocommerce-profile-wizard__continue');
  await page.waitForTimeout(1500);

  // Step 2: Industry
  if (config.industry) {
    await page.click(`.woocommerce-profile-wizard__checkbox-group label:has-text("${config.industry}")`);
    await page.click('.woocommerce-profile-wizard__continue');
    await page.waitForTimeout(1500);
  }

  // Step 3: Product Types
  if (config.productTypes) {
    for (const type of config.productTypes) {
      await page.click(`.components-checkbox-control:has-text("${type}")`);
    }
    await page.click('.woocommerce-profile-wizard__continue');
    await page.waitForTimeout(1500);
  }

  // Step 4: Business Details
  // Continue through remaining steps
  // ...
}
```

### Workflow 6: Bulk Actions on Post List Table

```javascript
async function bulkTrashDraftPosts(page, siteUrl) {
  await page.goto(`${siteUrl}/wp-admin/edit.php?post_status=draft`, {
    waitUntil: 'networkidle'
  });

  // Select all drafts
  await page.check('#cb-select-all-1');

  // Choose "Move to Trash" from bulk actions
  await page.selectOption('#bulk-action-selector-top', 'trash');

  // Apply
  await Promise.all([
    page.waitForNavigation({ waitUntil: 'networkidle' }),
    page.click('#doaction')
  ]);

  const notice = await page.textContent('#message');
  return notice;
}
```

---

## Playwright Config for WordPress

A reusable config that sets sensible defaults:

```javascript
// playwright-wp.config.js
const { chromium } = require('playwright');

module.exports = {
  async launch(headless = true) {
    return await chromium.launch({
      headless,
      args: [
        '--no-sandbox',
        '--disable-setuid-sandbox',
        '--disable-dev-shm-usage',
        '--disable-web-security',        // wp-admin uses cross-origin iframes
        '--disable-features=IsolateOrigins,site-per-process'
      ]
    });
  },

  async createContext(browser, siteUrl) {
    return await browser.newContext({
      viewport: { width: 1440, height: 900 },
      userAgent: 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36',
      ignoreHTTPSErrors: true,
      // WordPress admin needs these permissions
      permissions: ['clipboard-read', 'clipboard-write']
    });
  }
};
```

---

## Debugging & Troubleshooting

### Take Screenshots on Failure

```javascript
async function withScreenshotOnError(page, label, fn) {
  try {
    return await fn();
  } catch (err) {
    const filename = `/tmp/wp-error-${label}-${Date.now()}.png`;
    await page.screenshot({ path: filename, fullPage: true });
    console.error(`Error during "${label}". Screenshot: ${filename}`);
    throw err;
  }
}
```

### Log All AJAX Requests

```javascript
page.on('request', req => {
  if (req.url().includes('admin-ajax.php') || req.url().includes('wp-json')) {
    console.log(`[AJAX] ${req.method()} ${req.url()}`);
  }
});

page.on('response', resp => {
  if (resp.url().includes('admin-ajax.php')) {
    console.log(`[AJAX] ${resp.status()} ${resp.url()}`);
  }
});
```

### Detect WordPress Fatal Errors

```javascript
async function checkForWpError(page) {
  // WordPress shows fatal errors in #error-page or .wp-die-message
  const errors = await page.$$eval(
    '#error-page, .wp-die-message, .php-error, .error:has-text("Fatal"), .notice-error',
    els => els.map(el => el.textContent.trim())
  );

  if (errors.length > 0) {
    throw new Error(`WordPress error detected: ${errors.join(' | ')}`);
  }
}
```

### Common Pitfalls

| Issue | Cause | Fix |
|-------|-------|-----|
| `wp_die` or white screen | Nonce expired or invalid request | Re-navigate to the page to get a fresh nonce |
| Gutenberg not loading | JavaScript error or plugin conflict | Check browser console: `page.on('console', msg => console.log(msg.text()))` |
| AJAX timeout | WordPress is rate-limiting or overloaded | Increase timeout, add `waitForTimeout()` before clicks |
| Customizer iframe not accessible | Cross-origin restrictions | Use `--disable-web-security` in args |
| tagDiv Composer blank | Composer JS hasn't loaded | Wait for `.tdc-header` not just the page load |
| "Are you sure you want to do this?" | Nonce failure | Always re-navigate the page before form submission |
| Login redirects to same page | Session cookie issues | Delete old `wp-auth-state.json` and log in fresh |

---

## When to Use Playwright vs REST API vs WP-CLI

| Task | Best Tool |
|------|-----------|
| Create posts with Gutenberg blocks | REST API (faster, more reliable) |
| Create posts via page builder (Composer, Elementor) | Playwright |
| Install/update plugins | WP-CLI |
| Configure visual page builder settings | Playwright |
| Bulk database operations | WP-CLI |
| Upload media | REST API |
| Run setup wizards (WooCommerce, LifterLMS) | Playwright |
| Change site settings | REST API or WP-CLI |
| Drag-and-drop menu editor | Playwright |
| Widget management | Playwright (via Customizer or Appearance > Widgets) |
| Customizer live preview changes | Playwright |
| Export/import content | WP-CLI |
