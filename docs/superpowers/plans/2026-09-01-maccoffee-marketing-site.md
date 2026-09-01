# Mac Coffee Marketing Site Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build, validate, and publish a bilingual engineering landing page that sells Mac Coffee through its real wake-session, battery-safety, privacy, and local MCP capabilities.

**Architecture:** A dependency-free static site lives under `site/` and is deployed as an immutable GitHub Pages artifact. Semantic HTML carries the complete English experience, a separate translation dictionary adds Russian, CSS owns the responsive Agent Ops Console visual system, and a small progressive-enhancement script owns only language, copy, hero-state, and reveal interactions.

**Tech Stack:** HTML5, CSS3, browser JavaScript, Node.js built-ins for validation, GitHub Actions, GitHub Pages

**Spec:** `docs/superpowers/specs/2026-09-01-maccoffee-marketing-site-design.md`

## Global Constraints

- The site is dependency-free and has no runtime framework, analytics, cookies, forms, account, pricing, payment, or backend.
- English is the default language; Russian is available through an in-page switch and stored only in `localStorage`.
- The target URL is `https://rekurt.github.io/Mac-Coffee/`; every asset reference must remain relative to support the `/Mac-Coffee/` base path.
- Claims and enum values must match `README.md`, `docs/MCP.md`, and `docs/ARCHITECTURE.md`.
- The page must never claim to override manual Sleep, lid closure, shutdown, restart, thermal protection, or other macOS safety decisions.
- JavaScript is progressive enhancement: all product content, MCP configuration, and external actions remain readable and usable without it.
- Controls are keyboard and touch accessible, focus is visible, targets are at least 44×44 CSS pixels, and nonessential animation respects `prefers-reduced-motion`.

---

## File map

- `site/index.html` — metadata, semantic page narrative, accessible controls, complete English fallback content.
- `site/styles.css` — tokens, responsive layout, Agent Ops Console components, interaction states, and motion preferences.
- `site/i18n.js` — immutable English and Russian string dictionaries exposed as `globalThis.MacCoffeeTranslations`.
- `site/script.js` — language application, copy feedback, hero wake-state toggle, and optional reveal behavior.
- `site/assets/app-icon.png` — 512×512 application icon copied from the shipping asset catalog.
- `site/assets/panel-en.png` — English application panel screenshot copied from repository documentation.
- `site/assets/settings-ru.png` — Russian settings screenshot copied from repository documentation.
- `site/assets/og.png` — one bespoke 1200×630 social card matching the finished site.
- `site/.nojekyll` — disables Jekyll processing for the static artifact.
- `site/tests/validate-site.mjs` — dependency-free structural, content, i18n, link, and asset validation.
- `.github/workflows/pages.yml` — official Pages upload and deploy workflow for `site/`.

---

### Task 1: Static contract and validation harness

**Files:**
- Create: `site/tests/validate-site.mjs`
- Create: `site/index.html`
- Create: `site/i18n.js`
- Create: `site/script.js`
- Create: `site/styles.css`

**Interfaces:**
- Consumes: Node.js built-ins `node:assert/strict`, `node:fs`, `node:path`, `node:vm`, and `node:url`.
- Produces: `node site/tests/validate-site.mjs`, the authoritative zero-dependency site check used by later tasks and CI.

- [ ] **Step 1: Write the failing validator**

Create `site/tests/validate-site.mjs` with checks for required files, unique IDs, valid internal anchors, image alternatives and dimensions, relative local assets, external-link safety, mandatory narrative phrases, language coverage, and JavaScript syntax:

```js
import assert from "node:assert/strict";
import { existsSync, readFileSync } from "node:fs";
import { dirname, join } from "node:path";
import vm from "node:vm";
import { fileURLToPath } from "node:url";

const siteRoot = join(dirname(fileURLToPath(import.meta.url)), "..");
const required = ["index.html", "styles.css", "i18n.js", "script.js"];

for (const file of required) {
  assert.ok(existsSync(join(siteRoot, file)), `Missing ${file}`);
}

const html = readFileSync(join(siteRoot, "index.html"), "utf8");
const ids = [...html.matchAll(/\sid="([^"]+)"/g)].map((match) => match[1]);
assert.equal(ids.length, new Set(ids).size, "HTML IDs must be unique");

for (const [, anchor] of html.matchAll(/href="#([^"]+)"/g)) {
  assert.ok(ids.includes(anchor), `Missing internal anchor #${anchor}`);
}

