import Foundation
import AppKit
import SwiftUI
import UniformTypeIdentifiers
import QuickLookThumbnailing
import AVFoundation

enum ClipboardKind: String, Codable, CaseIterable {
    case url, color, email, image, file, text

    var displayName: String {
        switch self {
        case .url: return "URL"
        case .color: return "Color"
        case .email: return "Email"
        case .image: return "Image"
        case .file: return "File"
        case .text: return "Text"
        }
    }
}

struct FileClipMetadata: Codable, Hashable {
    var id: String
    var name: String
    var size: Int64
    var mimeType: String
    var modifiedAtMs: Int64?
    var thumbnailBase64: String?
    var durationMs: Int64?
    var width: Int?
    var height: Int?
    var artist: String?
    var album: String?

    var iconAssetName: String {
        let ext = (name as NSString).pathExtension.lowercased()
        switch ext {
        case "pdf": return "FileIconPDF"
        case "ppt", "pptx", "key": return "FileIconPresentation"
        case "exe", "msi", "msix": return "FileIconWindowsInstaller"
        case "dmg", "ipa", "pkg", "app": return "FileIconAppleInstaller"
        case "apk", "aab": return "FileIconAndroidInstaller"
        case "zip", "7z", "tar", "gz", "bz2": return "FileIconZip"
        case "rar": return "FileIconRar"
        case "mp3", "m4a", "aac", "wav", "flac", "ogg", "opus", "aiff": return "FileIconAudio"
        case "mp4", "m4v", "mov", "mkv", "avi", "webm", "wmv": return "FileIconVideo"
        case "html", "htm", "css", "js", "ts", "jsx", "tsx", "json", "xml", "py", "swift", "kt", "java", "c", "cpp", "h", "rs", "go", "sh", "sql": return "FileIconCode"
        default: break
        }
        if mimeType == "application/pdf" { return "FileIconPDF" }
        if mimeType.hasPrefix("audio/") { return "FileIconAudio" }
        if mimeType.hasPrefix("video/") { return "FileIconVideo" }
        if mimeType.hasPrefix("text/") && ext != "txt" { return "FileIconCode" }
        return "FileIconDocument"
    }

    var iconAccentColor: Color {
        switch iconAssetName {
        case "FileIconPDF": return Color(hex: "#DC0C11")
        case "FileIconPresentation": return Color(hex: "#FC6F40")
        case "FileIconWindowsInstaller", "FileIconAppleInstaller": return Color(hex: "#33A1FE")
        case "FileIconAndroidInstaller": return Color(hex: "#50DA8C")
        case "FileIconZip": return Color(hex: "#FFBA02")
        case "FileIconRar": return Color(hex: "#A79455")
        case "FileIconAudio": return Color(hex: "#ED144E")
        case "FileIconVideo": return Color(hex: "#ED144E")
        case "FileIconCode": return Color(hex: "#DF53E3")
        default: return Color(hex: "#33A1FE")
        }
    }

    var thumbnailImage: NSImage? {
        guard let thumbnailBase64,
              let data = Data(base64Encoded: thumbnailBase64) else { return nil }
        return NSImage(data: data)
    }

    var isImage: Bool {
        mimeType.hasPrefix("image/") || ["png", "jpg", "jpeg", "gif", "webp", "heic", "heif", "bmp", "tif", "tiff"]
            .contains((name as NSString).pathExtension.lowercased())
    }

    var isPlayableMedia: Bool {
        let ext = (name as NSString).pathExtension.lowercased()
        return mimeType.hasPrefix("audio/") || mimeType.hasPrefix("video/") ||
            ["mp3", "m4a", "aac", "wav", "flac", "ogg", "opus", "aiff",
             "mp4", "m4v", "mov", "mkv", "avi", "webm", "wmv"].contains(ext)
    }
}

struct ClipboardPacket: Codable, Hashable {
    var kindRaw: String
    var text: String
    var imageDataBase64: String?
    var file: FileClipMetadata?

