---
schema: "1.0"
updated: 2026-11-02
app:
  name: Todo
  slug: todo-expo
  description: A to-do list that keeps its items on the device.
  languages: [en]
framework:
  kind: expo
  package_manager: npm
  evidence: app.json
targets:
  web:
    intent: not-wanted
    detected: "no"
    status: unknown
    url: ""
    provider: ""
    domain: ""
  ios:
    intent: wanted
    detected: "yes"
    status: unknown
    bundle_id: ""
    asc_app_id: ""
  android:
    intent: undecided
    detected: "yes"
    status: unknown
    package: ""
readiness:
  web: { result: unknown, revision: "", date: "" }
  ios: { result: unknown, revision: "", date: "" }
  android: { result: unknown, revision: "", date: "" }
accounts:
  apple_developer: ""
  google_play: ""
  vercel: ""
tools:
  deploy: ""
  analytics: ""
  iap: ""
  ads: ""
  payments: ""
  attribution: ""
monetization:
  model: ""
goal: publish
provided:
  publish-readiness:
    privacy_policy_url: ""
    support_email_env: ""
history:
  - { skill: app-creators, version: "0.1.1", date: 2026-11-02, result: ok }
---

Eval fixture state: written by hand, as `app-creators` would leave it.
