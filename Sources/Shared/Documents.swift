import Foundation

// Files Convert to PDF accepts. The extension shows the item only when every selected item is one,
// and the helper checks again before handing the file to Word.
let wordExtensions: Set<String> = ["docx", "doc"]

func isWordDocument(_ url: URL) -> Bool {
    !url.hasDirectoryPath && wordExtensions.contains(url.pathExtension.lowercased())
}
