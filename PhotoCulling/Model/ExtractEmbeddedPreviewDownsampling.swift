import Foundation
import ImageIO
import OSLog
import UniformTypeIdentifiers

actor ExtractEmbeddedPreviewDownsampling {
    // Target size for culling previews (width or height)
    // The system will resize the image to fit within this box during extraction
    // Above 8640 extracs full size
    let maxThumbnailSize: CGFloat = 8000

    // Cannot use @concurrent nonisolated here, the func getWidth
    // will not work then.
    // The func extractEmbeddedPreview and func getWidth must be on the same isolation
    func extractEmbeddedPreview(from arwURL: URL) async -> CGImage? {
        guard let imageSource = CGImageSourceCreateWithURL(arwURL as CFURL, nil) else {
            Logger.process.warning("Failed to create image source")
            return nil
        }

        let imageCount = CGImageSourceGetCount(imageSource)
        Logger.process.debugThreadOnly("ExtractEmbeddedPreview: found \(imageCount) images in ARW file")

        var targetIndex: Int = -1
        var targetWidth = 0

        // 1. Find the LARGEST JPEG available
        for index in 0 ..< imageCount {
            guard let properties = CGImageSourceCopyPropertiesAtIndex(imageSource, index, nil) as? [CFString: Any] else {
                continue
            }

            // Detect JPEG
            let hasJFIF = (properties[kCGImagePropertyJFIFDictionary] as? [CFString: Any]) != nil
            let tiffDict = properties[kCGImagePropertyTIFFDictionary] as? [CFString: Any]
            let compression = tiffDict?[kCGImagePropertyTIFFCompression] as? Int
            let isJPEG = hasJFIF || (compression == 6)

            guard isJPEG else { continue }

            if let width = getWidth(from: properties) {
                // We track the widest JPEG found to get the best quality source
                if width > targetWidth {
                    targetWidth = width
                    targetIndex = index
                }
                Logger.process.debugMessageOnly("ExtractEmbeddedPreview: Index \(index) - JPEG \(width)px wide")
            }
        }

        // If no JPEG found, we are out of luck
        guard targetIndex != -1 else {
            Logger.process.warning("ExtractEmbeddedPreview: No JPEG found in file")
            return nil
        }

        Logger.process.info("ExtractEmbeddedPreview: Selected JPEG at index \(targetIndex) (\(targetWidth)px). Target: \(maxThumbnailSize)")

        // 2. Decide: Downsample or Decode Directly?
        // We only downsample if the source image is LARGER than our desired maxThumbnailSize.
        // If the source is smaller (e.g. a 2048px preview inside the ARW), we keep it as is (don't upscale).

        let requiresDownsampling = CGFloat(targetWidth) > maxThumbnailSize

        if requiresDownsampling {
            Logger.process.info("ExtractEmbeddedPreview: Downsampling to \(maxThumbnailSize)px")

            let options: [CFString: Any] = [
                kCGImageSourceCreateThumbnailFromImageIfAbsent: true,
                kCGImageSourceCreateThumbnailWithTransform: true, // Fixes rotation if needed
                kCGImageSourceThumbnailMaxPixelSize: maxThumbnailSize
            ]

            return CGImageSourceCreateThumbnailAtIndex(imageSource, targetIndex, options as CFDictionary)
        } else {
            Logger.process.info("ExtractEmbeddedPreview: Using original preview size (\(targetWidth)px)")
            // It's already small enough, just decode normally
            let options: [CFString: Any] = [
                kCGImageSourceShouldCacheImmediately: true,
                kCGImageSourceShouldAllowFloat: false
            ]
            return CGImageSourceCreateImageAtIndex(imageSource, targetIndex, options as CFDictionary)
        }
    }

    func getWidth(from properties: [CFString: Any]) -> Int? {
        // Try Root
        if let w = properties[kCGImagePropertyPixelWidth] as? Int { return w }
        if let w = properties[kCGImagePropertyPixelWidth] as? Double { return Int(w) }

        // Try EXIF Dictionary
        if let exif = properties[kCGImagePropertyExifDictionary] as? [CFString: Any] {
            if let w = exif[kCGImagePropertyExifPixelXDimension] as? Int { return w }
            if let w = exif[kCGImagePropertyExifPixelXDimension] as? Double { return Int(w) }
        }

        return nil
    }

    /// Saves the extracted CGImage to disk as a JPEG.
    /// - Parameters:
    ///   - image: The CGImage to save.
    ///   - originalURL: The URL of the source ARW file (used to generate the filename).
    @concurrent
    nonisolated func save(image: CGImage, originalURL: URL) async {
        let outputURL = originalURL.deletingPathExtension().appendingPathExtension("jpg")

        Logger.process.info("ExtractEmbeddedPreview: Attempting to save to \(outputURL.path)")

        guard let destination = CGImageDestinationCreateWithURL(outputURL as CFURL, UTType.jpeg.identifier as CFString, 1, nil) else {
            Logger.process.error("ExtractEmbeddedPreview: Failed to create image destination at \(outputURL.path)")
            return
        }

        let options: [CFString: Any] = [
            kCGImageDestinationLossyCompressionQuality: 1.0
        ]

        CGImageDestinationAddImage(destination, image, options as CFDictionary)
        let success = CGImageDestinationFinalize(destination)

        if success {
            // Log the actual output size for verification
            Logger.process.info("ExtractEmbeddedPreview: Successfully saved JPEG. Output Dimensions: \(image.width)x\(image.height)")
        } else {
            Logger.process.error("ExtractEmbeddedPreview: Failed to finalize image writing")
        }
    }
}
