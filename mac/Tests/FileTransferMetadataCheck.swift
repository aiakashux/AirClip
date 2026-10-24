import Foundation

@main
struct FileTransferMetadataCheck {
    static func main() {
        let valid = FileClipMetadata(id: "source-file-1", name: "test.txt", size: 1, mimeType: "text/plain")
        precondition(valid.isSafeForTransfer)
        for id in ["../escape", "/absolute", "a/b", "a\\b", "", ".", String(repeating: "a", count: 129)] {
            var file = valid
            file.id = id
            precondition(!file.isSafeForTransfer)
            let wire = ClipboardPacket(kind: .file, text: file.name, file: file).encodedJSONString()!
            precondition(ClipboardPacket.decode(from: wire) == nil)
        }
        var negative = valid
        negative.size = -1
        precondition(!negative.isSafeForTransfer)
        precondition(ClipboardPacket.decode(from: "{\"kindRaw\":\"file\",\"text\":\"missing metadata\"}") == nil)
        let wire = ClipboardPacket(kind: .file, text: valid.name, file: valid).encodedJSONString()!
        precondition(ClipboardPacket.decode(from: wire)?.file == valid)
        print("File transfer metadata checks passed")
    }
}