    init(kind: ClipboardKind, text: String, imageData: Data? = nil, file: FileClipMetadata? = nil) {
        self.kindRaw = kind.rawValue
        self.text = text
        let wireImageData = imageData.flatMap(Self.pngData) ?? imageData
        self.imageDataBase64 = wireImageData?.base64EncodedString()
        self.file = file
    }

    var kind: ClipboardKind {
        ClipboardKind(rawValue: kindRaw) ?? .text
    }

    var imageData: Data? {
        imageDataBase64.flatMap { Data(base64Encoded: $0) }
    }

    var fingerprint: String {
        switch kind {
        case .image:
            return "image:\(imageDataBase64 ?? "")"
        case .file:
            return "file:\(file?.id ?? text)"
        default:
            return "\(kind.rawValue):\(text)"
        }
    }

    func encodedJSONString() -> String? {
        guard let data = try? JSONEncoder().encode(self) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    static func decode(from string: String) -> ClipboardPacket? {
        guard let data = string.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode(ClipboardPacket.self, from: data)
    }

    private static func pngData(from data: Data) -> Data? {
        guard
            let image = NSImage(data: data),
            let tiff = image.tiffRepresentation,
            let bitmap = NSBitmapImageRep(data: tiff)
        else { return nil }
        return bitmap.representation(using: .png, properties: [:])
    }
}

enum ClipboardCapture {
    static func packet(forDroppedFile url: URL) -> ClipboardPacket? {
        guard url.isFileURL else { return nil }

        let hasAccess = url.startAccessingSecurityScopedResource()
        defer { if hasAccess { url.stopAccessingSecurityScopedResource() } }
        guard let values = try? url.resourceValues(forKeys: [.isRegularFileKey]),
              values.isRegularFile == true else { return nil }

        if let imagePacket = readImageFilePacket(from: url) {
            return imagePacket
        }
        return FileClipSource.packet(for: url)
    }

    static func readCurrentPackets(from pasteboard: NSPasteboard = .general) -> [ClipboardPacket] {
        let urls = fileURLs(from: pasteboard)
        if !urls.isEmpty {
            return urls.filter { $0.isFileURL && !$0.hasDirectoryPath }
                .compactMap(packet(forClipboardFileURL:))
        }
        return readCurrentPacket(from: pasteboard).map { [$0] } ?? []
    }

    static func readCurrentPacket(from pasteboard: NSPasteboard = .general) -> ClipboardPacket? {
        if let url = fileURLs(from: pasteboard).first(where: { $0.isFileURL && !$0.hasDirectoryPath }),
           let packet = packet(forClipboardFileURL: url) {
            return packet
        }
        if let packet = readImagePacket(from: pasteboard) {
            return packet
        }
        if let packet = readColorPacket(from: pasteboard) {
            return packet
        }

        guard let string = pasteboard.string(forType: .string)?
            .trimmingCharacters(in: .whitespacesAndNewlines),
              !string.isEmpty
        else { return nil }

        if let packet = readFileImagePacket(from: string) {
            return packet
        }

        return ClipboardPacket(kind: ClipType.detect(string).clipboardKind, text: string)
    }

    /// Finder has used several representations for copied files across macOS
    /// releases. Prefer typed NSURL decoding, then inspect modern file-url
    /// pasteboard items, and finally the legacy filename-list flavor.
    static func fileURLs(from pasteboard: NSPasteboard) -> [URL] {
        let options: [NSPasteboard.ReadingOptionKey: Any] = [.urlReadingFileURLsOnly: true]
        var urls = (pasteboard.readObjects(forClasses: [NSURL.self], options: options) as? [URL]) ?? []

        for item in pasteboard.pasteboardItems ?? [] {
            for type in [NSPasteboard.PasteboardType.fileURL,
                         NSPasteboard.PasteboardType("public.file-url")] {
                guard let value = item.string(forType: type),
                      let url = URL(string: value), url.isFileURL else { continue }
                urls.append(url)
            }
        }

        let legacyType = NSPasteboard.PasteboardType("NSFilenamesPboardType")
        if let paths = pasteboard.propertyList(forType: legacyType) as? [String] {
            urls.append(contentsOf: paths.map { URL(fileURLWithPath: $0) })
        }

        var seen = Set<String>()
        return urls.filter { seen.insert($0.standardizedFileURL.path).inserted }
    }

