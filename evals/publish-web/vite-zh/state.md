---
schema: "1.0"
updated: 2026-10-26
app:
  name: Todo
  slug: todo-vite
  description: A to-do list that keeps its items in the browser.
  languages: [en]
framework:
  kind: vite
  package_manager: npm
  evidence: vite.config.ts
targets:
  web:
    intent: wanted
    detected: "yes"
    status: unknown
    url: ""
    provider: ""
    domain: ""
  ios:
    intent: undecided
    detected: "no"
    status: unknown
    bundle_id: ""
    asc_app_id: ""
  android:
    intent: undecided
    detected: "no"
    status: unknown
    package: ""
readiness:
  web: { result: unknown, revision: "", date: "" }
  ios: { result: unknown, revision: "", date: "" }
  android: { result: unknown, revision: "", date: "" }
accounts:
  apple_developer: missing
  google_play: missing
  vercel: has
tools:
  deploy: ""
  analytics: ""
  iap: ""
  ads: ""
  payments: ""
  attribution: ""
monetization:
  model: none
goal: publish
history:
  - { skill: app-creators, version: "0.1.0", date: 2026-10-26, result: ok }
---

Eval fixture state: written by hand for the publish-web level-2 cases, as `app-creators` would leave it.
