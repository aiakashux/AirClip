import Foundation

@main
struct ClipTypeDetectorCheck {
    static func main() {
        precondition(ClipType.detect("#FF00AA") == .color)
        precondition(ClipType.detect("FF00AA") == .color)
        precondition(ClipType.detect("abcdef") == .text)
        precondition(ClipType.detect("123456") == .text)
        precondition(ClipType.detect("rgb(12, 34, 56)") == .color)
        precondition(ClipType.detect("rgba(12, 34, 56, 0.5)") == .color)
    }
}
