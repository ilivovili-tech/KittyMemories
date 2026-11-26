import SwiftUI
import SwiftData
import UIKit

struct StickerLibraryView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \DIYSticker.createdAt, order: .reverse) private var stickers: [DIYSticker]
    var body: some View {
        List {
            Section("内置素材 · Hello Kitty") {
                ContentUnavailableView("等待添加内置素材", systemImage: "heart",
                    description: Text("需要你提供 16 篇公众号文章链接，才能在开发阶段提取并打包素材。"))
            }
            Section("导入素材") {
                if stickers.isEmpty {
                    ContentUnavailableView("暂无导入素材", systemImage: "photo.badge.plus",
                        description: Text("剪贴板文章导入器将在下一阶段接入。"))
                } else {
                    ForEach(stickers) { sticker in
                        HStack(spacing: 12) {
                            if let url = LocalFileStore.url(sticker.imageFileName, in: .stickers),
                               let image = UIImage(contentsOfFile: url.path) {
                                Image(uiImage: image).resizable().scaledToFit().frame(width: 58, height: 58)
                            }
                            VStack(alignment: .leading) {
                                Text(sticker.name)
                                Text(sticker.createdAt.formatted()).font(.caption).foregroundStyle(.secondary)
                            }
                        }
                    }.onDelete(perform: deleteStickers)
                }
            }
        }.navigationTitle("DIY 素材库")
    }
    private func deleteStickers(at offsets: IndexSet) {
        for index in offsets {
            let sticker = stickers[index]
            LocalFileStore.delete(sticker.imageFileName, from: .stickers)
            context.delete(sticker)
        }
    }
}
