import Foundation
import SwiftData

@Model
final class AnniversaryEntry {
    @Attribute(.unique) var id: UUID
    var title: String
    var date: Date
    @Relationship(deleteRule: .cascade, inverse: \AnniversaryPhoto.anniversary) var photos: [AnniversaryPhoto] = []
    init(id: UUID = UUID(), title: String, date: Date) { self.id = id; self.title = title; self.date = date }
}

@Model
final class AnniversaryPhoto {
    @Attribute(.unique) var id: UUID
    var fileName: String
    var anniversary: AnniversaryEntry?
    init(id: UUID = UUID(), fileName: String, anniversary: AnniversaryEntry? = nil) {
        self.id = id; self.fileName = fileName; self.anniversary = anniversary
    }
}
