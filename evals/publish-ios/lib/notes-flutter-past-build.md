
Step 1: the creator has an active Apple Developer Program membership.
Step 2: the creator reported `xcodebuild -version` prints Xcode 27.2, `flutter doctor` reports Xcode without errors, and an Apple Account is added in Xcode, under Xcode, Settings, Accounts.
Step 3: the app record exists, Apple ID __ASC__, version 1.0.0 at Prepare for Submission, reported by the creator on 2026-11-03.
Step 6: the creator turned on Automatically manage signing on the Runner target and chose a team. `DEVELOPMENT_TEAM` is committed in `ios/Runner.xcodeproj/project.pbxproj`, and readiness was reassessed at that commit.
Step 7: the creator generated the key and set `ASC_KEY_ID` and `ASC_ISSUER_ID`. The names are under `provided.publish-ios`; the key is outside this repo.
Build flutter-ipa: commit __REV__, clean tree at build time, 2026-11-03; finished, clean tree after build, version 1.0.0, build 7, ipa build/ios/ipa/todo.ipa, sha256 0000000000000000000000000000000000000000000000000000000000000007
