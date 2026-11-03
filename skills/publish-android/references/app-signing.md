# Play App Signing and the upload key

What Step 6 sets up, on any route. The route file names the tool that holds the upload key. Bracketed numbers point to `## Sources`.

## Two keys

| key | who holds it | what it does [1] |
|---|---|---|
| Upload key | the creator, or the route's build service on the creator's behalf | Signs the bundle before upload. RSA, 2048 bits or more, in a Java keystore. Google can reset it if it is lost or compromised |
| App signing key | Google Play | Signs the APKs delivered to devices. Google-generated keys are RSA 4096-bit. If you manage it yourself and lose it, it cannot be reset |

Google recommends that the two keys differ [1]. A new app is enrolled in Play App Signing automatically, with quantum-ready hybrid signing and Google-generated keys, when its first bundle is uploaded [1]. App bundles require Play App Signing [2].

## At the first release

Play Console's release page shows the Play App Signing setup for a first release [3]. Default: keep the Google-generated app signing key. Expo's manual guide says the same: choose Google-generated key [4].

Changing the app signing key is possible only before a release reaches the open testing or production track; once an app is published to an open track, its signing key is fixed [1][3]. Changing it after uploads means internal and closed testers must reinstall, and earlier uploads cannot be reused [3]. This skill does not change it. If the creator wants their own app signing key, that is their choice in Play Console, before any open testing or production release.

## Every later upload

The bundle must be signed with the same upload key, and an update must have the same package name and a higher version code [5]. `jarsigner -verify -verbose -certs <file>.aab` on two bundles shows whether they share a certificate [5].

## Lost or compromised upload key

Not locked out [1]. The creator, in their own terminal and Play Console:

1. Create a new upload key, for example in Android Studio [1].
2. Export its certificate: `keytool -export -rfc -keystore upload-keystore.jks -alias upload -file upload_certificate.pem` [1].
3. Play Console, the app, Protected with Play, Play Store protection, Manage Play app signing; under Upload key certificate, Request upload key reset, give a reason, upload the `.pem`, Request [1].

The route file says where its tool keeps the key. Never ask to see a keystore or its password, and never commit one.

## Fingerprints

Services that check the app's signature, such as Google sign-in or Maps, need the app signing key's fingerprints from the same Play Console page, not only the upload key's. With hybrid signing, three keys' fingerprints [1]. The skill names this; registering them is the creator's.

## Sources

All fetched with curl and read 2026-11-03.

1. Use Play App Signing, Play Console Help: https://support.google.com/googleplay/android-developer/answer/9842756?hl=en
2. Inspect app versions on the Latest releases and bundles page, Play Console Help: https://support.google.com/googleplay/android-developer/answer/9844279?hl=en
3. Prepare and roll out a release, Play Console Help: https://support.google.com/googleplay/android-developer/answer/9859348?hl=en
4. Manually submit an Android app to the Google Play Store, Expo: https://docs.expo.dev/submit/android-manual/
5. Update or unpublish your app, Play Console Help: https://support.google.com/googleplay/android-developer/answer/9859350?hl=en
