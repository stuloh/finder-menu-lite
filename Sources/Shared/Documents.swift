import Foundation

// Files each conversion accepts, by extension. The extension shows an item only when every selected
// item passes its check (it can't read the files, only their names), and the helper checks again.
let wordExtensions: Set<String> = ["docx", "doc"]
// Images ImageIO reads that aren't already JPEG.
let jpgSourceExtensions: Set<String> = ["heic", "heif", "png", "tiff", "tif", "gif", "bmp", "webp", "avif"]
let resizableExtensions: Set<String> = jpgSourceExtensions.union(["jpg", "jpeg"])

private func hasExtension(_ url: URL, in extensions: Set<String>) -> Bool {
    !url.hasDirectoryPath && extensions.contains(url.pathExtension.lowercased())
}

func isWordDocument(_ url: URL) -> Bool { hasExtension(url, in: wordExtensions) }
func isJPGSource(_ url: URL) -> Bool { hasExtension(url, in: jpgSourceExtensions) }
func isResizable(_ url: URL) -> Bool { hasExtension(url, in: resizableExtensions) }

// The longest side Resize makes an image.
let resizeLongestSide = 1600
