import Foundation

func testWordDocuments() throws {
    for path in ["/a/report.docx", "/a/Report.DOCX", "/a/old.doc"] {
        check(isWordDocument(URL(fileURLWithPath: path)), "\(path) should count as a Word document")
    }
    for url in [URL(fileURLWithPath: "/a/report.pdf"), URL(fileURLWithPath: "/a/report.docx.zip"),
                URL(fileURLWithPath: "/a/docx"), URL(fileURLWithPath: "/a/folder.docx", isDirectory: true)] {
        check(!isWordDocument(url), "\(url) shouldn't count as a Word document")
    }

    let dir = try makeTempFolder()
    let report = dir + "/report.docx"
    FileManager.default.createFile(atPath: report, contents: nil)
    FileManager.default.createFile(atPath: dir + "/notes.txt", contents: nil)
    try FileManager.default.createDirectory(atPath: dir + "/folder.docx", withIntermediateDirectories: false)
    checkEqual(existingFile(for: report, matching: isWordDocument), report)
    checkEqual(existingFile(for: dir + "/./sub/../report.docx", matching: isWordDocument), report)
    for path in ["report.docx", dir + "/missing.docx", dir + "/notes.txt", dir + "/folder.docx"] {
        checkEqual(existingFile(for: path, matching: isWordDocument), nil)
    }

    // Never overwrites: the next free name, Finder style.
    checkEqual(siblingPath(for: report, ext: "pdf"), dir + "/report.pdf")
    FileManager.default.createFile(atPath: dir + "/report.pdf", contents: nil)
    checkEqual(siblingPath(for: report, ext: "pdf"), dir + "/report 2.pdf")

    // Paths reach Word only as escaped AppleScript strings.
    let source = #"/Users/me/"odd" \ name.docx"#
    let destination = #"/Users/me/"odd" \ name.pdf"#
    let script = wordToPDFScript(source: source, destination: destination)
    check(script.components(separatedBy: appleScriptString(source)).count == 3, "source should appear escaped twice")
    check(script.contains(appleScriptString(destination)), "destination should appear escaped")
    check(!script.contains(source) && !script.contains(destination), "a path appears unescaped")
}
