import Foundation
import Network

@MainActor final class AirclipIdentity {
    static let shared = AirclipIdentity()
    var deviceId: String?
    func ensureDeviceId() { if deviceId == nil { deviceId = UUID().uuidString } }
}
enum AppConfig {
    static let lanPort = NWEndpoint.Port.any
    static let lanServiceType = "_airclip._tcp"
}
@MainActor final class PeerConnection {
    init(connection: NWConnection, isIncoming: Bool) {}
}
@MainActor final class PeerManager {
    static let shared = PeerManager()
    func addIncoming(_ peer: PeerConnection) {}
}
@main struct PairingServerStartupCheck {
    @MainActor static func main() {
        precondition(AirclipIdentity.shared.deviceId == nil)
        LanServer.shared.start()
        precondition(AirclipIdentity.shared.deviceId != nil,
                     "A fresh Mac must get an identity before starting its pairing listener")
        LanServer.shared.stop()
    }
}
