import Foundation
import ImageIO
import OSLog
import UniformTypeIdentifiers

struct ExtractEmbeddedPreview {
    func extractEmbeddedPreview(from arwURL: URL) -> CGImage? {
        guard let imageSource = CGImageSourceCreateWithURL(arwURL as CFURL, nil) else {
            Logger.process.warning("Failed to create image source")
            return nil
        }

        let imageCount = CGImageSourceGetCount(imageSource)
        Logger.process.debugThreadOnly("ExtractEmbeddedPreview: found \(imageCount) images in ARW file")

        var bestIndex: Int = -1
        var largestWidth: Int = 0
        
        var jpegIndex: Int = -1
        var jpegWidth: Int = 0

        for index in 0 ..< imageCount {
            guard let properties = CGImageSourceCopyPropertiesAtIndex(imageSource, index, nil) as? [CFString: Any] else {
                continue
            }

            // 1. Detect JPEG.
            // JFIF dictionary is a strong indicator.
            // Compression value of 6 is the definitive indicator for JPEG.
            let hasJFIF = (properties[kCGImagePropertyJFIFDictionary] as? [CFString: Any]) != nil
            let tiffDict = properties[kCGImagePropertyTIFFDictionary] as? [CFString: Any]
            let compression = tiffDict?[kCGImagePropertyTIFFCompression] as? Int
            let isJPEG = hasJFIF || (compression == 6)
            
            // 2. Get Width (Removed the non-existent TIFF constant)
            let width = ExtractEmbeddedPreview.getWidth(from: properties)
            
            guard let w = width else {
                Logger.process.debugMessageOnly("ExtractEmbeddedPreview: Index \(index) - Unknown dimensions")
                continue
            }

            Logger.process.debugMessageOnly("ExtractEmbeddedPreview: Index \(index) - \(w)px wide (\(isJPEG ? "JPEG" : "RAW/TIFF"))")

            // Strategy:
            // A. If we find a JPEG, track the largest one.
            if isJPEG {
                if w > jpegWidth {
                    jpegWidth = w
                    jpegIndex = index
                }
            }
            // B. Backup Plan: If no JPEG found yet.
            else if jpegIndex == -1 {
                // LOGIC:
                // 1. Skip Index 0 (Always RAW on Sony).
                // 2. Pick the largest remaining image.
                if index != 0 && w > largestWidth {
                    largestWidth = w
                    bestIndex = index
                }
            }
        }

        // Decision
        var finalIndex = -1
        if jpegIndex != -1 {
            finalIndex = jpegIndex
            Logger.process.info("ExtractEmbeddedPreview: Selected JPEG preview at index \(finalIndex)")
        } else if bestIndex != -1 {
            finalIndex = bestIndex
            Logger.process.info("ExtractEmbeddedPreview: Selected fallback image at index \(finalIndex)")
        }

        // 3. Decode
        if finalIndex != -1 {
            // kCGImageSourceShouldCacheImmediately: true ensures we get the data now
            let options: [CFString: Any] = [
                kCGImageSourceShouldCacheImmediately: true,
                kCGImageSourceShouldAllowFloat: false
            ]
            
            if let image = CGImageSourceCreateImageAtIndex(imageSource, finalIndex, options as CFDictionary) {
                return image
            }
        }

        Logger.process.warning("ExtractEmbeddedPreview: No suitable preview found")
        return nil
    }
    
    // Helper to find width in nested dictionaries
    static func getWidth(from properties: [CFString: Any]) -> Int? {
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
}
