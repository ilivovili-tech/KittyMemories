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
        try VNImageRequestHandler(cgImage: image).perform([request])
        guard let observation = request.results?.first else { throw StickerCutoutError.noForeground }
        let maskBuffer = try observation.generateScaledMaskForImage(
            forInstances: observation.allInstances,
            from: VNImageRequestHandler(cgImage: image)
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
        return UIImagePNGRepresentationCompat(result)
    }

    private static func UIImagePNGRepresentationCompat(_ image: CGImage) -> Data {
        let data = NSMutableData()
        if let destination = CGImageDestinationCreateWithData(data, "public.png" as CFString, 1, nil) {
            CGImageDestinationAddImage(destination, image, nil)
            CGImageDestinationFinalize(destination)
        }
        return data as Data
    }
}