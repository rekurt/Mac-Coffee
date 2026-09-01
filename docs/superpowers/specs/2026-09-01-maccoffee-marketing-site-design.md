# Mac Coffee Marketing Site Design

## Goal

Create and publish a high-conversion engineering landing page for Mac Coffee. The page must make the product's core value immediately clear: long-running AI agents should not be interrupted because an unattended Mac enters idle sleep.

The site will present Mac Coffee as a native, privacy-first macOS utility with local MCP control. It will serve both developers discovering the project on GitHub and regular Mac users who need reliable long-running work.

## Audience and language

- Primary audience: developers using Codex, Claude Desktop, and other long-running local automation.
- Secondary audience: Mac users running downloads, builds, renders, presentations, or other unattended tasks.
- English is the default language for the international GitHub audience.
- Russian is available through an in-page language switch.
- Language choice is stored only in `localStorage`; the site sends no analytics or telemetry.

## Visual direction

The selected direction is **Agent Ops Console**: a polished product page combining a native-macOS feel with a restrained terminal aesthetic.

- Palette: near-black graphite, warm coffee amber, cream text, and operational green.
- Typography: bold editorial display type paired with a compact monospace interface face.
- Motifs: agent-status rows, wake-session telemetry, coffee-ring geometry, and subtle grid lines.
- Motion: purposeful status transitions, cursor-like activity, and scroll reveals. All nonessential motion respects `prefers-reduced-motion`.
- Imagery: real Mac Coffee screenshots and the application icon. Decorative illustrations are built with CSS rather than authored SVG.

The page must feel engineered rather than generic: concrete commands, real application states, security boundaries, and architecture details replace vague marketing claims.

## Page narrative

### 1. Navigation

The sticky navigation contains the product mark, links to Features, MCP, Security, and GitHub, an EN/RU language switch, and a primary Download action.

### 2. Hero: the interrupted-agent problem

The first viewport pairs a concise promise with an interactive operations panel.

- Headline: “Your agents don't sleep. Your Mac shouldn't either.”
- Supporting copy explains that idle sleep can interrupt long-running agents, builds, downloads, and local automation.
- Primary action opens the latest GitHub release.
- Secondary action scrolls to MCP setup.
- The operations panel first shows agents at risk because macOS is approaching idle sleep.
- Activating Mac Coffee changes the panel to a protected wake session and keeps all agents running.
- The transformation must remain understandable without animation and usable from keyboard and touch.

### 3. Product proof

A compact proof strip communicates the core technical attributes: native SwiftUI, process-owned IOKit assertions, no account, no cloud backend, and macOS 13+.

### 4. Feature system

Feature cards use real capabilities from the application:

- Keep Mac Awake and Keep Display Awake modes.
- 30 minutes, 1, 2, 4, or 8 hours, plus indefinite sessions.
- Configurable 10–30% battery cutoff with a safe 15% default and hysteresis.
- Launch at Login.
- Runtime language switching across English, Russian, German, French, Simplified Chinese, Japanese, Korean, and Spanish.
- Native local notifications and accessible VoiceOver labels.
- Direct-build updates through Sparkle.

A real product screenshot anchors the feature grid and confirms that the presented interface exists.

### 5. MCP walkthrough

The MCP section demonstrates both setup and use.

Setup flow:

1. Install and launch the Direct build.
2. Open Settings → AI & automation.
3. Enable MCP and run the setup wizard.
4. Select Codex or Claude Desktop and review the exact proposed config change.
5. Restart the MCP client and approve its first pairing request in Mac Coffee.

The page includes copyable configuration for Codex:

```toml
[mcp_servers.mac_coffee]
command = "/Applications/Mac Coffee.app/Contents/Helpers/MacCoffeeMCP"
```

It also shows a realistic tool call:

```json
{
  "tool": "maccoffee_set_session",
  "arguments": {
    "mode": "system",
    "duration": "hours2",
    "requestId": "agent-run-2026-09-01"
  }
}
```

The response view confirms that the wake session is active. A tool catalog lists status, session control, battery threshold, Launch at Login, and language operations without overwhelming the main story.

### 6. Safety and privacy

