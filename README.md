# KittyMemories 🎀

Private, offline-first native SwiftUI app targeting iOS 27.

## Initial foundation committed
- Independent Album and Anniversary SwiftData models.
- Private Application Support storage for image files.
- Local photo imports without writing to the system Photos library.
- Year → month → day album navigation with page and vertical browsing choices.
- Liquid Glass module switcher.
- Shared DIY sticker metadata and normalized-coordinate editor foundation.
- GitHub Actions simulator build workflow.

## Build
Requires Xcode 27 and XcodeGen:
```sh
brew install xcodegen
xcodegen generate
xcodebuild -project KittyMemories.xcodeproj -scheme KittyMemories -sdk iphonesimulator -configuration Debug -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO build
```

## Private storage
Images are stored in Application Support/Photos and Application Support/Stickers. File sharing and opening-in-place are disabled.

## Remaining milestones
The full WeChat article importer, GIF playback, Vision foreground cutout, complete sticker picker, custom animated page-turn effect, and bundled Hello Kitty frame assets remain to be implemented. The 16 source article URLs or source materials are required before extracting the requested user-provided artwork.
