# KittyMemories 🎀

Private, offline-first native SwiftUI app. Deployment target is intentionally set to iOS 27.0.

## Implemented foundation
- Independent Album and Anniversary SwiftData models.
- Private Application Support storage for album photos, anniversary photos and imported stickers.
- Local PhotosPicker imports copy files into the app sandbox; no Photos-library writes.
- Year → month → day album navigation; book/page and vertical browsing modes.
- Shared Liquid Glass module switcher.
- WeChat article parser using a MicroMessenger user agent, mp.weixin.qq.com Referer, #js_content image extraction and per-image failure handling.
- Clipboard import attempt when the sticker library opens or the app becomes active, plus a manual import button.
- Imported sticker library, GIF frame preview, sticker picker and normalized-coordinate sticker placement editor.
- Optional Vision foreground-mask cutout; failed cutouts keep the source image and show “未抠图”.
- Development-only downloader for the 16 user-provided WeChat articles.

## Build
Requires an Xcode release with the iOS 27 SDK and XcodeGen:
```sh
brew install xcodegen
xcodegen generate
xcodebuild -project KittyMemories.xcodeproj -scheme KittyMemories -sdk iphonesimulator -configuration Debug -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO build
```

The current GitHub-hosted macOS runner reports Xcode 26.6 / iOS 26.5 SDK. It can catch many Swift errors, but it cannot certify a final iOS 27 SDK build. Do not lower the deployment target just to make the older runner green.

## Private storage
Images are stored in Application Support/Photos and Application Support/Stickers. File sharing and opening-in-place are disabled.

## Remaining milestones
- Download and visually curate the 16 article images, then package approved frame assets in Images.xcassets.
- Apply distinct bundled frame styles to album photos.
- Finish custom paper-like page-turn animation and full Liquid Glass matched-geometry transitions.
- Add ImageRenderer export/share, stronger editor selection controls, and thorough on-device testing.
- Review importer behavior against actual WeChat articles; WeChat may block automated requests or return incomplete HTML.
