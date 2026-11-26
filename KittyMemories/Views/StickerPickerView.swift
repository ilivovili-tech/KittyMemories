import SwiftUI
import SwiftData
import UIKit

struct StickerPickerView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \DIYSticker.createdAt, order: .reverse) private var stickers: [DIYSticker]
    let onSelect: (DIYSticker) -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 104), spacing: 14)], spacing: 14) {
                    ForEach(stickers) { sticker in
                        Button {
                            onSelect(sticker)
                            dismiss()
                        } label: {
                            VStack(spacing: 8) {
                                if let url = LocalFileStore.url(sticker.imageFileName, in: .stickers),
                                   let image = UIImage(contentsOfFile: url.path) {
                                    Image(uiImage: image).resizable().scaledToFit().frame(height: 92)
                                } else {
                                    Image(systemName: "photo").font(.largeTitle).frame(height: 92)
                                }
                                Text(sticker.name).font(.caption).lineLimit(2)
                            }.frame(maxWidth: .infinity).padding(10)
                                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
                        }.buttonStyle(.plain)
                    }
                }.padding()
                if stickers.isEmpty {
                    ContentUnavailableView("素材库还是空的", systemImage: "sparkles",
                        description: Text("先导入公众号图片，再回来添加贴纸。"))
                }
            }
            .navigationTitle("选择贴纸")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { Button("关闭") { dismiss() } }
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink { StickerLibraryView() } label: { Image(systemName: "square.and.arrow.down") }
                }
            }
        }
    }
}