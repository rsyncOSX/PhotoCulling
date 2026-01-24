//
//  ExtractEmbeddedPreview.swift
//  PhotoCulling
//
//  Created by Thomas Evensen on 24/01/2026.
//

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

        // Get the count of images in the file (RAW + embedded previews)
        let imageCount = CGImageSourceGetCount(imageSource)
        Logger.process.debugThreadOnly("ExtractEmbeddedPreview: found \(imageCount) images in ARW file")

        // Sony ARW typically has multiple images:
        // Index 0: RAW data (not directly renderable)
        // Index 1: Large preview (often 4032×2688)
        // Index 2: Smaller preview (1616×1080)

        // Try to get the largest embedded preview
        var largestImage: CGImage?
        var largestDimensions: (width: Int, height: Int) = (0, 0)

        for index in 0 ..< imageCount {
            if let image = CGImageSourceCreateImageAtIndex(imageSource, index, nil) {
                let width = image.width
                let height = image.height

                Logger.process.debugMessageOnly("ExtractEmbeddedPreview: Image \(index): \(width)×\(height)")

                // Look for images around 4000px wide (Sony's large preview size)
                if width > largestDimensions.width && width > 2000 {
                    largestDimensions = (width, height)
                    largestImage = image
                }
            }
        }

        return largestImage
    }
}
