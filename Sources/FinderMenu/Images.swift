import Foundation
import ImageIO
import UniformTypeIdentifiers

// Convert to JPG and Resize. ImageIO is part of macOS, so neither needs another app or a permission.
// Each writes a new file next to the original, never touching it or overwriting anything.

enum ImageError: Error {
    case unreadable, unwritable
}

// photo.png → photo.jpg, at `quality` (0…1). Transparent areas become white, since JPEG has no transparency.
func convertToJPG(_ source: String, quality: Double) throws -> String {
    guard let image = CGImageSourceCreateWithURL(URL(fileURLWithPath: source) as CFURL, nil),
          let frame = CGImageSourceCreateImageAtIndex(image, 0, nil) else { throw ImageError.unreadable }
    let properties = CGImageSourceCopyPropertiesAtIndex(image, 0, nil) as? [CFString: Any] ?? [:]
    let destination = siblingPath(for: source, ext: "jpg")
    try write(onWhite(frame), properties: properties, type: .jpeg, quality: quality, to: destination)
    return destination
}

// Scales the copy so its longest side is `longestSide` (photo.png → photo 1600px.png). Returns nil, writing
// nothing, if the image is already that small. Formats ImageIO can't write (WebP) come out as JPEG.
func resizeImage(_ source: String, longestSide: Int = resizeLongestSide, quality: Double) throws -> String? {
    guard let image = CGImageSourceCreateWithURL(URL(fileURLWithPath: source) as CFURL, nil),
          var properties = CGImageSourceCopyPropertiesAtIndex(image, 0, nil) as? [CFString: Any],
          let width = properties[kCGImagePropertyPixelWidth] as? Int,
          let height = properties[kCGImagePropertyPixelHeight] as? Int else { throw ImageError.unreadable }
    guard max(width, height) > longestSide else { return nil }
    let options: [CFString: Any] = [
        kCGImageSourceThumbnailMaxPixelSize: longestSide,
        kCGImageSourceCreateThumbnailFromImageAlways: true,
        kCGImageSourceCreateThumbnailWithTransform: true, // Applies the EXIF orientation…
    ]
    guard let resized = CGImageSourceCreateThumbnailAtIndex(image, 0, options as CFDictionary) else { throw ImageError.unreadable }
    // …so the copy is already upright, and must not be rotated again. Its old size no longer applies either.
    properties[kCGImagePropertyOrientation] = 1
    if var tiff = properties[kCGImagePropertyTIFFDictionary] as? [CFString: Any] {
        tiff[kCGImagePropertyTIFFOrientation] = 1
        properties[kCGImagePropertyTIFFDictionary] = tiff
    }
    for key in [kCGImagePropertyPixelWidth, kCGImagePropertyPixelHeight] { properties.removeValue(forKey: key) }

    let writable = CGImageDestinationCopyTypeIdentifiers() as? [String] ?? []
    let original = CGImageSourceGetType(image).flatMap { UTType($0 as String) }
    let type = original.flatMap { writable.contains($0.identifier) ? $0 : nil } ?? .jpeg
    let ext = type == .jpeg && !["jpg", "jpeg"].contains((source as NSString).pathExtension.lowercased())
        ? "jpg" : (source as NSString).pathExtension
    let destination = siblingPath(for: source, suffix: " \(longestSide)px", ext: ext)
    try write(type == .jpeg ? onWhite(resized) : resized, properties: properties, type: type, quality: quality, to: destination)
    return destination
}

// Encodes in memory, then writes only if the name is still free, like New File.
private func write(_ image: CGImage, properties: [CFString: Any], type: UTType, quality: Double, to path: String) throws {
    let data = NSMutableData()
    guard let destination = CGImageDestinationCreateWithData(data, type.identifier as CFString, 1, nil) else { throw ImageError.unwritable }
    var options = properties
    if type == .jpeg { options[kCGImageDestinationLossyCompressionQuality] = quality }
    CGImageDestinationAddImage(destination, image, options as CFDictionary)
    guard CGImageDestinationFinalize(destination) else { throw ImageError.unwritable }
    try (data as Data).write(to: URL(fileURLWithPath: path), options: .withoutOverwriting)
}

// The image drawn over white, if it has transparency; JPEG would otherwise turn those areas black.
private func onWhite(_ image: CGImage) -> CGImage {
    switch image.alphaInfo {
    case .none, .noneSkipFirst, .noneSkipLast: return image
    default: break
    }
    let space = image.colorSpace.flatMap { $0.model == .rgb ? $0 : nil } ?? CGColorSpace(name: CGColorSpace.sRGB)!
    guard let context = CGContext(data: nil, width: image.width, height: image.height, bitsPerComponent: 8, bytesPerRow: 0,
                                  space: space, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue) else { return image }
    let rect = CGRect(x: 0, y: 0, width: image.width, height: image.height)
    context.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
    context.fill(rect)
    context.draw(image, in: rect)
    return context.makeImage() ?? image
}
