import Foundation

@main
struct DeviceDisplayTextCheck {
    static func main() {
        precondition(DeviceDisplayText.clipped("OnePlus 6") == "OnePlus 6")
        precondition(DeviceDisplayText.clipped(String(repeating: "A", count: 36)).count == 36)

        let clipped = DeviceDisplayText.clipped(String(repeating: "B", count: 50))
        precondition(clipped.count == 36)
        precondition(clipped.hasSuffix("..."))
    }
}
