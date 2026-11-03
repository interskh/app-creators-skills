# Encryption export compliance

Apple asks about encryption for every new version, and a build with no answer shows Missing Compliance. Bracketed numbers point to `## Sources`.

## The rule

An app that uses, accesses, contains, implements, or incorporates encryption needs an export compliance determination, including one using crypto functionality within Apple's operating system. It is your responsibility, and you carry the liability for claiming an exemption wrongly [1]. The determination covers third-party libraries too [2].

Typically, encryption built into the operating system, such as HTTPS through `URLSession`, is exempt from export documentation upload, and proprietary encryption is not [3]. A year-end self-classification report to the U.S. government may apply to exempt encryption [3]. France controls the import and export of encryption apps separately [1].

The `ITSAppUsesNonExemptEncryption` key in `Info.plist` records the answer: `NO` means no encryption or only exempt encryption, `YES` means non-exempt. With it absent, App Store Connect asks on every upload [2]. A route sets it in its own way; see the route file.

## The ask

Read the project first. If the key or the route's equivalent is set, do not ask. Otherwise, name any crypto dependency the project shows, then ask once, and stop:

"Does your app, including its libraries, use encryption other than what Apple's operating system provides, such as HTTPS? Reply no, yes, or not sure. This is your legal answer, and Apple's questions in App Store Connect will help you decide it."

- **no:** set the flag per the route file, in Step 4's commit.
- **yes or not sure:** set nothing. The creator answers Apple's questions in App Store Connect: App Information, App Encryption Documentation, add (+) [4]. Or Manage next to the build. Required role: Account Holder, Admin, or App Manager [4].

Never answer for the creator.

## When documentation is needed

Upload it under App Encryption Documentation before submitting a build for App Review or TestFlight App Review. Fill in the App Description and availability first, or Apple cannot judge it. Apple expects to clear complete information in about two business days, then gives a key value for `ITSEncryptionExportComplianceCode` [3][4]. Adding that value is a project edit, so it changes the revision and returns to Step 4.

## Missing Compliance on a build

Click Manage or Choose File next to the build in App Store Connect and answer [5]. Answering there needs no new build, and internal testing and submission wait until it is done. Set the flag only if the answer is no, so the next upload skips the question. That edit is committed for the next build, and does not change this one.

## Sources

All fetched with curl and read 2026-11-03.

1. Overview of export compliance, Apple: https://developer.apple.com/help/app-store-connect/manage-app-information/overview-of-export-compliance/
2. ITSAppUsesNonExemptEncryption, Apple: https://developer.apple.com/documentation/bundleresources/information-property-list/itsappusesnonexemptencryption
3. Complying with Encryption Export Regulations, Apple: https://developer.apple.com/documentation/security/complying-with-encryption-export-regulations
4. Determine and upload app encryption documentation, Apple: https://developer.apple.com/help/app-store-connect/manage-app-information/determine-and-upload-app-encryption-documentation/
5. Choose a build to submit, Apple: https://developer.apple.com/help/app-store-connect/manage-builds/choose-a-build-to-submit
