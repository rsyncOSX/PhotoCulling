import Foundation
import ImageIO

struct ExifMetadata: Hashable {
    let shutterSpeed: String?
    let focalLength: String?
    let aperture: String?
    let iso: String?
    let camera: String?
    let lensModel: String?
}

func extractExifData(from url: URL) -> ExifMetadata? {
    guard let imageSource = CGImageSourceCreateWithURL(url as CFURL, nil),
          let properties = CGImageSourceCopyPropertiesAtIndex(imageSource, 0, nil) as? [CFString: Any],
          let exifDict = properties[kCGImagePropertyExifDictionary] as? [CFString: Any],
          let tiffDict = properties[kCGImagePropertyTIFFDictionary] as? [CFString: Any] else {
        return nil
    }

    return ExifMetadata(
        shutterSpeed: formatShutterSpeed(exifDict[kCGImagePropertyExifExposureTime]),
        focalLength: formatFocalLength(exifDict[kCGImagePropertyExifFocalLength]),
        aperture: formatAperture(exifDict[kCGImagePropertyExifFNumber]),
        iso: formatISO(exifDict[kCGImagePropertyExifISOSpeedRatings]),
        camera: tiffDict[kCGImagePropertyTIFFModel] as? String,
        lensModel: exifDict[kCGImagePropertyExifLensModel] as? String
    )
}

private func formatShutterSpeed(_ value: Any?) -> String? {
    guard let speed = value as? NSNumber else { return nil }
    let speedValue = speed.doubleValue
    if speedValue >= 1 {
        return String(format: "%.1f\"", speedValue)
    } else {
        return String(format: "1/%.0f", 1 / speedValue)
    }
}

private func formatFocalLength(_ value: Any?) -> String? {
    guard let focal = value as? NSNumber else { return nil }
    return String(format: "%.1fmm", focal.doubleValue)
}

private func formatAperture(_ value: Any?) -> String? {
    guard let aperture = value as? NSNumber else { return nil }
    return String(format: "ƒ/%.1f", aperture.doubleValue)
}

private func formatISO(_ value: Any?) -> String? {
    guard let iso = value as? NSNumber else { return nil }
    return String(format: "ISO %.0f", iso.doubleValue)
}
