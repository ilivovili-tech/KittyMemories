# KittyMemories 🎀

Private native SwiftUI app. Deployment target is intentionally set to iOS 27.0, with landscape-left and landscape-right orientations only.

## Implemented
- Independent Album and Anniversary SwiftData models.
- Private Application Support storage for album photos, anniversary photos and imported stickers.
- PhotosPicker imports copy images into the app sandbox; the app never writes to the Photos library.
- Year → month → day album navigation with book/page and vertical browsing modes; browse preference persists.
- Paper-like 3D page-turn interaction and shared Liquid Glass module selection.
- Per-photo date and thought text, plus normalized-coordinate sticker placement, drag, scale, rotate, z-order and delete controls.
- On-demand ImageRenderer composition export and iOS share sheet.
- Independent anniversary entries with photo add/delete and local-file cleanup when entries or photos are deleted.
- WeChat article importer with strict HTTPS host validation, MicroMessenger user agent, Referer, #js_content extraction, image validation and partial-failure reporting.
- Clipboard import attempt when the sticker library opens or the app becomes active, plus manual import.
- Imported sticker library with GIF preview and optional Vision foreground-mask cutout; failed cutouts preserve the source image.
- Private file sharing and opening-in-place disabled.

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

## Remaining work
- Download and visually curate the 16 user-provided WeChat article images, then package approved frame assets in Images.xcassets.
- Add and test distinct built-in Hello Kitty frame styles for album photos.
- Complete real-device testing on iOS 27, especially orientation, GIF playback, PhotosPicker imports, SwiftData persistence, gestures and share-sheet behavior.
- Review WeChat importer behavior against the actual articles; WeChat may block automated requests or return incomplete HTML.
