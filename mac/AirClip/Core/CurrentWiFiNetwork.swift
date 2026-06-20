import CoreWLAN
import Foundation

enum CurrentWiFiNetwork {
    static func name() -> String? {
        CWWiFiClient.shared().interface()?.ssid()
    }
}
