import Foundation

enum LocalFileStore {
    enum Folder: String { case photos = "Photos", stickers = "Stickers" }
    static func directory(_ folder: Folder) throws -> URL {
        let support = try FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
        let url = support.appendingPathComponent(folder.rawValue, isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }
    static func save(_ data: Data, in folder: Folder, fileExtension: String = "jpg") throws -> String {
        let name = UUID().uuidString + "." + fileExtension
        try data.write(to: directory(folder).appendingPathComponent(name), options: .atomic)
        return name
    }
    static func url(_ name: String, in folder: Folder) -> URL? {
        guard !name.contains("/"), !name.contains("..") else { return nil }
        return try? directory(folder).appendingPathComponent(name)
    }
    static func delete(_ name: String, from folder: Folder) {
        guard let url = url(name, in: folder) else { return }
        try? FileManager.default.removeItem(at: url)
    }
}
