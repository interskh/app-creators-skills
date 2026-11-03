---
schema: "1.0"
revision: "__REV__"
date: 2026-11-03
platforms:
  ios:
    result: __IOS__
    checks:
      - { id: app-name, result: pass, evidence: "Todo from the Expo config", fix: "" }
      - { id: bundle-id, result: pass, evidence: "io.github.interskh.todo from ios.bundleIdentifier", fix: "" }
      - { id: icon-sizes, result: pass, evidence: "./assets/icon.png is 1024x1024", fix: "" }
      - __ALPHA__
      - { id: permission-strings, result: pass, evidence: "declared: NSPhotoLibraryUsageDescription", fix: "" }
      - { id: privacy-policy-url, result: pass, evidence: "set in state", fix: "" }
      - { id: data-inventory, result: pass, evidence: "confirmed by the creator", fix: "" }
      - { id: age-rating, result: pass, evidence: "all questions answered", fix: "" }
      - { id: smoke-run, result: unknown, evidence: "xcodebuild is absent", fix: "" }
  android:
    result: __ANDROID__
    checks:
      - { id: app-name, result: pass, evidence: "Todo from the Expo config", fix: "" }
      - { id: package, result: pass, evidence: "io.github.interskh.todo from android.package", fix: "" }
      - { id: icon-sizes, result: pass, evidence: "adaptive layers have valid sizes", fix: "" }
      - { id: permissions-declared, result: pass, evidence: "needed by code: none detected", fix: "" }
      - { id: privacy-policy-url, result: pass, evidence: "set in state", fix: "" }
      - { id: data-inventory, result: pass, evidence: "confirmed by the creator", fix: "" }
      - { id: age-rating, result: pass, evidence: "all questions answered", fix: "" }
      - { id: smoke-run, result: unknown, evidence: "no JDK", fix: "" }
data_inventory:
  confirmed: true
  items: []
age_rating:
  answers: {}
---

Eval fixture report: written by hand, as `publish-readiness` would leave it. The photo the app attaches stays on the device, so the inventory has no items.
