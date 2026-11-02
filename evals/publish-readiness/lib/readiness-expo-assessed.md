---
schema: "1.0"
revision: "__REV__"
date: 2026-11-02
platforms:
  ios:
    result: pass
    checks:
      - { id: app-name, result: pass, evidence: "Todo from the Expo config", fix: "" }
      - { id: bundle-id, result: pass, evidence: "io.github.interskh.todo from ios.bundleIdentifier", fix: "" }
      - { id: icon-sizes, result: pass, evidence: "./assets/icon.png is 1024x1024", fix: "" }
      - { id: icon-alpha, result: pass, evidence: "./assets/icon.png has no alpha channel or tRNS chunk", fix: "" }
      - { id: permission-strings, result: pass, evidence: "declared: NSPhotoLibraryUsageDescription", fix: "" }
      - { id: privacy-policy-url, result: pass, evidence: "set in state", fix: "" }
      - { id: data-inventory, result: pass, evidence: "confirmed by the creator", fix: "" }
      - { id: age-rating, result: pass, evidence: "all questions answered", fix: "" }
      - { id: smoke-run, result: unknown, evidence: "xcodebuild is absent", fix: "" }
  android:
    result: pass
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
  answers:
    parentalControls: false
    ageAssurance: false
    unrestrictedWebAccess: false
    userGeneratedContent: false
    socialMedia: false
    socialMediaAgeRestricted: false
    messagingAndChat: false
    advertising: false
    profanityOrCrudeHumor: NONE
    horrorOrFearThemes: NONE
    alcoholTobaccoOrDrugUseOrReferences: NONE
    medicalOrTreatmentInformation: NONE
    healthOrWellnessTopics: false
    matureOrSuggestiveThemes: NONE
    sexualContentOrNudity: NONE
    sexualContentGraphicAndNudity: NONE
    violenceCartoonOrFantasy: NONE
    violenceRealistic: NONE
    violenceRealisticProlongedGraphicOrSadistic: NONE
    gunsOrOtherWeapons: NONE
    gambling: false
    gamblingSimulated: NONE
    contests: NONE
    lootBox: false
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

Eval fixture report: written by hand, as `publish-readiness` would leave it. The photo the app attaches stays on the device, so the inventory has no items.
