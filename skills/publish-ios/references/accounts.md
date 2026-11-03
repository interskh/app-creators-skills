# Accounts, app record, and keys

What the human-only and app record steps need, on any route. Bracketed numbers point to `## Sources`.

## Apple Developer Program

All enrollees need an Apple Account with two-factor authentication on, and must be of the legal age of majority in their region. Enrollment is in the Apple Developer app or on the web [1].

| | individual | organization |
|---|---|---|
| who | an individual, or a sole proprietor or single-person business [1] | a company, non-profit, joint venture, partnership, or government organization [1] |
| seller on the App Store | your personal legal name. Do not enter an alias or company name: it delays approval [1] | the legal entity name [1] |
| D-U-N-S Number | not needed [2] | required, registered to the legal entity; optional for government organizations [1][2] |
| also needed | nothing further | a legal entity (no DBAs, trade names, or branches), legal authority to bind it, a work email on its domain, and a public website on its domain [1] |
| when you can pay | at enrollment [1] | after Apple Developer Support verifies and emails next steps [1] |

Fee: 99 USD a year, in local currency where available. Enrolling through the Apple Developer app makes it an auto-renewing subscription [1]. If you enroll on the web as an individual and pay by credit card, it must be your own card, or enrollment is delayed and Apple asks for government photo ID [1]. If no membership confirmation arrives within 24 hours of purchase, contact Apple with the Enrollment ID [1].

D-U-N-S: look up your organization first; a request is free. Allow up to 5 business days from D&B, then up to 2 for Apple to receive it [2]. An organization may be asked for notarized business documents [1]. To have your organization named as seller, enroll as an organization; a sole proprietor enrolls as an individual [1].

## Agreements

Free apps are distributed under the Apple Developer Program License Agreement. To sell apps or offer In-App Purchases, the Account Holder must sign the Paid Apps Agreement under Business, Agreements. It can ask for a two-factor code, and it cannot be undone [3]. So when `monetization.model` is anything but `none`, this is a human-only ask. You cannot add an app until the Account Holder signs the latest agreement [4].

## Bundle id

The bundle id must match the project, and it cannot change after a build is uploaded [5]. If it is not in the New App dialog, an Account Holder or Admin registers an explicit App ID: Certificates, Identifiers & Profiles, Identifiers, add (+), App IDs, Explicit App ID [6].

## App record

Role: Account Holder, Admin, or App Manager [4]. Path: Apps, add (+), New App, select the platform, enter the information, Create [4]. Give the creator:

- Platform: iOS.
- Name: `name` from `listing.md` for the primary locale, 2 to 30 characters [5]. If another developer uses the name and you hold trademark rights to it, you can submit a claim [4].
- Primary language: from `references/localizations.md`.
- Bundle ID: `targets.ios.bundle_id`.
- SKU: letters, numbers, hyphens, periods, and underscores, not starting with a hyphen, period, or underscore. It cannot change later [5]. Suggest `app.slug`.
- User access: their choice.

After creation the app appears in Apps with status Prepare for Submission [4]. The Apple ID is under App Information, General Information [5][8].

## New version of a live app

Role: Account Holder, Admin, App Manager, or Marketing. The current version must be Ready for Distribution. Apps, select the app, add (+) next to the platform, enter an incremental version number, Create, then Save. Metadata transfers from the current version. A release cannot be reverted: a fix is a new version [7]. The version number is a project edit, in Step 4.

## App Store Connect API keys

The Account Holder first requests access: Users and Access, Integrations, Request Access. Apple approves requests case by case [9]. A team key needs the Account Holder or Admin role. The file downloads once [9]. All of this is the creator's. Revoke a lost key at once [9]. Never ask to see the key file, and keep it outside the repo.

## EU trader status

If you distribute in the EU, Apple asks you to state whether you are a trader when you next submit a new app. You assess this yourself; Apple cannot. A trader's address, phone number, and email are published on the product page [10]. Apps without trader status are removed from the EU App Store, and it is required to submit updates there [11]. This is the creator's legal decision: give the page, never an answer.

## Sources

All fetched with curl and read 2026-11-03.

1. Program enrollment, Apple: https://developer.apple.com/help/account/membership/program-enrollment/
2. D-U-N-S Number, Apple: https://developer.apple.com/help/account/membership/D-U-N-S/
3. Sign and update agreements, Apple: https://developer.apple.com/help/app-store-connect/manage-agreements/sign-and-update-agreements/
4. Add a new app, Apple: https://developer.apple.com/help/app-store-connect/create-an-app-record/add-a-new-app/
5. App information, Apple: https://developer.apple.com/help/app-store-connect/reference/app-information/app-information
6. Register an App ID, Apple: https://developer.apple.com/help/account/identifiers/register-an-app-id/
7. Create a new version, Apple: https://developer.apple.com/help/app-store-connect/update-your-app/create-a-new-version
8. Submit to the Apple App Store with Expo Submit, how to find `ascAppId`, Expo: https://docs.expo.dev/submit/ios/
9. App Store Connect API, Apple: https://developer.apple.com/help/app-store-connect/get-started/app-store-connect-api/
10. Manage European Union Digital Services Act trader requirements, Apple: https://developer.apple.com/help/app-store-connect/manage-compliance-information/manage-european-union-digital-services-act-trader-requirements
11. Upcoming requirements, Apple: https://developer.apple.com/news/upcoming-requirements/