    static func write(_ packet: ClipboardPacket, to pasteboard: NSPasteboard = .general) {
        pasteboard.clearContents()

        switch packet.kind {
        case .file:
            if let file = packet.file {
                _ = FileClipSource.withAccess(to: file.id) { url in
                    pasteboard.writeObjects([url as NSURL])
                }
            }
        case .image:
            if let data = packet.imageData, let image = NSImage(data: data) {
                pasteboard.writeObjects([image])
            } else {
                pasteboard.setString(packet.text, forType: .string)
            }
        default:
            pasteboard.setString(packet.text, forType: .string)
        }
    }

    private static func readImagePacket(from pasteboard: NSPasteboard) -> ClipboardPacket? {
        if let data = pasteboard.data(forType: .tiff) ?? pasteboard.data(forType: .png),
           let image = NSImage(data: data) {
            return ClipboardPacket(
                kind: .image,
                text: imageSummary(for: image),
                imageData: data
            )
        }

        if let images = pasteboard.readObjects(forClasses: [NSImage.self], options: nil) as? [NSImage],
           let image = images.first,
           let data = image.tiffRepresentation {
            return ClipboardPacket(
                kind: .image,
                text: imageSummary(for: image),
                imageData: data
            )
        }

        return nil
    }

    private static func readColorPacket(from pasteboard: NSPasteboard) -> ClipboardPacket? {
        guard
            let colors = pasteboard.readObjects(forClasses: [NSColor.self], options: nil) as? [NSColor],
            let color = colors.first,
            let hex = color.clipboardHexString
        else { return nil }

        return ClipboardPacket(kind: .color, text: hex)
    }

    private static func readFileImagePacket(from string: String) -> ClipboardPacket? {
        let url = URL(fileURLWithPath: string)
        return readImageFilePacket(from: url)
    }

    private static func readImageFilePacket(from url: URL) -> ClipboardPacket? {
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }

        let ext = url.pathExtension.lowercased()
        let imageExtensions = ["png", "jpg", "jpeg", "gif", "webp", "heic", "heif", "bmp", "tif", "tiff"]
        let contentType = UTType(filenameExtension: ext)
        guard (imageExtensions.contains(ext) || contentType?.conforms(to: .image) == true),
              let data = try? Data(contentsOf: url),
              NSImage(data: data) != nil else {
            return nil
        }

        return ClipboardPacket(kind: .image, text: url.lastPathComponent, imageData: data)
    }

    private static func packet(forClipboardFileURL url: URL) -> ClipboardPacket? {
        let hasAccess = url.startAccessingSecurityScopedResource()
        defer { if hasAccess { url.stopAccessingSecurityScopedResource() } }

        if let imagePacket = readImageFilePacket(from: url) {
            return imagePacket
        }
        return FileClipSource.packet(for: url)
    }

    private static func imageSummary(for image: NSImage) -> String {
        let width = Int(image.size.width.rounded())
        let height = Int(image.size.height.rounded())
        guard width > 0, height > 0 else { return "Image" }
        return "Image \(width)×\(height)"
    }

}

private extension NSColor {
    var clipboardHexString: String? {
        let color = usingColorSpace(.sRGB) ?? usingColorSpace(.deviceRGB)
        guard let color else { return nil }

        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        color.getRed(&red, green: &green, blue: &blue, alpha: &alpha)

        return String(
            format: "#%02X%02X%02X%02X",
            Int((red * 255).rounded()),
            Int((green * 255).rounded()),
            Int((blue * 255).rounded()),
            Int((alpha * 255).rounded())
        )
    }
}

enum FileClipSource {
    private static let defaultsKey = "fileClipSourceURLs"
    private static let bookmarkKey = "fileClipSourceBookmarks"

