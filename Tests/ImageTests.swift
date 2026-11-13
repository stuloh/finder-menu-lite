import Foundation
import ImageIO
import UniformTypeIdentifiers

func testImageFormats() {
    for name in ["a.png", "a.PNG", "a.heic", "a.tiff", "a.webp"] {
        let url = URL(fileURLWithPath: "/x/" + name)
        check(isJPGSource(url) && isResizable(url), "\(name) should be convertible and resizable")
    }
    for name in ["a.jpg", "a.JPEG"] {
        let url = URL(fileURLWithPath: "/x/" + name)
        check(!isJPGSource(url) && isResizable(url), "\(name) should be resizable only")
    }
    for url in [URL(fileURLWithPath: "/x/a.pdf"), URL(fileURLWithPath: "/x/a.docx"), URL(fileURLWithPath: "/x/png"),
                URL(fileURLWithPath: "/x/photos.png", isDirectory: true)] {
        check(!isJPGSource(url) && !isResizable(url), "\(url) should be neither")
    }
}

// Real files through ImageIO, in a temp folder. The quality is passed in: tests never read settings.
func testImageConversions() throws {
    let dir = try makeTempFolder()
    let wide = try writePNG(dir + "/wide.png", width: 3000, height: 2000)
    let original = try Data(contentsOf: URL(fileURLWithPath: wide))

    let jpg = try convertToJPG(wide, quality: 0.9)
    checkEqual(jpg, dir + "/wide.jpg")
    checkEqual(try imageInfo(jpg).type, UTType.jpeg.identifier)
    checkEqual(try imageInfo(jpg).size, [3000, 2000])
    checkEqual(try convertToJPG(wide, quality: 0.9), dir + "/wide 2.jpg") // never overwrites
    // Transparent areas come out white, not black.
    checkEqual(try cornerIsLight(jpg), true)
    // Lower quality, smaller file.
    let low = try convertToJPG(wide, quality: 0.6)
    let size = { (path: String) in (try FileManager.default.attributesOfItem(atPath: path)[.size] as? Int) ?? 0 }
    check(try size(low) < size(jpg), "60% quality should be smaller than 90%")

    let resized = try resizeImage(wide, quality: 0.9)
    checkEqual(resized, dir + "/wide 1600px.png")
    checkEqual(try resized.map { try imageInfo($0).size }, [1600, 1067])
    checkEqual(try resized.map { try imageInfo($0).type }, UTType.png.identifier)

    let tall = try writePNG(dir + "/tall.png", width: 1000, height: 2400)
    checkEqual(try resizeImage(tall, quality: 0.9).map { try imageInfo($0).size }, [667, 1600])

    // A JPEG stays a JPEG, with the same extension.
    checkEqual(try resizeImage(jpg, quality: 0.9), dir + "/wide 1600px.jpg")

    // Already small enough: skipped, nothing written.
    let small = try writePNG(dir + "/small.png", width: 800, height: 600)
    checkEqual(try resizeImage(small, quality: 0.9), nil)
    check(!FileManager.default.fileExists(atPath: dir + "/small 1600px.png"), "a small image shouldn't be copied")

    // The original is never touched.
    checkEqual(try Data(contentsOf: URL(fileURLWithPath: wide)), original)
}

// A PNG with a transparent top-left corner and a solid red rest.
private func writePNG(_ path: String, width: Int, height: Int) throws -> String {
    let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
                            space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    context.setFillColor(CGColor(red: 1, green: 0, blue: 0, alpha: 1))
    context.fill(CGRect(x: 0, y: 0, width: width, height: height))
    context.clear(CGRect(x: 0, y: height - 100, width: 100, height: 100))
    let destination = CGImageDestinationCreateWithURL(URL(fileURLWithPath: path) as CFURL, UTType.png.identifier as CFString, 1, nil)!
    CGImageDestinationAddImage(destination, context.makeImage()!, nil)
    guard CGImageDestinationFinalize(destination) else { throw TestFailure(description: "couldn't write \(path)") }
    return path
}

private func imageInfo(_ path: String) throws -> (type: String, size: [Int]) {
    guard let source = CGImageSourceCreateWithURL(URL(fileURLWithPath: path) as CFURL, nil),
          let type = CGImageSourceGetType(source) as String?,
          let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else { throw TestFailure(description: "can't read \(path)") }
    return (type, [image.width, image.height])
}

// Whether the top-left pixel (transparent in the PNG) is near white.
private func cornerIsLight(_ path: String) throws -> Bool {
    guard let source = CGImageSourceCreateWithURL(URL(fileURLWithPath: path) as CFURL, nil),
          let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else { throw TestFailure(description: "can't read \(path)") }
    var pixel = [UInt8](repeating: 0, count: 4)
    let context = CGContext(data: &pixel, width: 1, height: 1, bitsPerComponent: 8, bytesPerRow: 4,
                            space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
    // Draw the whole image so its top-left pixel lands on the 1×1 context.
    context.draw(image, in: CGRect(x: 0, y: 1 - image.height, width: image.width, height: image.height))
    return pixel[0] > 200 && pixel[1] > 200 && pixel[2] > 200
}
