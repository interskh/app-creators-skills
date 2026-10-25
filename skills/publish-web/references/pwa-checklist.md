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

Other browsers have similar criteria with small differences.

web.dev also accepts `window-controls-overlay` for `display`; MDN lists
it only under `display_override`, and its `display` values are
`fullscreen`, `standalone`, `minimal-ui`, and `browser` (the default).
The script accepts the three app-like `display` values and ignores
`display_override`.

## Rules the script adds

- An icon counts only if `sizes` lists the exact size (it may list
  several), it is a PNG (`type: image/png`, or no `type` and a `.png`
  src), and its `purpose` is unset or includes `any`. MDN: `any` is the
  default and means the icon fits any context; `maskable` is for icons
  designed around a mask's safe zone. Ship a `maskable` icon in
  addition to, not instead of, the `any` icons.
- Icon `src` resolves against the manifest URL, not the page URL. The
  manifest `href` resolves against the page URL after redirects.
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

- `service-worker-registration`: the page, or one of its first ten
  scripts, calls `navigator.serviceWorker.register(` or loads
  `registerSW.js` (what `vite-plugin-pwa` injects).
- `service-worker-script`: the registered script (or `sw.js` next to
  the page when the path is not a literal string) returns 200 with a
  JavaScript content type. A `text/html` response fails, because that
  is a fallback page answering for a missing file.

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
- https://developer.chrome.com/blog/update-install-criteria (checked 2026-10-26)
- https://developer.chrome.com/docs/devtools/progressive-web-apps/ (checked 2026-10-26)
- https://github.com/GoogleChrome/lighthouse/blob/main/changelog.md (12.0.0 entry, checked 2026-10-26)
- https://github.com/GoogleChrome/lighthouse/releases/tag/v12.0.0 (checked 2026-10-26)
