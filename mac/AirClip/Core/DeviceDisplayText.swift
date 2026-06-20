import Foundation

enum DeviceDisplayText {
    static func clipped(_ text: String, maxCharacters: Int = 36) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count > maxCharacters else { return trimmed }
        guard maxCharacters > 3 else { return String(trimmed.prefix(maxCharacters)) }
        return String(trimmed.prefix(maxCharacters - 3)) + "..."
    }
}
