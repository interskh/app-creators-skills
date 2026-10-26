# PWA install checklist

What a browser needs before it offers to install the app, and how each
`scripts/check-pwa.sh` line maps to it. Grounded in the web.dev, MDN,
Chrome, and Lighthouse pages under Sources, checked 2026-10-26.

## Install criteria (Chrome, Edge, Samsung Internet)

| requirement | `check-pwa.sh` line |
|---|---|
| Served over HTTPS (localhost and 127.0.0.1 also count, for local development) | `https`, `html` |
| A `<link rel="manifest" href="...">` in the page | `manifest-link` |
| The manifest is valid JSON | `manifest-json` |
| `name` or `short_name` | `manifest-name` |
| `start_url` | `manifest-start-url` |
| `display` is `fullscreen`, `standalone`, or `minimal-ui` | `manifest-display` |
| `prefer_related_applications` absent or `false` | `manifest-prefer-related-applications` |
| Icons include a 192px and a 512px icon | `icon-192x192`, `icon-512x512` |

The browser also waits for user engagement before it shows its own
install prompt: at least one click or tap on the page and 30 seconds
viewing it, at any time. The app must not be installed already.

Other browsers have similar criteria with small differences. web.dev also
lists `window-controls-overlay` for `display`; MDN has it only under
`display_override`, which the script ignores.

## Rules the script adds

- An icon counts only if `sizes` lists the exact size (it may list
  several), it is a PNG (`type: image/png`, or no `type` and a `.png`
  src), and its `purpose` is unset or includes `any`. MDN: `any` is the
  default and means the icon fits any context; `maskable` is for icons
  designed around a mask's safe zone. Ship a `maskable` icon in
  addition to, not instead of, the `any` icons.
- An icon response must be an image (`image/*` content type or a PNG
  signature). A `text/html` 200 is a rewrite answering for a missing
  file, which a SPA fallback such as Vercel's `rewrites` rule produces.
- Icon `src` resolves against the manifest URL, not the page URL. The
  manifest `href` resolves against the page URL after redirects, and
  HTML comments are removed before the page is scanned for tags.
  The scan reads each tag to its closing `>`, honouring quoted
  attribute values, so `<div data-x="<script>">` does not start a
  script body, a `<link>` inside an attribute value is not a link, and
  `<link title="1 > 0" rel="manifest" …>` is read whole. Attributes are
  read as name, optional `=`, quoted or unquoted value, so
  `rel="manifest"href="…"` works. `<!--` inside a `<script>` or `<style>`
  body does not open a comment; the body ends at `</script` or `</style`
  followed by `>`, `/`, or whitespace. Text inside script and style
  bodies is never read as tags.
  Behaviour that matches the browser: a `<script>` with no closing tag
  turns the rest of the page into script text, and `<script src="…"/>`
  does not self-close, so a manifest link after either is not found
  (`FAIL manifest-link`), as a browser would not see it either.
- A transfer that fails after the status line (timeout, truncation)
  fails the check, whatever the status code.
- Every run prints the same 12 check lines; a check that cannot run
  prints `FAIL <check>: skipped: <reason>`.
- `--allow-http` exists for local previews only. Without it the script
  fails on any http URL, localhost included, so it never passes an
  insecure production URL.

## Service worker

MDN: a service worker is not required for installability, though many
PWAs use one for offline support. Chrome's 2023-12-05 post says it
dropped the requirement for install from the browser menu (Chrome 108
on mobile, 112 on desktop), while the automatic install prompt still
required a `fetch()` handler at that time.

The script checks for one, for offline support and for that prompt:

- `service-worker-registration`: an inline script, or one of the
  page's first ten scripts, calls `navigator.serviceWorker.register(`,
  or the page has a `<script src>` ending in `registerSW.js` (what
  `vite-plugin-pwa` injects).
  With `virtual:pwa-register` the call sits in a lazy chunk, so if a
  script only mentions `serviceWorker`, registration is inferred
  from a JavaScript `sw.js` next to the page ("(inferred from sw.js,
  static scan)"). The check reads source text; it does not run the
  page, so its PASS line always ends in "static scan".