for (const [tag] of html.matchAll(/<img\b[^>]*>/g)) {
  assert.match(tag, /\salt="[^"]*"/, `Image requires alt: ${tag}`);
  assert.match(tag, /\swidth="\d+"/, `Image requires width: ${tag}`);
  assert.match(tag, /\sheight="\d+"/, `Image requires height: ${tag}`);
}

for (const [, asset] of html.matchAll(/(?:src|href)="((?:assets\/|styles\.css|i18n\.js|script\.js)[^"]*)"/g)) {
  const cleanPath = asset.split(/[?#]/)[0];
  assert.ok(existsSync(join(siteRoot, cleanPath)), `Missing local asset ${cleanPath}`);
}

for (const [tag] of html.matchAll(/<a\b[^>]*target="_blank"[^>]*>/g)) {
  assert.match(tag, /rel="[^"]*noopener[^"]*"/, `External target requires noopener: ${tag}`);
}

for (const phrase of [
  "Your agents don’t sleep",
  "maccoffee_set_session",
  "Settings → AI & automation",
  "Battery protection",
  "No cloud backend",
  "lid closure",
]) {
  assert.ok(html.includes(phrase), `Missing required narrative: ${phrase}`);
}

const context = {};
vm.runInNewContext(readFileSync(join(siteRoot, "i18n.js"), "utf8"), context);
const translations = context.MacCoffeeTranslations;
assert.ok(translations?.en && translations?.ru, "English and Russian dictionaries are required");
assert.deepEqual(Object.keys(translations.ru).sort(), Object.keys(translations.en).sort(), "Language keys differ");

const keys = [
  ...html.matchAll(/data-i18n(?:-aria)?="([^"]+)"/g),
].map((match) => match[1]);
for (const key of new Set(keys)) {
  assert.ok(key in translations.en, `Missing English translation for ${key}`);
  assert.ok(key in translations.ru, `Missing Russian translation for ${key}`);
}

new vm.Script(readFileSync(join(siteRoot, "script.js"), "utf8"));
console.log(`Validated ${ids.length} IDs and ${new Set(keys).size} translation keys.`);
```

- [ ] **Step 2: Run the validator and confirm the red state**

Run:

```bash
node site/tests/validate-site.mjs
```

Expected: non-zero exit with `Missing index.html` because the product files do not exist yet.

- [ ] **Step 3: Add minimal parseable product files**

Create a semantic `site/index.html` skeleton with `header`, `main`, the eight required sections, `footer`, relative stylesheet/script references, and no inline JavaScript. Create `site/i18n.js` with matching `en` and `ru` objects, a strict-mode `site/script.js`, and a token-only `site/styles.css`.

The initial translation interface is:

```js
globalThis.MacCoffeeTranslations = Object.freeze({
  en: Object.freeze({ languageLabel: "Language" }),
  ru: Object.freeze({ languageLabel: "Язык" }),
});
```

- [ ] **Step 4: Run the validator to expose the remaining content contract**

Run:

```bash
node site/tests/validate-site.mjs
```

Expected: non-zero exit naming the first missing narrative or local asset, proving the validator evaluates the product requirements rather than only file existence.

- [ ] **Step 5: Commit the validation contract**

```bash
git add site/tests/validate-site.mjs site/index.html site/i18n.js site/script.js site/styles.css
git commit -m "test(site): define landing page contract"
```

---

### Task 2: Complete bilingual product narrative and assets

**Files:**
- Modify: `site/index.html`
- Modify: `site/i18n.js`
- Create: `site/assets/app-icon.png`
- Create: `site/assets/panel-en.png`
- Create: `site/assets/settings-ru.png`
- Create: `site/.nojekyll`

**Interfaces:**
- Consumes: `globalThis.MacCoffeeTranslations.en` and `.ru`, keyed by every `data-i18n` and `data-i18n-aria` attribute in `index.html`.
- Produces: complete semantic product copy and stable DOM hooks used by `script.js`: `[data-language]`, `[data-copy]`, `#wake-demo`, `#wake-toggle`, `#copy-status`, and `[data-reveal]`.

