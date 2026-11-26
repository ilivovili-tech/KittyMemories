import SwiftUI
import SwiftData
import UIKit

struct StickerEditorView: View {
    @Environment(\.modelContext) private var context
    @Bindable var entry: PhotoEntry
    @State private var selectedID: UUID?
    @State private var dragOffset: CGSize = .zero
    @State private var magnification: CGFloat = 1
    @State private var rotation: Angle = .zero
    @State private var showingStickerPicker = false
    @State private var shareImage: UIImage?
    @State private var exportError: String?

    private var selectedSticker: PlacedSticker? {
        entry.stickers.first { $0.id == selectedID }
    }

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .topLeading) {
                Color.black.opacity(0.035)
                if let url = LocalFileStore.url(entry.photoFileName, in: .photos),
                   let image = UIImage(contentsOfFile: url.path) {
                    let rect = aspectFitRect(imageSize: image.size, in: proxy.size)
                    Image(uiImage: image).resizable().scaledToFit()
                        .frame(width: rect.width, height: rect.height)
                        .position(x: rect.midX, y: rect.midY)
                    ForEach(entry.stickers.sorted { $0.zIndex < $1.zIndex }) { placed in
                        layer(for: placed, photoRect: rect)
                    }
                }
            }
            .contentShape(Rectangle())
            .onTapGesture { selectedID = nil }
        }
        .navigationTitle("贴纸 DIY")
        .sheet(isPresented: $showingStickerPicker) {
            StickerPickerView { sticker in
                let nextZ = (entry.stickers.map(\.zIndex).max() ?? -1) + 1
                let placed = PlacedSticker(sticker: sticker, zIndex: nextZ, photoEntry: entry)
                entry.stickers.append(placed)
                context.insert(placed)
                selectedID = placed.id
            }
        }
        .sheet(item: Binding(
            get: { shareImage.map(ShareImageItem.init) },
            set: { shareImage = $0?.image }
        )) { item in
            ActivityShareView(items: [item.image])
        }
        .alert("导出失败", isPresented: Binding(
            get: { exportError != nil },
            set: { if !$0 { exportError = nil } }
        )) {
            Button("好", role: .cancel) { exportError = nil }
        } message: {
            Text(exportError ?? "无法生成图片。")
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { showingStickerPicker = true } label: { Label("添加贴纸", systemImage: "plus") }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button("置顶") {
                    guard let selectedSticker else { return }
                    selectedSticker.zIndex = (entry.stickers.map(\.zIndex).max() ?? 0) + 1
                }.disabled(selectedID == nil)
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button { exportComposition() } label: {
                    Label("分享", systemImage: "square.and.arrow.up")
                }
            }
        }
    }

    @MainActor private func exportComposition() {
        guard let photoURL = LocalFileStore.url(entry.photoFileName, in: .photos),
              let photo = UIImage(contentsOfFile: photoURL.path) else {
            exportError = "找不到原始照片。"
            return
        }
        let canvas = ZStack {
            Image(uiImage: photo).resizable().frame(width: photo.size.width, height: photo.size.height)
            ForEach(entry.stickers.sorted { $0.zIndex < $1.zIndex }) { placed in
                if let sticker = placed.sticker,
                   let url = LocalFileStore.url(sticker.imageFileName, in: .stickers),
                   let image = UIImage(contentsOfFile: url.path) {
                    Image(uiImage: image).resizable().scaledToFit()
                        .frame(width: photo.size.width * 0.22 * placed.scale)
                        .rotationEffect(.radians(placed.rotation))
                        .position(x: photo.size.width * placed.positionX,
                                  y: photo.size.height * placed.positionY)
                }
            }
        }.frame(width: photo.size.width, height: photo.size.height)
        let renderer = ImageRenderer(content: canvas)
        renderer.scale = 1
        guard let rendered = renderer.uiImage else {
            exportError = "图片合成失败，请重试。"
            return
        }
        shareImage = rendered
    }

    private func aspectFitRect(imageSize: CGSize, in canvas: CGSize) -> CGRect {
        guard imageSize.width > 0, imageSize.height > 0 else { return CGRect(origin: .zero, size: canvas) }
        let scale = min(canvas.width / imageSize.width, canvas.height / imageSize.height)
        let size = CGSize(width: imageSize.width * scale, height: imageSize.height * scale)
        return CGRect(x: (canvas.width - size.width) / 2,
                      y: (canvas.height - size.height) / 2,
                      width: size.width, height: size.height)
    }

    @ViewBuilder private func layer(for placed: PlacedSticker, photoRect: CGRect) -> some View {
        if let sticker = placed.sticker,
           let url = LocalFileStore.url(sticker.imageFileName, in: .stickers),
           let image = UIImage(contentsOfFile: url.path) {
            let selected = selectedID == placed.id
            let visual = Image(uiImage: image).resizable().scaledToFit()
                .frame(width: 92 * placed.scale * (selected ? magnification : 1))
                .rotationEffect(.radians(placed.rotation) + (selected ? rotation : .zero))
                .position(x: photoRect.minX + photoRect.width * placed.positionX + (selected ? dragOffset.width : 0),
                          y: photoRect.minY + photoRect.height * placed.positionY + (selected ? dragOffset.height : 0))
                .overlay {
                    if selected {
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(.pink, style: StrokeStyle(lineWidth: 1.5, dash: [5]))
                    }
                }
            if selected {
                visual
                    .gesture(editingGesture(for: placed, photoRect: photoRect))
                    .overlay(alignment: .topTrailing) {
                        Button {
                            entry.stickers.removeAll { $0.id == placed.id }
                            context.delete(placed)
                            selectedID = nil
                        } label: {
                            Image(systemName: "xmark.circle.fill").foregroundStyle(.red).font(.title2)
                        }.offset(x: 12, y: -12)
                    }
            } else {
                visual.onTapGesture {
                    selectedID = placed.id
                    placed.zIndex = (entry.stickers.map(\.zIndex).max() ?? 0) + 1
                }
            }
        } else {
            EmptyView()
        }
    }

    private func editingGesture(for placed: PlacedSticker, photoRect: CGRect) -> some Gesture {
        let drag = DragGesture().onChanged { dragOffset = $0.translation }.onEnded {
            placed.positionX = min(1, max(0, placed.positionX + $0.translation.width / max(photoRect.width, 1)))
            placed.positionY = min(1, max(0, placed.positionY + $0.translation.height / max(photoRect.height, 1)))
            dragOffset = .zero
        }
        let magnify = MagnificationGesture().onChanged { magnification = $0 }.onEnded {
            placed.scale = min(5, max(0.2, placed.scale * $0)); magnification = 1
        }
        let rotate = RotationGesture().onChanged { rotation = $0 }.onEnded {
            placed.rotation += $0.radians; rotation = .zero
        }
        return SimultaneousGesture(SimultaneousGesture(drag, magnify), rotate)
    }
}

private struct ShareImageItem: Identifiable {
    let id = UUID()
    let image: UIImage
}

private struct ActivityShareView: UIViewControllerRepresentable {
    let items: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}
