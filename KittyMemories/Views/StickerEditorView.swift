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

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                Color.black.opacity(0.035)
                if let url = LocalFileStore.url(entry.photoFileName, in: .photos),
                   let image = UIImage(contentsOfFile: url.path) {
                    Image(uiImage: image).resizable().scaledToFit()
                        .frame(maxWidth: proxy.size.width, maxHeight: proxy.size.height)
                }
                ForEach(entry.stickers.sorted { $0.zIndex < $1.zIndex }) { placed in
                    layer(for: placed, canvas: proxy.size)
                }
            }.contentShape(Rectangle())
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
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { showingStickerPicker = true } label: { Label("添加贴纸", systemImage: "plus") }
            }
        }
    }

    @ViewBuilder private func layer(for placed: PlacedSticker, canvas: CGSize) -> some View {
        if let sticker = placed.sticker,
           let url = LocalFileStore.url(sticker.imageFileName, in: .stickers),
           let image = UIImage(contentsOfFile: url.path) {
            let selected = selectedID == placed.id
            let visual = Image(uiImage: image).resizable().scaledToFit()
                .frame(width: 92 * placed.scale * (selected ? magnification : 1))
                .rotationEffect(.radians(placed.rotation) + (selected ? rotation : .zero))
                .position(x: canvas.width * placed.positionX + (selected ? dragOffset.width : 0),
                          y: canvas.height * placed.positionY + (selected ? dragOffset.height : 0))
                .overlay {
                    if selected {
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(.pink, style: StrokeStyle(lineWidth: 1.5, dash: [5]))
                    }
                }
            if selected {
                visual
                    .gesture(editingGesture(for: placed, canvas: canvas))
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
        } else if selectedID == placed.id {
            Text("素材已删除").font(.caption).foregroundStyle(.secondary)
        }
    }

    private func editingGesture(for placed: PlacedSticker, canvas: CGSize) -> some Gesture {
        let drag = DragGesture().onChanged { dragOffset = $0.translation }.onEnded {
            placed.positionX = min(1, max(0, placed.positionX + $0.translation.width / max(canvas.width, 1)))
            placed.positionY = min(1, max(0, placed.positionY + $0.translation.height / max(canvas.height, 1)))
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
