import Foundation

func testValidFilenames() {
    for name in ["notes.md", ".env", "Makefile", "a b.txt", "...", "  padded.txt  ", "colon:name"] {
        check(isValidFilename(name), "\(name.debugDescription) should be allowed")
    }
    // Empty names, and anything that would point outside the folder.
    for name in ["", "   ", "\n", ".", "..", " .. ", "/", "a/b", "../x", "/etc/hosts"] {
        check(!isValidFilename(name), "\(name.debugDescription) should be rejected")
    }
}

func testDesktopFiles() throws {
    let desktop = try makeTempFolder()
    try FileManager.default.createDirectory(atPath: desktop + "/sub", withIntermediateDirectories: false)
    let other = try makeTempFolder()
    check(isOnDesktop(desktop + "/photo.jpg", desktop: desktop), "a file on the Desktop")
    check(isOnDesktop(desktop + "/sub/../photo.jpg", desktop: desktop), "a Desktop file reached through ..")
    check(!isOnDesktop(desktop + "/sub/photo.jpg", desktop: desktop), "a file in a folder on the Desktop")
    check(!isOnDesktop(other + "/photo.jpg", desktop: desktop), "a file elsewhere")
    // NSTemporaryDirectory sits behind the /var → /private/var symlink, so this also checks resolving.
    check(isOnDesktop(((desktop as NSString).resolvingSymlinksInPath) + "/photo.jpg", desktop: desktop), "the Desktop's real path")
}

func testUnusedFilename() throws {
    let dir = try makeTempFolder()
    func touch(_ name: String) {
        FileManager.default.createFile(atPath: (dir as NSString).appendingPathComponent(name), contents: nil)
    }
    checkEqual(unusedFilename("notes.md", in: dir), "notes.md")
    touch("notes.md")
    checkEqual(unusedFilename("notes.md", in: dir), "notes 2.md")
    touch("notes 2.md")
    checkEqual(unusedFilename("notes.md", in: dir), "notes 3.md")
    touch("Makefile")
    checkEqual(unusedFilename("Makefile", in: dir), "Makefile 2")
    touch(".env")
    checkEqual(unusedFilename(".env", in: dir), ".env 2")
    // A broken symlink still takes the name.
    try FileManager.default.createSymbolicLink(atPath: dir + "/link.txt", withDestinationPath: dir + "/missing")
    checkEqual(unusedFilename("link.txt", in: dir), "link 2.txt")
}

// Links name a path; the helper only acts on the folder it resolves to.
func testFolderForLink() throws {
    let root = try makeTempFolder()
    let sub = root + "/sub folder"
    let app = root + "/Some.app"
    try FileManager.default.createDirectory(atPath: sub, withIntermediateDirectories: true)
    FileManager.default.createFile(atPath: sub + "/file.txt", contents: nil)
    try FileManager.default.createDirectory(atPath: app + "/Contents", withIntermediateDirectories: true)
    FileManager.default.createFile(atPath: app + "/Info.plist", contents: nil)
    try FileManager.default.createSymbolicLink(atPath: root + "/Alias.app", withDestinationPath: app)

    checkEqual(folder(for: sub), sub)
    checkEqual(folder(for: sub + "/"), sub)
    checkEqual(folder(for: root + "/sub folder/../sub folder"), sub)
    checkEqual(folder(for: sub + "/file.txt"), sub)
    // Packages count as files, also through a symlink, and never become the folder themselves.
    checkEqual(folder(for: app), root)
    checkEqual(folder(for: root + "/Alias.app"), root)
    checkEqual(folder(for: app + "/Info.plist"), nil)
    // Only existing absolute paths, even when a relative one exists from the current folder.
    checkEqual(folder(for: root + "/missing"), nil)
    checkEqual(folder(for: ""), nil)
    let cwd = FileManager.default.currentDirectoryPath
    FileManager.default.changeCurrentDirectoryPath(root)
    checkEqual(folder(for: "sub folder"), nil)
    FileManager.default.changeCurrentDirectoryPath(cwd)
}
