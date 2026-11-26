import Foundation
import SwiftData
import UIKit
import SwiftSoup

struct StickerImportResult {
    let success: Int
    let failed: Int
}

@MainActor
final class WeChatStickerImporter {
    static let shared = WeChatStickerImporter()
    private let userAgent = "Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.0 Mobile/15E148 MicroMessenger/8.0.55(0x1800372b) NetType/WIFI Language/zh_CN"
    private let referer = "https://mp.weixin.qq.com/"

    func importFromClipboard(into context: ModelContext) async throws -> StickerImportResult {
        guard let url = UIPasteboard.general.url, url.host?.contains("mp.weixin.qq.com") == true else {
            throw ImportError.invalidClipboard
        }
        return try await importArticle(url, into: context)
    }

    func importArticle(_ url: URL, into context: ModelContext) async throws -> StickerImportResult {
        guard url.host?.contains("mp.weixin.qq.com") == true else { throw ImportError.invalidURL }
        var request = URLRequest(url: url)
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        request.setValue(referer, forHTTPHeaderField: "Referer")
        request.timeoutInterval = 30
        let (html, response) = try await URLSession.shared.data(for: request)
        guard (response as? HTTPURLResponse)?.statusCode == 200,
              let htmlText = String(data: html, encoding: .utf8) else { throw ImportError.articleUnavailable }

        let document = try SwiftSoup.parse(htmlText)
        let images = try document.select("#js_content img")
        var links: [URL] = []
        for image in images.array() {
            let raw = (try? image.attr("data-src")).flatMap { $0.isEmpty ? nil : $0 }
                ?? (try? image.attr("src")) ?? ""
            guard let candidate = URL(string: raw), candidate.host?.contains("mmbiz.qpic.cn") == true else { continue }
            if !links.contains(candidate) { links.append(candidate) }
        }

        var success = 0
        var failed = 0
        for (index, imageURL) in links.enumerated() {
            do {
                var imageRequest = URLRequest(url: imageURL)
                imageRequest.setValue(userAgent, forHTTPHeaderField: "User-Agent")
                imageRequest.setValue(referer, forHTTPHeaderField: "Referer")
                imageRequest.timeoutInterval = 25
                let (data, imageResponse) = try await URLSession.shared.data(for: imageRequest)
                guard (imageResponse as? HTTPURLResponse)?.statusCode == 200,
                      let type = imageResponse.mimeType, type.hasPrefix("image/"),
                      UIImage(data: data) != nil else { throw ImportError.invalidImage }
                let ext: String
                switch type.lowercased() {
                case "image/gif": ext = "gif"
                case "image/png": ext = "png"
                case "image/webp": ext = "webp"
                default: ext = "jpg"
                }
                let file = try LocalFileStore.save(data, in: .stickers, fileExtension: ext)
                context.insert(DIYSticker(name: "微信素材 \(Date.now.formatted(date: .numeric, time: .shortened)) · \(index + 1)",
                                          imageFileName: file, source: "clipboard"))
                success += 1
            } catch {
                failed += 1
            }
        }
        try context.save()
        return StickerImportResult(success: success, failed: failed)
    }

    enum ImportError: LocalizedError {
        case invalidClipboard, invalidURL, articleUnavailable, invalidImage
        var errorDescription: String? {
            switch self {
            case .invalidClipboard: return "剪贴板中没有微信文章链接。"
            case .invalidURL: return "仅支持 mp.weixin.qq.com 公众号文章链接。"
            case .articleUnavailable: return "文章暂时无法读取，可能需要在微信中打开后重试。"
            case .invalidImage: return "图片格式无效。"
            }
        }
    }
}
