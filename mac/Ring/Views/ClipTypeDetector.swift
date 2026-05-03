import Foundation

// MARK: - Clip Type — shared between popup and main window

enum ClipType {
    case url, code, color, text

    static func detect(_ raw: String) -> ClipType {
        let t = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if t.hasPrefix("http://") || t.hasPrefix("https://") { return .url }
        if isColorHex(t) { return .color }
        if looksLikeCode(t) { return .code }
        return .text
    }

    private static func isColorHex(_ t: String) -> Bool {
        guard t.hasPrefix("#") else { return false }
        let hex = String(t.dropFirst())
        return [3, 4, 6, 8].contains(hex.count) && hex.allSatisfy(\.isHexDigit)
    }

    private static func looksLikeCode(_ t: String) -> Bool {
        guard t.contains("\n") else { return false }
        let keywords = ["func ", "let ", "var ", "return ", "class ", "struct ",
                        "def ", "const ", "function ", "import ", "->", "{"]
        return keywords.contains { t.contains($0) }
    }
}
