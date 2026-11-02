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
    intent: wanted
    detected: "yes"
    status: unknown
    package: ""
readiness:
  web: { result: unknown, revision: "", date: "" }
  ios: { result: __RESULT__, revision: "__REV__", date: 2026-11-02 }
  android: { result: __RESULT__, revision: "__REV__", date: 2026-11-02 }
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
    privacy_policy_url: "https://example.com/todo/privacy"
    support_email_env: ""
history:
  - { skill: app-creators, version: "0.1.1", date: 2026-11-02, result: ok }
  - { skill: publish-readiness, version: "0.1.0", date: 2026-11-02, result: __RESULT__ }
---

Eval fixture state: written by hand, as `publish-readiness` would leave it.
