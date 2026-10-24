import Foundation

@main
struct PeerHeartbeatPolicyCheck {
    static func main() {
        precondition(!PeerHeartbeatPolicy.hasTimedOut(
            lastAckAt: 100,
            now: 100 + PeerHeartbeatPolicy.timeout - 0.001
        ))
        precondition(PeerHeartbeatPolicy.hasTimedOut(
            lastAckAt: 100,
            now: 100 + PeerHeartbeatPolicy.timeout
        ))
    }
}