- [ ] **Step 1: Extend the validator for exact product and asset requirements**

Add these required asset checks and DOM hooks to `site/tests/validate-site.mjs`:

```js
for (const asset of ["assets/app-icon.png", "assets/panel-en.png", "assets/settings-ru.png", ".nojekyll"]) {
  assert.ok(existsSync(join(siteRoot, asset)), `Missing ${asset}`);
}

for (const hook of ["data-language", "data-copy", 'id="wake-demo"', 'id="wake-toggle"', 'id="copy-status"']) {
  assert.ok(html.includes(hook), `Missing interaction hook ${hook}`);
}

for (const href of [
  "https://github.com/rekurt/Mac-Coffee",
  "https://github.com/rekurt/Mac-Coffee/releases/latest",
]) {
  assert.ok(html.includes(href), `Missing product link ${href}`);
}
```

- [ ] **Step 2: Run the validator and confirm missing product assets**

Run:

```bash
node site/tests/validate-site.mjs
```

Expected: non-zero exit naming `assets/app-icon.png`.

- [ ] **Step 3: Build the complete English page**

Implement these sections in `site/index.html` with the exact factual content from the spec:

```html
<main id="main-content">
  <section class="hero" id="top" aria-labelledby="hero-title">...</section>
  <section class="proof" aria-label="Engineering proof">...</section>
  <section class="features" id="features" aria-labelledby="features-title">...</section>
  <section class="mcp" id="mcp" aria-labelledby="mcp-title">...</section>
  <section class="safety" id="security" aria-labelledby="security-title">...</section>
  <section class="architecture" id="architecture" aria-labelledby="architecture-title">...</section>
  <section class="final-cta" aria-labelledby="cta-title">...</section>
</main>
```

The hero must contain the English fallback headline “Your agents don’t sleep. Your Mac shouldn’t either.”, three visible agent jobs, the idle-sleep risk state, and the `#wake-toggle` control. The MCP section must contain the five setup steps, the Codex TOML block, the `maccoffee_set_session` JSON example, the six tool names, and the three resource URIs. The safety section must include the exact non-overridden macOS boundaries.

- [ ] **Step 4: Add the complete Russian dictionary**

Populate `site/i18n.js` so every English content node with `data-i18n` has a natural Russian equivalent. Preserve technical identifiers, file paths, tool names, URLs, and enum values verbatim. Use `data-i18n-aria` for translated accessible labels.

The core conversion strings are:

```js
heroEyebrow: "Native macOS wake control for human and AI work",
heroTitle: "Your agents don’t sleep. Your Mac shouldn’t either.",
heroBody: "Keep long-running agents, builds, downloads, and local automation alive while you step away.",
heroPrimary: "Download Direct Build",
heroSecondary: "Connect your MCP client",
heroEyebrowRu: "Нативное управление сном macOS для людей и AI-агентов",
heroTitleRu: "Агенты не спят. И ваш Mac не должен.",
heroBodyRu: "Не прерывайте долгие задачи агентов, сборки, загрузки и локальную автоматизацию, когда отходите от компьютера.",
```

Store these phrases under the shared keys `heroEyebrow`, `heroTitle`, `heroBody`, `heroPrimary`, and `heroSecondary` in the appropriate language objects; the `*Ru` labels above specify the Russian values and are not dictionary keys.

- [ ] **Step 5: Copy shipping assets and create the Pages marker**

Run:

```bash
mkdir -p site/assets
cp Resources/Shared/Assets.xcassets/AppIcon.appiconset/icon_512x512.png site/assets/app-icon.png
cp docs/images/panel-en.png site/assets/panel-en.png
cp docs/images/settings-ru.png site/assets/settings-ru.png
touch site/.nojekyll
```

- [ ] **Step 6: Run the validator and confirm content passes**

Run:

```bash
node site/tests/validate-site.mjs
```

Expected: exit 0 with a count of IDs and translation keys.

