// APIClient is no longer used — all sync is LAN-based via AirClipIdentity + LanServer/LanBrowser.
// Kept as an empty stub so the Xcode project file doesn't need updating.

import Foundation

@MainActor
final class APIClient {
    static let shared = APIClient()
    private init() {}
}
