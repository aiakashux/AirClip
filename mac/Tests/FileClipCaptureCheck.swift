import AppKit
import Foundation

@main
struct FileClipCaptureCheck {
    static func main() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let movie = directory.appendingPathComponent("movie.mp4")
        let document = directory.appendingPathComponent("notes.docx")
        try Data([1, 2, 3]).write(to: movie)
        try Data([4, 5]).write(to: document)

        let pasteboard = NSPasteboard.withUniqueName()
        defer { pasteboard.releaseGlobally() }
        precondition(pasteboard.writeObjects([movie as NSURL, document as NSURL, directory as NSURL]))
        let packets = ClipboardCapture.readCurrentPackets(from: pasteboard)
        precondition(packets.count == 2)
        precondition(packets.allSatisfy { $0.kind == .file })
        precondition(packets[0].file?.size == 3)
        precondition(packets[0].file?.iconAssetName == "FileIconVideo")
        precondition(packets[1].file?.iconAssetName == "FileIconDocument")
        precondition(packets[0].file?.id != packets[1].file?.id)

        let modern = NSPasteboard.withUniqueName()
        defer { modern.releaseGlobally() }
        let modernItem = NSPasteboardItem()
        modernItem.setString(movie.absoluteString, forType: .fileURL)
        modern.writeObjects([modernItem])
        precondition(ClipboardCapture.readCurrentPackets(from: modern).first?.kind == .file)

        let legacy = NSPasteboard.withUniqueName()
        defer { legacy.releaseGlobally() }
        legacy.setPropertyList([document.path], forType: NSPasteboard.PasteboardType("NSFilenamesPboardType"))
        precondition(ClipboardCapture.readCurrentPackets(from: legacy).first?.kind == .file)
    }
}