- [ ] **Step 7: Commit the complete narrative**

```bash
git add site
git commit -m "feat(site): add bilingual product narrative"
```

---

### Task 3: Agent Ops Console visual system and interactions

**Files:**
- Modify: `site/styles.css`
- Modify: `site/script.js`
- Modify: `site/tests/validate-site.mjs`

**Interfaces:**
- Consumes: DOM hooks from Task 2 and `globalThis.MacCoffeeTranslations`.
- Produces: `setLanguage(language)`, `setWakeState(active)`, `copyCode(button)`, stored preference key `maccoffee-language`, root attribute `data-wake-active`, and non-blocking reveal enhancement.

- [ ] **Step 1: Add script behavior assertions to the validator**

Append static contract checks for progressive enhancement, reduced motion, keyboard-visible focus, and storage isolation:

```js
const css = readFileSync(join(siteRoot, "styles.css"), "utf8");
const script = readFileSync(join(siteRoot, "script.js"), "utf8");

for (const token of ["prefers-reduced-motion", ":focus-visible", "@media (max-width:", "[data-wake-active=\"true\"]"]) {
  assert.ok(css.includes(token), `Missing CSS contract ${token}`);
}

for (const token of ["maccoffee-language", "navigator.clipboard", "IntersectionObserver", "MacCoffeeTranslations"]) {
  assert.ok(script.includes(token), `Missing script contract ${token}`);
}

assert.ok(!html.includes("<script>"), "Inline JavaScript is forbidden");
assert.ok(!html.includes("http://"), "Insecure HTTP URL is forbidden");
```

- [ ] **Step 2: Run the validator and confirm the visual contract fails**

Run:

```bash
node site/tests/validate-site.mjs
```

Expected: non-zero exit naming the first missing CSS contract.

- [ ] **Step 3: Implement the full CSS system**

Build `site/styles.css` around these tokens and breakpoints:

```css
:root {
  --ink: #090a0c;
  --panel: #111317;
  --panel-raised: #171a1f;
  --cream: #f4efe6;
  --muted: #a7a39b;
  --coffee: #d78a4a;
  --coffee-bright: #ffad63;
  --safe: #75e6a4;
  --danger: #ff7b6b;
  --line: rgba(244, 239, 230, 0.12);
  --radius-sm: 12px;
  --radius-md: 22px;
  --radius-lg: 36px;
  --content: 1180px;
}
```

Implement the sticky glass navigation, asymmetric hero grid, coffee glow, operations console, proof strip, feature bento grid, MCP terminal, safety boundary cards, architecture flow, closing CTA, and footer. Use a single-column layout below 800px and compact navigation below 640px. At wide sizes, the hero must fit the initial narrative without forcing horizontal scrolling. Add a visible `:focus-visible` ring, minimum 44px control sizing, and a `prefers-reduced-motion: reduce` block that disables smooth scrolling and decorative transitions.

- [ ] **Step 4: Implement progressive interaction behavior**

Implement `site/script.js` inside a strict IIFE:

```js
(() => {
  "use strict";

  const translations = globalThis.MacCoffeeTranslations;
  const storageKey = "maccoffee-language";

  const setLanguage = (language) => {
    const selected = translations[language] ? language : "en";
    document.documentElement.lang = selected;
    document.querySelectorAll("[data-i18n]").forEach((node) => {
      node.textContent = translations[selected][node.dataset.i18n];
    });
    document.querySelectorAll("[data-i18n-aria]").forEach((node) => {
      node.setAttribute("aria-label", translations[selected][node.dataset.i18nAria]);
    });
    document.querySelectorAll("[data-language]").forEach((button) => {
      button.setAttribute("aria-pressed", String(button.dataset.language === selected));
    });
    try { localStorage.setItem(storageKey, selected); } catch {}
  };

  const setWakeState = (active) => {
    document.querySelector("#wake-demo")?.setAttribute("data-wake-active", String(active));
    document.querySelector("#wake-toggle")?.setAttribute("aria-pressed", String(active));
  };

  // Wire language, wake-state, clipboard, and reveal controls after DOMContentLoaded.
})();
```