    static func packet(for url: URL) -> ClipboardPacket? {
        guard url.isFileURL,
              let values = try? url.resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey, .contentModificationDateKey, .contentTypeKey]),
              values.isRegularFile == true
        else { return nil }
        let id = UUID().uuidString
        var sources = UserDefaults.standard.dictionary(forKey: defaultsKey) as? [String: String] ?? [:]
        sources[id] = url.path
        UserDefaults.standard.set(sources, forKey: defaultsKey)
        if let bookmark = try? url.bookmarkData(options: .withSecurityScope,
                                                includingResourceValuesForKeys: nil, relativeTo: nil) {
            var bookmarks = UserDefaults.standard.dictionary(forKey: bookmarkKey) as? [String: String] ?? [:]
            bookmarks[id] = bookmark.base64EncodedString()
            UserDefaults.standard.set(bookmarks, forKey: bookmarkKey)
        }
        let type = values.contentType ?? UTType(filenameExtension: url.pathExtension) ?? .data
        let metadata = FileClipMetadata(
            id: id,
            name: url.lastPathComponent,
            size: Int64(values.fileSize ?? 0),
            mimeType: type.preferredMIMEType ?? "application/octet-stream",
            modifiedAtMs: values.contentModificationDate.map { Int64($0.timeIntervalSince1970 * 1000) },
            thumbnailBase64: nil,
            durationMs: nil,
            width: nil,
            height: nil,
            artist: nil,
            album: nil
        )
        return ClipboardPacket(kind: .file, text: metadata.name, file: metadata)
    }

    static func url(for id: String) -> URL? {
        if let encoded = (UserDefaults.standard.dictionary(forKey: bookmarkKey) as? [String: String])?[id],
           let data = Data(base64Encoded: encoded) {
            var stale = false
            if let secured = try? URL(resolvingBookmarkData: data, options: .withSecurityScope,
                                      relativeTo: nil, bookmarkDataIsStale: &stale),
               FileManager.default.fileExists(atPath: secured.path) {
                return secured
            }
        }
        guard let path = (UserDefaults.standard.dictionary(forKey: defaultsKey) as? [String: String])?[id] else { return nil }
        let url = URL(fileURLWithPath: path)
        return FileManager.default.fileExists(atPath: url.path) ? url : nil
    }

    static func withAccess<T>(to id: String, _ operation: (URL) throws -> T) rethrows -> T? {
        guard let url = url(for: id) else { return nil }
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        return try operation(url)
    }

    static func thumbnail(for id: String) async -> Data? {
        guard let url = url(for: id) else { return nil }
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        if let type = try? url.resourceValues(forKeys: [.contentTypeKey]).contentType,
           type.conforms(to: .audio) {
            let metadata = (try? await AVURLAsset(url: url).load(.commonMetadata)) ?? []
            let artworkItem = AVMetadataItem.metadataItems(from: metadata,
                                                           withKey: AVMetadataKey.commonKeyArtwork,
                                                           keySpace: .common).first
            if let artwork = try? await artworkItem?.load(.dataValue),
               let image = NSImage(data: artwork) {
                let side = max(image.size.width, image.size.height)
                let scale = min(1, 320 / max(side, 1))
                let target = NSSize(width: image.size.width * scale, height: image.size.height * scale)
                let resized = NSImage(size: target, flipped: false) { rect in
                    image.draw(in: rect)
                    return true
                }
                guard let tiff = resized.tiffRepresentation,
               let bitmap = NSBitmapImageRep(data: tiff),
               let jpeg = bitmap.representation(using: .jpeg, properties: [.compressionFactor: 0.7]),
                jpeg.count <= 160 * 1024 else { return nil }
                return jpeg
            }
        }
        let request = QLThumbnailGenerator.Request(
            fileAt: url,
            size: CGSize(width: 320, height: 320),
            scale: 1,
            representationTypes: .thumbnail
        )
        return await withCheckedContinuation { continuation in
            QLThumbnailGenerator.shared.generateBestRepresentation(for: request) { representation, _ in
                guard let representation else { continuation.resume(returning: nil); return }
                let bitmap = NSBitmapImageRep(cgImage: representation.cgImage)
                let data = bitmap.representation(using: .jpeg, properties: [.compressionFactor: 0.76])
                continuation.resume(returning: (data?.count ?? 0) <= 160 * 1024 ? data : nil)
            }
        }
    }

    static func enrichMedia(_ file: FileClipMetadata) async -> FileClipMetadata {
        guard file.mimeType.hasPrefix("audio/") || file.mimeType.hasPrefix("video/"),
              let url = url(for: file.id) else { return file }
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        let asset = AVURLAsset(url: url)
        var result = file
        if let duration = try? await asset.load(.duration), duration.isNumeric {
            result.durationMs = Int64(CMTimeGetSeconds(duration) * 1000)
        }
        if file.mimeType.hasPrefix("video/"),
           let tracks = try? await asset.loadTracks(withMediaType: .video),
           let track = tracks.first,
           let size = try? await track.load(.naturalSize) {
            result.width = Int(abs(size.width))
            result.height = Int(abs(size.height))
        }
        if file.mimeType.hasPrefix("audio/") {
            let metadata = (try? await asset.load(.commonMetadata)) ?? []
            let artist = AVMetadataItem.metadataItems(from: metadata, withKey: AVMetadataKey.commonKeyArtist, keySpace: .common).first
            let album = AVMetadataItem.metadataItems(from: metadata, withKey: AVMetadataKey.commonKeyAlbumName, keySpace: .common).first
            result.artist = try? await artist?.load(.stringValue)
            result.album = try? await album?.load(.stringValue)
        }
        return result
    }
}

