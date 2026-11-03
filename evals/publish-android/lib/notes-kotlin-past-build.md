
Step 1: the creator has a Google Play developer account, personal, with identity verification finished, on the account that will publish this app.
Step 2: the creator reported that `./gradlew --version` exits 0 on JVM 21, and that `sdk.dir` is set in `local.properties`.
Step 3: All apps lists io.github.interskh.todo, app status Draft, reported by the creator on 2026-11-03.
Step 6: the creator created the upload key outside this repo and wrote `keystore.properties`. `git ls-files -- keystore.properties '*.jks' '*.keystore'` printed nothing and `git check-ignore -q keystore.properties` exited 0, reported by the creator on 2026-11-03.
Upload key: SHA-256 __FINGERPRINT__, from signingReport, 2026-11-03
Build gradle-bundle: commit __REV__, clean tree at build time, 2026-11-03; finished, clean tree after build, bundle app/build/outputs/bundle/release/app-release.aab, sha256 __SHA____READINGS__