Clipboard success and fallback text must be written to `#copy-status` with `aria-live="polite"`. If clipboard access fails, select the associated code block. The reveal observer must be skipped when unavailable; content remains visible by default.

- [ ] **Step 5: Run syntax and contract checks**

Run:

```bash
node --check site/i18n.js
node --check site/script.js
node site/tests/validate-site.mjs
```

Expected: all three commands exit 0; the validator prints counts for IDs and translation keys.

- [ ] **Step 6: Commit the visual product**

```bash
git add site/styles.css site/script.js site/tests/validate-site.mjs
git commit -m "feat(site): add agent operations experience"
```

---

### Task 4: Social preview and deployment workflow

**Files:**
- Create: `site/assets/og.png`
- Modify: `site/index.html`
- Modify: `site/tests/validate-site.mjs`
- Create: `.github/workflows/pages.yml`

**Interfaces:**
- Consumes: the stable site headline, palette, typography treatment, and operations-console motif from Tasks 2–3.
- Produces: a 1200×630 social card and a Pages workflow deploying the exact `site/` directory from `main`.

- [ ] **Step 1: Extend validation for social metadata and Pages deployment**

Add checks to `site/tests/validate-site.mjs`:

```js
for (const metadata of [
  'property="og:title"',
  'property="og:description"',
  'property="og:image"',
  'name="twitter:card" content="summary_large_image"',
  'name="theme-color"',
]) {
  assert.ok(html.includes(metadata), `Missing metadata ${metadata}`);
}
assert.ok(existsSync(join(siteRoot, "assets/og.png")), "Missing social card");

const workflow = readFileSync(join(siteRoot, "../.github/workflows/pages.yml"), "utf8");
for (const token of ["pages: write", "id-token: write", "actions/upload-pages-artifact", "path: site", "actions/deploy-pages"]) {
  assert.ok(workflow.includes(token), `Missing Pages workflow contract ${token}`);
}
```

- [ ] **Step 2: Run the validator and confirm missing deployment assets**

Run:

```bash
node site/tests/validate-site.mjs
```

Expected: non-zero exit naming the first missing social metadata entry.

- [ ] **Step 3: Generate exactly one bespoke social card**

Use the image-generation tool once with this frozen brief:

```text
Create a finished 1200×630 social preview for Mac Coffee. Near-black graphite background, warm coffee-amber glow, cream typography, operational green status. Large exact headline: “Your agents don’t sleep. Your Mac shouldn’t either.” Include a refined macOS-style operations console with three AI agents still running and a clear “WAKE SESSION ACTIVE” state. Add the exact product name “Mac Coffee”. Premium native developer-tool aesthetic, crisp editorial typography, generous safe margins, no logos other than the Mac Coffee cup icon motif, no invented UI labels, no photorealistic laptop.
```

Inspect the returned text. Retry once only if the required text is incorrect or illegible. Save the accepted image as `site/assets/og.png`.

- [ ] **Step 4: Add complete metadata**

Add canonical, description, Open Graph, and X metadata to `site/index.html`:

```html
<link rel="canonical" href="https://rekurt.github.io/Mac-Coffee/">
<meta property="og:type" content="website">
<meta property="og:url" content="https://rekurt.github.io/Mac-Coffee/">
<meta property="og:title" content="Mac Coffee — Keep your agents running">
<meta property="og:description" content="Native macOS wake control with local MCP automation, battery protection, and no cloud backend.">
<meta property="og:image" content="https://rekurt.github.io/Mac-Coffee/assets/og.png">
<meta name="twitter:card" content="summary_large_image">
<meta name="theme-color" content="#090a0c">
```

- [ ] **Step 5: Create the GitHub Pages workflow**

Create `.github/workflows/pages.yml`:

```yaml
name: Deploy website to GitHub Pages

on:
  push:
    branches: [main]
    paths:
      - "site/**"
      - ".github/workflows/pages.yml"
  workflow_dispatch:

permissions:
  contents: read
  pages: write
  id-token: write

concurrency:
  group: pages
  cancel-in-progress: false

jobs:
  deploy:
    environment:
      name: github-pages
      url: ${{ steps.deployment.outputs.page_url }}
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v5
      - uses: actions/configure-pages@v5
      - uses: actions/upload-pages-artifact@v4
        with:
          path: site
      - name: Deploy to GitHub Pages
        id: deployment
        uses: actions/deploy-pages@v4
```

