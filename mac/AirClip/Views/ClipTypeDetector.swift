import Foundation
import AppKit

enum ClipboardKind: String, Codable, CaseIterable {
    case url, code, color, email, image, text

    var displayName: String {
        switch self {
        case .url: return "URL"
        case .code: return "Code"
        case .color: return "Color"
        case .email: return "Email"
        case .image: return "Image"
        case .text: return "Text"
        }
    }
}

struct ClipboardPacket: Codable, Hashable {
    var kindRaw: String
    var text: String
    var imageDataBase64: String?

    init(kind: ClipboardKind, text: String, imageData: Data? = nil) {
        self.kindRaw = kind.rawValue
        self.text = text
        let wireImageData = imageData.flatMap(Self.pngData) ?? imageData
        self.imageDataBase64 = wireImageData?.base64EncodedString()
    }

    var kind: ClipboardKind {
        let decoded = ClipboardKind(rawValue: kindRaw) ?? .text
        return decoded == .code ? .text : decoded
    }

    var imageData: Data? {
        imageDataBase64.flatMap { Data(base64Encoded: $0) }
    }

    var fingerprint: String {
        switch kind {
        case .image:
            return "image:\(imageDataBase64 ?? "")"
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
    static func readCurrentPacket(from pasteboard: NSPasteboard = .general) -> ClipboardPacket? {
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

    static func write(_ packet: ClipboardPacket, to pasteboard: NSPasteboard = .general) {
        pasteboard.clearContents()

        switch packet.kind {
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
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }

        let ext = url.pathExtension.lowercased()
        let imageExtensions = ["png", "jpg", "jpeg", "gif", "webp", "heic", "heif", "bmp", "tif", "tiff"]
        guard imageExtensions.contains(ext), let data = try? Data(contentsOf: url), NSImage(data: data) != nil else {
            return nil
        }

        return ClipboardPacket(kind: .image, text: url.lastPathComponent, imageData: data)
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

// MARK: - Clip Type — shared between popup and main window

enum ClipType: String, Codable, CaseIterable {
    case url, code, color, email, image, text

    var clipboardKind: ClipboardKind {
        ClipboardKind(rawValue: rawValue) ?? .text
    }

    static func detect(_ raw: String) -> ClipType {
        let t = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if isImageLike(t) { return .image }
        if t.hasPrefix("http://") || t.hasPrefix("https://") { return .url }
        if isColorHex(t) { return .color }
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
        guard t.hasPrefix("#") else { return false }
        let hex = String(t.dropFirst())
        return [3, 4, 6, 8].contains(hex.count) && hex.allSatisfy(\.isHexDigit)
    }

    private static func isEmail(_ t: String) -> Bool {
        let parts = t.split(separator: "@")
        guard parts.count == 2, let domain = parts.last else { return false }
        return domain.contains(".") && !t.contains(" ") && t.count <= 254
    }

}
