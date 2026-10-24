import Foundation

enum PeerHeartbeatPolicy {
    static let timeout: TimeInterval = 45

    static func hasTimedOut(lastAckAt: TimeInterval, now: TimeInterval) -> Bool {
        now - lastAckAt >= timeout
    }
}