The site must explicitly distinguish idle-sleep prevention from bypassing macOS safety behavior.

- Mac Coffee does not override manual Sleep, lid closure, shutdown, restart, thermal protection, or macOS safety decisions.
- Wake assertions are process-owned and released when the session ends or the app terminates.
- MCP is optional and disabled by default.
- Pairing requires explicit approval; credentials live in Keychain.
- MCP communication remains local to the current macOS user.
- There is no account, analytics pipeline, or cloud backend.

### 7. Engineering architecture

A compact flow illustrates:

`AI client → stdio MCP helper → local XPC broker → Mac Coffee → IOKit`

The accompanying copy explains that the helper never launches the application, mutable requests can use idempotent request IDs, and the App Store build excludes MCP entirely.

### 8. Closing conversion

The final section repeats the core outcome: start the agents, start a wake session, and walk away without losing the run. It provides Download Direct Build and View Source actions, followed by a concise repository footer.

## Architecture and files

The site is dependency-free static HTML, CSS, and JavaScript under `site/`.

- `site/index.html`: semantic page structure, product copy, metadata, and accessible controls.
- `site/styles.css`: responsive layout, visual system, animations, and reduced-motion behavior.
- `site/script.js`: language switching, copy buttons, interactive hero state, and progressive scroll effects.
- `site/assets/`: optimized product screenshots, application icon, and a bespoke social-preview image.
- `.github/workflows/pages.yml`: official GitHub Pages artifact and deployment workflow triggered by `main`.

This architecture has no runtime dependencies, avoids a framework build step, loads quickly from the repository subpath, and keeps all asset URLs relative so the site works at `/Mac-Coffee/`.

## Interaction and data flow

The site has no server-side data flow.

- Page content is embedded in the HTML as English and Russian strings.
- The language control swaps `data-i18n` text and updates the document language.
- The selected language is read from and written to local storage.
- Copy controls use the Clipboard API and expose success or failure through an accessible live region.
- The hero control toggles between an at-risk state and an active Mac Coffee session; it does not claim to control the local app.
- Download and source actions link to GitHub Releases and the repository.

JavaScript enhances the page but is not required to read the complete product story or reach the download links.

## Error handling and resilience

- Clipboard failure selects the code block and instructs the user to copy manually.
- Missing local storage or blocked browser storage falls back to English without breaking the page.
- Missing JavaScript leaves a complete static narrative, visible MCP configuration, and usable links.
- Images include meaningful alternatives and fixed dimensions to avoid layout shift.
- External links are direct GitHub URLs and never depend on a third-party redirect.

## Accessibility and responsive behavior

- Semantic landmarks, logical heading order, visible focus styles, and keyboard-operable controls are mandatory.
- Color contrast must remain readable in both operational states.
- Status is communicated by text and icons, not color alone.
- Layout adapts from a single-column mobile presentation to a wide two-column console composition.
- Touch targets are at least 44×44 CSS pixels.
- Animations stop or simplify under `prefers-reduced-motion`.

## Publication

GitHub Pages will be deployed by the official Actions flow from the validated `site/` directory. The public target is:

`https://rekurt.github.io/Mac-Coffee/`

Repository Pages settings will use GitHub Actions as the source. Deployment requires `pages: write` and `id-token: write`; concurrent deployments are serialized.

## Verification

Before publication:

1. Validate that required files and assets exist and contain no broken relative references.
2. Parse the HTML and confirm unique IDs, valid internal anchors, image alternatives, and button labels.
3. Run JavaScript syntax validation.
4. Serve `site/` locally and verify HTTP responses for the page, stylesheet, script, images, and social card.
5. Confirm both language dictionaries cover every translatable key.
6. Confirm the page contains the required feature, MCP, agent-sleep pain, privacy, and safety claims from repository documentation.
7. Validate the GitHub Actions workflow syntax and deployment path.
8. After pushing, wait for the Pages workflow and verify the public URL returns the deployed page.

## Out of scope

- Analytics, cookies, forms, accounts, pricing, payments, or a backend.
- Remote control of a visitor's local Mac Coffee instance from the page.
- Claims that Mac Coffee overrides manual or safety-related macOS sleep behavior.
- MCP support in the App Store build.
