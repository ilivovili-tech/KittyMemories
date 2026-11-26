import Foundation
import Vision
import CoreImage
import CoreVideo
import ImageIO

enum StickerCutoutError: LocalizedError {
    case noForeground, cannotRender
    var errorDescription: String? {
        switch self {
        case .noForeground: return "没有识别到可抠出的主体，已保留原图。"
        case .cannotRender: return "透明图片生成失败，已保留原图。"
        }
    }
}

enum StickerCutoutService {
    static func makeTransparentPNG(from url: URL) throws -> Data {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
            throw StickerCutoutError.cannotRender
        }
        let request = VNGenerateForegroundInstanceMaskRequest()
        let handler = VNImageRequestHandler(cgImage: image)
        try handler.perform([request])
        guard let observation = request.results?.first else { throw StickerCutoutError.noForeground }
        let maskBuffer = try observation.generateScaledMaskForImage(
            forInstances: observation.allInstances,
            from: handler
        )
        let foreground = CIImage(cgImage: image)
        let mask = CIImage(cvPixelBuffer: maskBuffer)
        let output = foreground.applyingFilter("CIBlendWithMask", parameters: [
            kCIInputBackgroundImageKey: CIImage(color: CIColor(red: 0, green: 0, blue: 0, alpha: 0)).cropped(to: foreground.extent),
            kCIInputMaskImageKey: mask
        ])
        let context = CIContext()
        guard let result = context.createCGImage(output, from: foreground.extent) else {
            throw StickerCutoutError.cannotRender
        }
        return try pngData(result)
    }

    private static func pngData(_ image: CGImage) throws -> Data {
        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(data, "public.png" as CFString, 1, nil) else {
            throw StickerCutoutError.cannotRender
        }
        CGImageDestinationAddImage(destination, image, nil)
        guard CGImageDestinationFinalize(destination), data.length > 0 else {
            throw StickerCutoutError.cannotRender
        }
        return data as Data
    }
}