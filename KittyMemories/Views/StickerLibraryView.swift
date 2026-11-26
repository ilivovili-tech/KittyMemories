import SwiftUI
import SwiftData
import UIKit
import ImageIO

struct StickerLibraryView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.scenePhase) private var scenePhase
    @Query(sort: \DIYSticker.createdAt, order: .reverse) private var stickers: [DIYSticker]
    @State private var importing = false
    @State private var statusMessage: String?
    @State private var showStatus = false
    @State private var lastCheckedURL = ""
    @State private var cutoutFailed = Set<UUID>()
    @State private var cuttingOut = Set<UUID>()

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Label("复制公众号链接即可导入", systemImage: "doc.on.clipboard").font(.headline)
                    Text("复制 mp.weixin.qq.com 文章链接后，打开本页面会尝试自动识别并导入。也可以点击右上角手动导入。")
                        .font(.footnote).foregroundStyle(.secondary)
                    if importing { ProgressView("正在解析文章并下载图片…") }
                }.padding(.vertical, 6)
            }
            Section("内置素材 · Hello Kitty") {
                ContentUnavailableView("内置素材包待生成", systemImage: "heart",
                    description: Text("文章图片需要先完成开发阶段筛选，再打包进 App。"))
            }
            Section("导入素材 · \(stickers.count)") {
                if stickers.isEmpty {
                    ContentUnavailableView("暂无导入素材", systemImage: "photo.badge.plus",
                        description: Text("从微信复制公众号文章链接，返回此页面即可尝试导入。"))
                } else {
                    ForEach(stickers) { sticker in
                        HStack(spacing: 12) {
                            if let url = LocalFileStore.url(sticker.imageFileName, in: .stickers),
                               let image = UIImage(contentsOfFile: url.path) {
                                Group {
                                    if sticker.imageFileName.lowercased().hasSuffix(".gif") {
                                        AnimatedStickerPreview(url: url)
                                    } else {
                                        Image(uiImage: image).resizable().scaledToFit()
                                    }
                                }.frame(width: 64, height: 64)
                            }
                            VStack(alignment: .leading, spacing: 5) {
                                Text(sticker.name)
                                Text(sticker.createdAt.formatted()).font(.caption).foregroundStyle(.secondary)
                                if cutoutFailed.contains(sticker.id) {
                                    Text("未抠图").font(.caption2).foregroundStyle(.orange)
                                }
                                if !sticker.imageFileName.lowercased().hasSuffix(".gif") {
                                    Button {
                                        Task { await cutout(sticker) }
                                    } label: {
                                        if cuttingOut.contains(sticker.id) {
                                            ProgressView()
                                        } else {
                                            Label("智能抠图", systemImage: "person.crop.rectangle")
                                                .font(.caption)
                                        }
                                    }.disabled(cuttingOut.contains(sticker.id))
                                }
                            }
                        }
                    }.onDelete(perform: deleteStickers)
                }
            }
        }
        .navigationTitle("DIY 素材库")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { Task { await importClipboard(manual: true) } } label: {
                    if importing { ProgressView() } else { Label("从剪贴板导入", systemImage: "doc.on.clipboard") }
                }.disabled(importing)
            }
        }
        .onAppear { Task { await importClipboard(manual: false) } }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { Task { await importClipboard(manual: false) } }
        }
        .alert("素材导入", isPresented: $showStatus) {
            Button("好", role: .cancel) {}
        } message: { Text(statusMessage ?? "") }
    }

    @MainActor private func importClipboard(manual: Bool) async {
        guard !importing else { return }
        guard let url = UIPasteboard.general.url, url.host?.contains("mp.weixin.qq.com") == true else {
            if manual { statusMessage = "请先复制一条 mp.weixin.qq.com 公众号文章链接。"; showStatus = true }
            return
        }
        let key = url.absoluteString
        if !manual && (key == lastCheckedURL || UserDefaults.standard.string(forKey: "lastImportedWeChatURL") == key) { return }
        lastCheckedURL = key
        importing = true
        defer { importing = false }
        do {
            let result = try await WeChatStickerImporter.shared.importArticle(url, into: context)
            UserDefaults.standard.set(key, forKey: "lastImportedWeChatURL")
            statusMessage = "成功 \(result.success) 张，失败 \(result.failed) 张。"
        } catch {
            statusMessage = error.localizedDescription
        }
        showStatus = true
    }

    @MainActor private func cutout(_ sticker: DIYSticker) async {
        guard let source = LocalFileStore.url(sticker.imageFileName, in: .stickers) else { return }
        cuttingOut.insert(sticker.id)
        defer { cuttingOut.remove(sticker.id) }
        do {
            let png = try await Task.detached(priority: .userInitiated) {
                try StickerCutoutService.makeTransparentPNG(from: source)
            }.value
            let newName = try LocalFileStore.save(png, in: .stickers, fileExtension: "png")
            let oldName = sticker.imageFileName
            sticker.imageFileName = newName
            sticker.name += " · 已抠图"
            LocalFileStore.delete(oldName, from: .stickers)
            cutoutFailed.remove(sticker.id)
            try context.save()
        } catch {
            cutoutFailed.insert(sticker.id)
            statusMessage = error.localizedDescription
            showStatus = true
        }
    }

    private func deleteStickers(at offsets: IndexSet) {
        for index in offsets {
            let sticker = stickers[index]
            LocalFileStore.delete(sticker.imageFileName, from: .stickers)
            context.delete(sticker)
        }
    }
}

private struct AnimatedStickerPreview: UIViewRepresentable {
    let url: URL
    func makeUIView(context: Context) -> UIImageView {
        let view = UIImageView()
        view.contentMode = .scaleAspectFit
        view.image = Self.loadImage(url)
        return view
    }
    func updateUIView(_ uiView: UIImageView, context: Context) {
        uiView.image = Self.loadImage(url)
    }
    private static func loadImage(_ url: URL) -> UIImage? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else {
            return UIImage(contentsOfFile: url.path)
        }
        let count = CGImageSourceGetCount(source)
        guard count > 1 else { return UIImage(contentsOfFile: url.path) }
        var frames: [UIImage] = []
        var duration: TimeInterval = 0
        for index in 0..<count {
            guard let cgImage = CGImageSourceCreateImageAtIndex(source, index, nil) else { continue }
            let properties = CGImageSourceCopyPropertiesAtIndex(source, index, nil) as? [CFString: Any]
            let gif = properties?[kCGImagePropertyGIFDictionary] as? [CFString: Any]
            let delay = (gif?[kCGImagePropertyGIFUnclampedDelayTime] as? NSNumber)?.doubleValue
                ?? (gif?[kCGImagePropertyGIFDelayTime] as? NSNumber)?.doubleValue ?? 0.1
            duration += max(0.04, delay)
            frames.append(UIImage(cgImage: cgImage))
        }
        return UIImage.animatedImage(with: frames, duration: duration)
    }
}
