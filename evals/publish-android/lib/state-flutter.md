---
schema: "1.0"
updated: 2026-11-03
app:
  name: Todo
  slug: todo
  description: A to-do list that keeps its items on the device.
  languages: [en, zh]
framework:
  kind: flutter
  package_manager: none
  evidence: pubspec.yaml
targets:
  web:
    intent: not-wanted
    detected: "no"
    status: unknown
    url: ""
    provider: ""
    domain: ""
  ios:
    intent: not-wanted
    detected: "yes"
    status: unknown
    bundle_id: ""
    asc_app_id: ""
  android:
    intent: wanted
    detected: "yes"
    status: __STATUS__
    package: "__PACKAGE__"
readiness:
  web: { result: unknown, revision: "", date: "" }
  ios: { result: unknown, revision: "", date: "" }
  android: { result: __RESULT__, revision: "__REV__", date: 2026-11-03 }
accounts:
  apple_developer: ""
  google_play: "__PLAY__"
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
  - { skill: app-creators, version: "0.1.5", date: 2026-11-03, result: ok }
  - { skill: publish-readiness, version: "0.2.0", date: 2026-11-03, result: __RESULT__ }
---

Eval fixture state: written by hand, as the skills named in `history` would leave it.
