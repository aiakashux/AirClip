import Foundation
import Network

enum AppConfig {
    static let defaultServerURL  = "http://127.0.0.1:8000"
    static let bundleID          = "com.airclip.airclip"
    static let keychainService   = "com.airclip.airclip"

    // LAN sync
    static let lanPort:        NWEndpoint.Port = 7878
    static let lanServiceType: String          = "_airclip._tcp"
}