// MARK: - Clip Type — shared between popup and main window

enum ClipType: String, Codable, CaseIterable {
    case url, color, email, image, file, text

    var clipboardKind: ClipboardKind {
        ClipboardKind(rawValue: rawValue) ?? .text
    }

    static func detect(_ raw: String) -> ClipType {
        let t = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if isImageLike(t) { return .image }
        if t.hasPrefix("http://") || t.hasPrefix("https://") { return .url }
        if isColorHex(t) || isColorRGB(t) { return .color }
        if isEmail(t) { return .email }
        return .text
    }

    private static func isImageLike(_ t: String) -> Bool {
        let lower = t.lowercased()
        if lower.hasPrefix("data:image/") { return true }

        let ext = URL(fileURLWithPath: t).pathExtension.lowercased()
        let imageExtensions = ["png", "jpg", "jpeg", "gif", "webp", "heic", "heif", "bmp", "tif", "tiff"]
        return imageExtensions.contains(ext)
    }

    private static func isColorHex(_ t: String) -> Bool {
        if t.hasPrefix("#") {
            let hex = String(t.dropFirst())
            return [3, 4, 6, 8].contains(hex.count) && hex.allSatisfy(\.isHexDigit)
        }

        // Hashless six-digit values are common in design tools. Requiring an
        // uppercase hex letter avoids treating arbitrary six-character text as a color.
        guard t.count == 6, t.allSatisfy(\.isHexDigit), t.contains(where: ("A"..."F").contains) else {
            return false
        }
        return t == t.uppercased()
    }

    private static func isColorRGB(_ t: String) -> Bool {
        let pattern = #"^rgba?\(\s*\d{1,3}\s*,\s*\d{1,3}\s*,\s*\d{1,3}(?:\s*,\s*(?:0|1|0?\.\d+))?\s*\)$"#
        guard let range = t.range(of: pattern, options: .regularExpression) else { return false }
        let values = t[range].drop { $0 != "(" }.dropFirst().dropLast()
            .split(separator: ",").compactMap { Double($0.trimmingCharacters(in: .whitespaces)) }
        return values.count == (t.hasPrefix("rgba") ? 4 : 3)
            && values.prefix(3).allSatisfy { (0...255).contains($0) }
    }

    private static func isEmail(_ t: String) -> Bool {
        let parts = t.split(separator: "@")
        guard parts.count == 2, let domain = parts.last else { return false }
        return domain.contains(".") && !t.contains(" ") && t.count <= 254
    }

}
