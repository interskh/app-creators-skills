---
schema: "1.0"
revision: "__REV__"
date: 2026-11-03
platforms:
  ios:
    result: __RESULT__
    checks:
      - { id: app-name, result: pass, evidence: "Todo from the Expo config", fix: "" }
      - { id: bundle-id, result: pass, evidence: "io.github.interskh.todo from ios.bundleIdentifier", fix: "" }
      - { id: icon-sizes, result: pass, evidence: "./assets/icon.png is 1024x1024", fix: "" }
      - { id: icon-alpha, result: pass, evidence: "./assets/icon.png has no alpha channel or tRNS chunk", fix: "" }
      - { id: permission-strings, result: pass, evidence: "declared: NSPhotoLibraryUsageDescription", fix: "" }
      - { id: privacy-policy-url, result: pass, evidence: "set in state", fix: "" }
      - { id: data-inventory, result: __INV_CHECK__, evidence: "__INV_EVIDENCE__", fix: "" }
      - { id: age-rating, result: pass, evidence: "all questions answered", fix: "" }
      - { id: smoke-run, result: unknown, evidence: "xcodebuild is absent", fix: "" }
data_inventory:
  confirmed: __CONFIRMED__
  items: __ITEMS__
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
---

Eval fixture report: written by hand, as `publish-readiness` would leave it.
