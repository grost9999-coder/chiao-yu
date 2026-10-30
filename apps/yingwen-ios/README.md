# 映文・iPhone 安裝版

Native SwiftUI app, iOS 17+. Bundle ID: `com.grost9999.yingwen`. Apple Developer team: `5PF59948NJ`.

## Implemented

- Product brief → Gemini generates three copy angles, narration, storyboard and video prompt.
- Gemini key is entered by the owner, tested, then stored in Keychain. Supports opaque auth keys, including `AQ.`. No API key is committed or shared with the web app.
- AI speech generation and importing personal narration.
- PhotosPicker, local H.264 MP4 generation through AVAssetWriter, timed captions, optional narration, portrait/square/landscape, native share sheet and save-to-Photos.
- Video import, preview, trim, optional original audio and frame-based burned-in subtitles.
- Gemini video transcription and highlight suggestions, with explicit upload notice and temporary-file cleanup.
- Device-local text drafts and previously exported MP4 files.

Text-to-new-motion generation remains unconnected, matching the current web deployment; the generated visual prompt can be copied/shared. It is not represented as a completed free video generation feature.

## Verify on a Mac

```sh
cd apps/yingwen-ios
brew install xcodegen
xcodegen generate
xcodebuild test -project YingwenStudio.xcodeproj -scheme YingwenStudio -destination 'platform=iOS Simulator,name=iPhone 17' CODE_SIGNING_ALLOWED=NO
```

The GitHub Actions workflow selects an actually available iPhone simulator. Tests validate SRT parsing and clipping, WAV bytes, native MP4 writing, output dimensions and captioned trimming. Simulator artifacts cannot be installed on an actual iPhone.

## TestFlight

1. App Store Connect must contain a new **映文** app record for `com.grost9999.yingwen` (SKU `yingwen-ios-001`, primary language Traditional Chinese).
2. Register that Bundle ID and add/fetch the matching App Store provisioning profile in the existing Codemagic team. Reuse the existing Apple Distribution certificate.
3. Build this branch in Codemagic using `yingwen-testflight`. It references the previously used `Codemagic-ClearPocket` integration; no private Apple keys are in source.
4. The workflow signs, creates an IPA and uploads it with `submit_to_testflight: true`. It does not submit to the public App Store.
5. After Apple processes the build, select the desired internal tester group in App Store Connect. External testing may require Beta App Review.

## App Store preparation

Provide a support URL/contact, public privacy-policy URL, screenshots, App Privacy disclosures (including user-initiated Gemini uploads), age rating and review notes before public submission. A successful simulator build is not evidence that signing or TestFlight upload succeeded.

## Data and privacy

No analytics/ads/account server. Gemini calls go directly to Google using the owner's key. Free quotas and Google project billing determine cost; no paid provider fallback. Photos/manual exports remain local. Drafts do not include media. Users can export their finished work before deleting the app.
