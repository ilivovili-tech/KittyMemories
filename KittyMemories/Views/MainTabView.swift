import SwiftUI
import UIKit

struct MainTabView: View {
    @Namespace private var glassNamespace
    @State private var selection = 0
    @AppStorage("preferredOrientation") private var preferredOrientation = "landscape"

    var body: some View {
        NavigationStack {
            GeometryReader { geometry in
                let railWidth = min(max(geometry.size.width * 0.13, 58), 76)
                HStack(spacing: 0) {
                    VStack(spacing: 8) {
                        moduleButton("相册", symbol: "book.closed.fill", index: 0)
                        moduleButton("纪念日", symbol: "heart.fill", index: 1)
                        Spacer(minLength: 8)
                        Button {
                            preferredOrientation = preferredOrientation == "landscape" ? "portrait" : "landscape"
                            applyPreferredOrientation()
                        } label: {
                            VStack(spacing: 4) {
                                Image(systemName: preferredOrientation == "landscape" ? "rectangle.portrait" : "rectangle.landscape")
                                    .font(.system(size: 15, weight: .medium))
                                Text(preferredOrientation == "landscape" ? "竖屏" : "横屏")
                                    .font(.system(size: 10, weight: .medium))
                            }
                            .foregroundStyle(.secondary)
                            .frame(width: railWidth - 12, height: 48)
                            .contentShape(RoundedRectangle(cornerRadius: 13))
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("切换屏幕方向")
                    }
                    .padding(.horizontal, 5)
                    .padding(.vertical, 10)
                    .frame(width: railWidth, height: geometry.size.height)
                    .background(.ultraThinMaterial)

                    Rectangle().fill(.quaternary).frame(width: 0.5)

                    Group {
                        if selection == 0 {
                            AlbumHomeView()
                                .transition(.asymmetric(insertion: .move(edge: .leading).combined(with: .opacity), removal: .move(edge: .trailing).combined(with: .opacity)))
                        } else {
                            AnniversaryHomeView()
                                .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity), removal: .move(edge: .leading).combined(with: .opacity)))
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .toolbar(.hidden, for: .navigationBar)
        }
        .controlSize(.small)
        .animation(.spring(response: 0.42, dampingFraction: 0.84), value: selection)
        .onAppear(perform: applyPreferredOrientation)
    }

    private func moduleButton(_ title: String, symbol: String, index: Int) -> some View {
        Button {
            withAnimation(.spring(response: 0.42, dampingFraction: 0.82)) { selection = index }
        } label: {
            VStack(spacing: 4) {
                Image(systemName: symbol).font(.system(size: 16, weight: .medium))
                Text(title).font(.system(size: 10, weight: .semibold)).lineLimit(1).minimumScaleFactor(0.8)
            }
            .frame(width: 64, height: 50)
            .foregroundStyle(selection == index ? Color.primary : Color.secondary)
            .background {
                if selection == index {
                    RoundedRectangle(cornerRadius: 14)
                        .fill(Color.pink.opacity(0.10))
                        .glassEffect(.regular.tint(.pink.opacity(0.18)), in: .rect(cornerRadius: 14))
                        .glassEffectID("active-module-indicator", in: glassNamespace)
                }
            }
            .contentShape(RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(.plain)
    }

    private func applyPreferredOrientation() {
        let mask: UIInterfaceOrientationMask = preferredOrientation == "portrait" ? .portrait : .landscape
        KittyOrientationDelegate.preferredMask = mask
        for scene in UIApplication.shared.connectedScenes {
            guard let windowScene = scene as? UIWindowScene else { continue }
            windowScene.windows.first?.rootViewController?.setNeedsUpdateOfSupportedInterfaceOrientations()
            windowScene.requestGeometryUpdate(.iOS(interfaceOrientations: mask)) { _ in }
        }
    }
}
