import Cocoa

// Path handling for the helper's actions. Kept out of AppDelegate (and main.swift's top-level code)
// so scripts/test.sh can compile and test it.

// Only act on existing absolute paths. Files and packages such as .app bundles resolve to the
// folder that contains them.
func folder(for path: String) -> String? {
    guard path.hasPrefix("/") else { return nil }
    let path = (path as NSString).standardizingPath
    var isDir: ObjCBool = false
    guard FileManager.default.fileExists(atPath: path, isDirectory: &isDir) else { return nil }
    let dir = isDir.boolValue && !isPackage(path) ? path : (path as NSString).deletingLastPathComponent
    return isPackage(dir) ? nil : dir
}

// Checks the real location, so a symlink to an .app counts as a package too.
func isPackage(_ path: String) -> Bool {
    NSWorkspace.shared.isFilePackage(atPath: (path as NSString).resolvingSymlinksInPath)
}

// Finder-style duplicate names: "notes.md" → "notes 2.md", "notes 3.md", …
func unusedFilename(_ filename: String, in dir: String) -> String {
    let ns = filename as NSString
    let base = ns.deletingPathExtension
    let ext = ns.pathExtension
    // Unlike fileExists, attributesOfItem doesn't follow symlinks, so a broken link still counts as taken.
    func taken(_ name: String) -> Bool {
        (try? FileManager.default.attributesOfItem(atPath: (dir as NSString).appendingPathComponent(name))) != nil
    }
    var candidate = filename
    var n = 2
    while taken(candidate) {
        candidate = ext.isEmpty ? "\(base) \(n)" : "\(base) \(n).\(ext)"
        n += 1
    }
    return candidate
}

// A path as an AppleScript string literal. Folder names can contain quotes and backslashes,
// and anything left unescaped would run as AppleScript.
func appleScriptString(_ s: String) -> String {
    "\"" + s.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"") + "\""
}

// Conversions only act on existing absolute paths to files they accept: no folders or packages.
func existingFile(for path: String, matching accepts: (URL) -> Bool) -> String? {
    guard path.hasPrefix("/") else { return nil }
    let path = (path as NSString).standardizingPath
    var isDir: ObjCBool = false
    guard FileManager.default.fileExists(atPath: path, isDirectory: &isDir), !isDir.boolValue,
          accepts(URL(fileURLWithPath: path)) else { return nil }
    return path
}

// Where a converted copy goes: next to the original, named after it with a free name.
// siblingPath(for: "/a/photo.png", suffix: " 1600px", ext: "png") → /a/photo 1600px.png, /a/photo 1600px 2.png, …
func siblingPath(for original: String, suffix: String = "", ext: String) -> String {
    let dir = (original as NSString).deletingLastPathComponent
    let base = ((original as NSString).lastPathComponent as NSString).deletingPathExtension
    return (dir as NSString).appendingPathComponent(unusedFilename(base + suffix + "." + ext, in: dir))
}

// Has Word save `source` as a PDF at `destination`. A document that was already open stays open,
// and Word quits afterwards only if this started it and nothing else is open.
func wordToPDFScript(source: String, destination: String) -> String {
    """
    set wasRunning to application id "com.microsoft.Word" is running
    tell application id "com.microsoft.Word"
        set theDoc to missing value
        repeat with d in documents
            try
                if posix full name of d is \(appleScriptString(source)) then set theDoc to contents of d
            end try
        end repeat
        set wasOpen to theDoc is not missing value
        if not wasOpen then
            open (POSIX file \(appleScriptString(source)))
            set theDoc to active document
        end if
        try
            save as theDoc file name \(appleScriptString(destination)) file format format PDF
        on error message number code
            if not wasOpen then close theDoc saving no
            error message number code
        end try
        if not wasOpen then close theDoc saving no
        if not wasRunning and (count of documents) is 0 then quit
    end tell
    """
}

// The user's Desktop folder, real path.
let desktopFolder = FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask).first?.path ?? NSHomeDirectory() + "/Desktop"

// Whether a file sits directly on the Desktop. Symlinks and ".." are resolved on both sides.
func isOnDesktop(_ path: String, desktop: String = desktopFolder) -> Bool {
    let real = { (p: String) in ((p as NSString).standardizingPath as NSString).resolvingSymlinksInPath }
    return real((path as NSString).deletingLastPathComponent) == real(desktop)
}

// Selects new files in Finder. Files on the Desktop are left alone: they're already in view, and no
// window shows the Desktop folder, so Finder would open a new one just to select them.
func revealInFinder(_ paths: [String]) {
    let shown = paths.filter { !isOnDesktop($0) }
    guard !shown.isEmpty else { return }
    NSWorkspace.shared.activateFileViewerSelecting(shown.map { URL(fileURLWithPath: $0) })
}
