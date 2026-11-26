import SwiftUI
import SwiftData

@main
struct KittyMemoriesApp: App {
    private let container: ModelContainer
    init() {
        do {
            container = try ModelContainer(for: PhotoEntry.self, DIYSticker.self, PlacedSticker.self, AnniversaryEntry.self, AnniversaryPhoto.self)
        } catch { fatalError("Unable to create local data store: \(error)") }
    }
    var body: some Scene {
        WindowGroup {
            MainTabView().modelContainer(container).tint(.pink)
        }
    }
}
