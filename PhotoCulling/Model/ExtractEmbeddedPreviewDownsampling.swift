import Foundation
import ImageIO
import OSLog
import UniformTypeIdentifiers

struct ExtractEmbeddedPreviewDownsampling {
    // Target size for culling previews (width or height)
    // The system will resize the image to fit within this box during extraction
    let maxThumbnailSize: CGFloat = 4096

    func extractEmbeddedPreview(from arwURL: URL) -> CGImage? {
        guard let imageSource = CGImageSourceCreateWithURL(arwURL as CFURL, nil) else {
            Logger.process.warning("Failed to create image source")
            return nil
        }

        let imageCount = CGImageSourceGetCount(imageSource)
        Logger.process.debugThreadOnly("ExtractEmbeddedPreview: found \(imageCount) images in ARW file")

        var targetIndex: Int = -1
        var targetWidth = 0
        var requiresDownsampling = false

        for index in 0 ..< imageCount {
            guard let properties = CGImageSourceCopyPropertiesAtIndex(imageSource, index, nil) as? [CFString: Any] else {
                continue
            }

            // 1. Detect JPEG
            let hasJFIF = (properties[kCGImagePropertyJFIFDictionary] as? [CFString: Any]) != nil
            let tiffDict = properties[kCGImagePropertyTIFFDictionary] as? [CFString: Any]
            let compression = tiffDict?[kCGImagePropertyTIFFCompression] as? Int
            let isJPEG = hasJFIF || (compression == 6)

            guard isJPEG else { continue } // Skip non-JPEGs (RAW)

            // 2. Get Width
            let width = ExtractEmbeddedPreview.getWidth(from: properties)
            guard let w = width else { continue }

            Logger.process.debugMessageOnly("ExtractEmbeddedPreview: Index \(index) - JPEG \(w)px wide")

            // Logic:
            // If we find a small JPEG (< 3000px), take it immediately (it's the native preview).
            // If we only find a huge JPEG (> 3000px), we'll take it, but flag it for downsampling.
            if w < 3000 {
                targetIndex = index
                targetWidth = w
                requiresDownsampling = false
                // Found a native small preview, stop looking
                break
            } else if w > targetWidth {
                // Track the largest JPEG (likely the full-size embedded one)
                targetIndex = index
                targetWidth = w
                requiresDownsampling = true
            }
        }

        // If no JPEG found, we are out of luck (or we'd have to decode RAW)
        guard targetIndex != -1 else {
            Logger.process.warning("ExtractEmbeddedPreview: No JPEG found in file")
            return nil
        }

        Logger.process.info("ExtractEmbeddedPreview: Selected JPEG at index \(targetIndex) (\(targetWidth)px). Downsampling: \(requiresDownsampling)")

        // 3. Decode
        if requiresDownsampling {
            // Create a Thumbnail. This is the magic:
            // It decodes the JPEG but subsamples it to `maxThumbnailSize` during the read process.
            // This avoids loading the full 17MB / 8640px image into memory.
            let options: [CFString: Any] = [
                kCGImageSourceCreateThumbnailFromImageIfAbsent: true,
                kCGImageSourceCreateThumbnailWithTransform: true, // Fixes rotation if needed
                kCGImageSourceThumbnailMaxPixelSize: maxThumbnailSize
            ]

            return CGImageSourceCreateThumbnailAtIndex(imageSource, targetIndex, options as CFDictionary)
        } else {
            // It's already small, just decode normally
            let options: [CFString: Any] = [
                kCGImageSourceShouldCacheImmediately: true,
                kCGImageSourceShouldAllowFloat: false
            ]
            return CGImageSourceCreateImageAtIndex(imageSource, targetIndex, options as CFDictionary)
        }
    }

    static func getWidth(from properties: [CFString: Any]) -> Int? {
        if let w = properties[kCGImagePropertyPixelWidth] as? Int { return w }
        if let w = properties[kCGImagePropertyPixelWidth] as? Double { return Int(w) }
        if let exif = properties[kCGImagePropertyExifDictionary] as? [CFString: Any] {
            if let w = exif[kCGImagePropertyExifPixelXDimension] as? Int { return w }
            if let w = exif[kCGImagePropertyExifPixelXDimension] as? Double { return Int(w) }
        }
        return nil
    }

    // Save function remains the same...
    func save(image: CGImage, originalURL: URL) -> URL? {
        let outputURL = originalURL.deletingPathExtension().appendingPathExtension("jpg")
        guard let destination = CGImageDestinationCreateWithURL(outputURL as CFURL, UTType.jpeg.identifier as CFString, 1, nil) else { return nil }

        // If we downsampled, we save at high quality (0.9).
        // If it was originally 17MB, it will now be roughly 500KB - 1MB.
        let options: [CFString: Any] = [kCGImageDestinationLossyCompressionQuality: 0.9]
        CGImageDestinationAddImage(destination, image, options as CFDictionary)

        if CGImageDestinationFinalize(destination) { return outputURL }
        return nil
    }
}
