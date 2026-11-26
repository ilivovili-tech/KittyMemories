import SwiftUI
import SwiftData
import UIKit

@MainActor
final class KittyOrientationDelegate: NSObject, UIApplicationDelegate {
    static var preferredMask: UIInterfaceOrientationMask = .landscape

    func application(
        _ application: UIApplication,
        supportedInterfaceOrientationsFor window: UIWindow?
    ) -> UIInterfaceOrientationMask {
        Self.preferredMask
    }
}

@main
struct KittyMemoriesApp: App {
    @UIApplicationDelegateAdaptor(KittyOrientationDelegate.self) private var orientationDelegate
    private let container: ModelContainer

    init() {
        do {
            container = try ModelContainer(for: PhotoEntry.self, DIYSticker.self, PlacedSticker.self, AnniversaryEntry.self, AnniversaryPhoto.self)
        } catch {
            fatalError("Unable to create local data store: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            MainTabView()
                .modelContainer(container)
                .tint(.pink)
        }
    }
}
