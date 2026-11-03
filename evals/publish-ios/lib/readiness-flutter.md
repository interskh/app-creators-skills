---
schema: "1.0"
revision: "__REV__"
date: 2026-11-03
platforms:
  ios:
    result: __RESULT__
    checks:
      - { id: app-name, result: pass, evidence: "\"Todo\" from CFBundleDisplayName", fix: "" }
      - { id: bundle-id, result: pass, evidence: "\"io.github.interskh.todo\" from PRODUCT_BUNDLE_IDENTIFIER", fix: "" }
      - { id: icon-sizes, result: pass, evidence: "\"AppIcon.appiconset\": 1024x1024 App Store icon present, 19 icon files sized correctly", fix: "" }
      - { id: icon-alpha, result: pass, evidence: "\"Icon-App-1024x1024-1x.png\" has no alpha channel or tRNS chunk", fix: "" }
      - { id: permission-strings, result: pass, evidence: "declared: NSPhotoLibraryUsageDescription; needed by code: NSPhotoLibraryUsageDescription", fix: "" }
      - { id: privacy-policy-url, result: pass, evidence: "set in state", fix: "" }
      - { id: data-inventory, result: __INV_CHECK__, evidence: "__INV_EVIDENCE__", fix: "" }
      - { id: age-rating, result: pass, evidence: "all questions answered", fix: "" }
      - { id: smoke-run, result: unknown, evidence: "no physical device connected, and Flutter does not support release mode on a simulator", fix: "" }
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

Eval fixture report: written by hand, as `publish-readiness` would leave it given resolved settings. No real `xcodebuild` output exists here: the evidence strings are what `check-readiness.py` printed on this fixture with a hand-written settings file.
