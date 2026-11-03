---
schema: "1.0"
revision: "__REV__"
date: 2026-11-03
platforms:
  android:
    result: __RESULT__
    checks:
      - { id: app-name, result: pass, evidence: "\"Todo\" from the Expo config (name)", fix: "" }
      - { id: package, result: pass, evidence: "\"io.github.interskh.todo\" from android.package", fix: "" }
      - { id: icon-sizes, result: pass, evidence: "\"./assets/android-icon-foreground.png\" 512x512, \"./assets/android-icon-background.png\" 512x512, \"./assets/android-icon-monochrome.png\" 432x432", fix: "" }
      - { id: permissions-declared, result: pass, evidence: "declared dangerous: none; needed by code: none detected", fix: "" }
      - { id: privacy-policy-url, result: pass, evidence: "\"https://example.com/todo/privacy\"", fix: "" }
      - { id: data-inventory, result: __INV_CHECK__, evidence: "__INV_EVIDENCE__", fix: "" }
      - { id: age-rating, result: pass, evidence: "all questions answered", fix: "" }
      - { id: smoke-run, result: unknown, evidence: "no Android device or emulator was connected", fix: "" }
data_inventory:
  confirmed: __CONFIRMED__
  items: __ITEMS__
age_rating:
  answers:
    play_category: "to-do list"
    play_target_age: "18 and over"
    play_violence: none
    play_sexual_content: none
    play_language: none
    play_gambling: none
    play_fear: none
    play_drugs: none
    play_user_interaction: false
    play_shares_location: false
    play_digital_purchases: none
    play_internet_access: false
---

Eval fixture report: written by hand, as `publish-readiness` would leave it. The evidence strings are what `check-readiness.py --platform android` printed on this fixture.
