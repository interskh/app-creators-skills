
Step 1: the creator has a Google Play developer account, personal, with identity verification finished, on the account that will publish this app.
Step 2: the creator reported that `flutter doctor` shows no errors under Android toolchain.
Step 3: All apps lists io.github.interskh.todo, app status Draft, reported by the creator on 2026-11-03.
Step 6: the creator created the upload key outside this repo and wrote `android/key.properties`. `git ls-files -- android/key.properties '*.jks' '*.keystore'` printed nothing and `git check-ignore -q android/key.properties` exited 0, reported by the creator on 2026-11-03.
Upload key: SHA-256 __FINGERPRINT__, from version code 7, 2026-11-03
Build flutter-appbundle: commit __REV__, clean tree at build time, 2026-11-03; finished, clean tree after build, bundle build/app/outputs/bundle/release/app-release.aab, sha256 __SHA__; package io.github.interskh.todo, version name 1.0.0, version code 7, signer SHA-256 __FINGERPRINT__
Target API: 36 read from build/app/outputs/bundle/release/app-release.aab at commit __REV__, requires 36