- `service-worker-script`: the registered script (or `sw.js` next to
  the page) returns 200 with a JavaScript MIME type. The W3C spec
  requires one; the script accepts exactly the WHATWG mimesniff list
  (`text/javascript`, `application/javascript`, `text/javascript1.0`
  to `1.5`, `text/jscript`, and the `x-`/`ecmascript`/`livescript`
  variants), case-insensitive, parameters ignored. `text/plain`,
  `application/octet-stream`, or a `text/html` fallback page fail.
  Only live calls count: `register("<url>")` with a quoted URL, found
  after HTML comments are removed from the page and JS comments from
  each inline `<script>` body, each inline event-handler attribute
  (`onload="…"` and every other `on*` attribute, after decoding
  `&quot;`, `&#39;`, `&amp;`, `&lt;`, `&gt;`), and each loaded script,
  one at a time; other HTML and CSS text is never treated as JS. The script fetches
  up to five of them in page order and reports the first served with a
  JavaScript MIME type; if none is, it reports the first and
  `service-worker-script` says why it failed (the line notes when
  there were more than five).
  The check fails closed: a commented-out registration never passes,
  even when its script is still deployed, because "I disabled the
  service worker but `sw.js` still ships" is a common state. A call
  that appears only in the raw text fails with "a register( call
  appears only inside a comment, or inside code the static scanner
  could not parse: <url>". The known cost: the JS pass reads a `/`
  after `)` or `]` as division, so a regex literal there
  (`if (x) /'/.test(y)`) can hide a real call later on that line; the
  message then names it.
  Known limits: a page that only calls `unregister()`, or registers
  behind a runtime branch, still reads as registered, since nothing
  runs; a `<script>` with a non-JS `type` (`importmap`,
  `text/template`) and the ignored body of a `<script src>` are
  scanned as JS; and `<!--` or `<script>` inside a script body (the
  HTML spec's escaped script states) is not modelled, so such a body
  ends at the first `</script`.

`register()` rejects a script URL that is not on a trustworthy origin
(HTTPS or localhost) or not same-origin with the page.

## Why not Lighthouse

Lighthouse 12.0.0 (2024-04-22) removed the PWA category, following
Chrome's updated install criteria. Use this script plus Chrome DevTools:
the Application panel's Manifest tab shows an Installability section
with errors such as an icon that cannot be loaded.

## Sources

- https://web.dev/articles/install-criteria (checked 2026-10-26)
- https://developer.mozilla.org/en-US/docs/Web/Progressive_web_apps/Guides/Making_PWAs_installable (checked 2026-10-26)
- https://developer.mozilla.org/en-US/docs/Web/Progressive_web_apps/Manifest (checked 2026-10-26)
- https://developer.mozilla.org/en-US/docs/Web/Progressive_web_apps/Manifest/Reference/icons (checked 2026-10-26)
- https://developer.mozilla.org/en-US/docs/Web/Progressive_web_apps/Manifest/Reference/display (checked 2026-10-26)
- https://developer.mozilla.org/en-US/docs/Web/API/ServiceWorkerContainer/register (checked 2026-10-26)
- https://w3c.github.io/ServiceWorker/ (checked 2026-10-26)
- https://mimesniff.spec.whatwg.org/#javascript-mime-type (checked 2026-10-26)
- https://vite-pwa-org.netlify.app/guide/register-service-worker.html (checked 2026-10-26)
- https://vercel.com/docs/frameworks/frontend/vite (checked 2026-10-26)
- https://developer.chrome.com/blog/update-install-criteria (checked 2026-10-26)
- https://developer.chrome.com/docs/devtools/progressive-web-apps/ (checked 2026-10-26)
- https://github.com/GoogleChrome/lighthouse/blob/main/changelog.md (12.0.0 entry, checked 2026-10-26)
- https://github.com/GoogleChrome/lighthouse/releases/tag/v12.0.0 (checked 2026-10-26)