- [ ] **Step 6: Run the complete static validation**

Run:

```bash
node site/tests/validate-site.mjs
git diff --check
```

Expected: both commands exit 0.

- [ ] **Step 7: Commit deployable source**

```bash
git add site .github/workflows/pages.yml
git commit -m "ci(pages): add marketing site deployment"
```

---

### Task 5: Local delivery verification and public publication

**Files:**
- Modify only if verification reveals a concrete defect: `site/index.html`, `site/styles.css`, `site/i18n.js`, `site/script.js`, `site/tests/validate-site.mjs`, `.github/workflows/pages.yml`

**Interfaces:**
- Consumes: validated static site and Pages workflow from Tasks 1–4.
- Produces: public `https://rekurt.github.io/Mac-Coffee/` responding successfully with the committed headline and assets.

- [ ] **Step 1: Run the complete local verification suite**

Run:

```bash
node --check site/i18n.js
node --check site/script.js
node site/tests/validate-site.mjs
git diff --check
git status --short
```

Expected: syntax checks and validator exit 0, `git diff --check` prints nothing, and the worktree is clean.

- [ ] **Step 2: Serve the exact artifact and probe every critical response**

Start a retained local server:

```bash
python3 -m http.server 4173 --directory site
```

In another shell, run:

```bash
curl --fail --silent http://127.0.0.1:4173/ | grep -F "Your agents don’t sleep"
curl --fail --silent --output /dev/null http://127.0.0.1:4173/styles.css
curl --fail --silent --output /dev/null http://127.0.0.1:4173/i18n.js
curl --fail --silent --output /dev/null http://127.0.0.1:4173/script.js
curl --fail --silent --output /dev/null http://127.0.0.1:4173/assets/app-icon.png
curl --fail --silent --output /dev/null http://127.0.0.1:4173/assets/panel-en.png
curl --fail --silent --output /dev/null http://127.0.0.1:4173/assets/og.png
```

Expected: every command exits 0 and the first prints the hero markup.

- [ ] **Step 3: Enable GitHub Actions as the Pages source if necessary**

Inspect current Pages state:

```bash
gh api repos/rekurt/Mac-Coffee/pages
```

If the endpoint returns 404, create it with the workflow build type:

```bash
gh api --method POST repos/rekurt/Mac-Coffee/pages -f build_type=workflow
```

If it exists with another build type, update it:

```bash
gh api --method PUT repos/rekurt/Mac-Coffee/pages -f build_type=workflow
```

- [ ] **Step 4: Publish the reviewed branch head to `main`**

Confirm the branch is based on the current remote and push the exact verified commit:

```bash
git fetch origin main
git merge-base --is-ancestor origin/main HEAD
git push origin HEAD:main
```

Expected: the ancestry check exits 0 and the push reports a fast-forward update to `main`.

- [ ] **Step 5: Wait for the Pages workflow**

Run:

```bash
gh run list --workflow pages.yml --branch main --limit 1
gh run watch --exit-status
```

Expected: `Deploy website to GitHub Pages` completes successfully.

- [ ] **Step 6: Verify the public deliverable**

Run:

```bash
curl --fail --location --silent https://rekurt.github.io/Mac-Coffee/ | grep -F "Your agents don’t sleep"
curl --fail --location --silent --output /dev/null https://rekurt.github.io/Mac-Coffee/styles.css
curl --fail --location --silent --output /dev/null https://rekurt.github.io/Mac-Coffee/script.js
curl --fail --location --silent --output /dev/null https://rekurt.github.io/Mac-Coffee/assets/og.png
```

Expected: every request succeeds and the page contains the committed hero headline.

- [ ] **Step 7: Record any verification-only repair**

If Tasks 5.1–5.6 exposed and fixed a concrete defect, rerun all affected checks and commit only that repair:

```bash
git add site .github/workflows/pages.yml
git commit -m "fix(site): resolve delivery verification issue"
git push origin HEAD:main
```

If no defect was found, create no additional commit.
