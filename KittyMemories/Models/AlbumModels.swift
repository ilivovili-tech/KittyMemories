import Foundation
import SwiftData

@Model
final class PhotoEntry {
    @Attribute(.unique) var id: UUID
    var photoFileName: String
    var customDate: Date
    var thought: String
    @Relationship(deleteRule: .cascade, inverse: \PlacedSticker.photoEntry) var stickers: [PlacedSticker] = []
    init(id: UUID = UUID(), photoFileName: String, customDate: Date = .now, thought: String = "") {
        self.id = id; self.photoFileName = photoFileName; self.customDate = customDate; self.thought = thought
    }
}

@Model
final class DIYSticker {
    @Attribute(.unique) var id: UUID
    var name: String
    var imageFileName: String
    var source: String
    var createdAt: Date
    @Relationship(deleteRule: .nullify, inverse: \PlacedSticker.sticker) var placements: [PlacedSticker] = []
    init(id: UUID = UUID(), name: String, imageFileName: String, source: String, createdAt: Date = .now) {
        self.id = id; self.name = name; self.imageFileName = imageFileName; self.source = source; self.createdAt = createdAt
    }
}

@Model
final class PlacedSticker {
    @Attribute(.unique) var id: UUID
    var positionX: Double
    var positionY: Double
    var scale: Double
    var rotation: Double
    var zIndex: Int
    var sticker: DIYSticker?
    var photoEntry: PhotoEntry?
    init(id: UUID = UUID(), sticker: DIYSticker?, positionX: Double = 0.5, positionY: Double = 0.5, scale: Double = 1, rotation: Double = 0, zIndex: Int = 0, photoEntry: PhotoEntry? = nil) {
        self.id = id; self.sticker = sticker; self.positionX = positionX; self.positionY = positionY
        self.scale = scale; self.rotation = rotation; self.zIndex = zIndex; self.photoEntry = photoEntry
    }
}
