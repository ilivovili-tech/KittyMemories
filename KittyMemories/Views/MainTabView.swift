import SwiftUI

struct MainTabView: View {
    @Namespace private var glassNamespace
    @State private var selection = 0
    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                GlassEffectContainer(spacing: 16) {
                    HStack(spacing: 10) {
                        moduleButton("相册", symbol: "book.closed.fill", index: 0)
                        moduleButton("纪念日", symbol: "heart.fill", index: 1)
                    }.padding(.horizontal)
                }
                Group {
                    if selection == 0 {
                        AlbumHomeView().transition(.asymmetric(insertion: .move(edge: .leading).combined(with: .opacity), removal: .move(edge: .trailing).combined(with: .opacity)))
                    } else {
                        AnniversaryHomeView().transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity), removal: .move(edge: .leading).combined(with: .opacity)))
                    }
                }.frame(maxWidth: .infinity, maxHeight: .infinity)
                NavigationLink { StickerLibraryView() } label: {
                    Label("DIY 素材库", systemImage: "sparkles").font(.headline).padding(.horizontal, 22).padding(.vertical, 12).glassEffect(.regular, in: .capsule)
                }.padding(.bottom, 8)
            }.navigationBarTitleDisplayMode(.inline)
        }.animation(.spring(response: 0.55, dampingFraction: 0.82), value: selection)
    }
    private func moduleButton(_ title: String, symbol: String, index: Int) -> some View {
        Button { withAnimation(.spring(response: 0.55, dampingFraction: 0.78)) { selection = index } } label: {
            Label(title, systemImage: symbol).font(.headline).frame(maxWidth: .infinity).padding(.vertical, 13)
                .foregroundStyle(selection == index ? Color.primary : Color.secondary)
                .glassEffect(selection == index ? .regular.tint(.pink.opacity(0.2)) : .clear, in: .capsule)
                .glassEffectID("module-\(index)", in: glassNamespace)
        }.buttonStyle(.plain)
    }
}
