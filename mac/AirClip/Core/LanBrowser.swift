import Foundation
import Network

/// Browses for `_airclip._tcp` services on the local network.
/// On discovery, caches the endpoint in ResolvedEndpointCache and hands off
/// to PeerManager to establish an outgoing connection.
@MainActor
final class LanBrowser {
    static let shared = LanBrowser()

    private var browser: NWBrowser?

    private init() {}

    // MARK: - Lifecycle

    func start() {
        guard browser == nil else { return }

        let params = NWParameters.tcp
        params.includePeerToPeer = true

        browser = NWBrowser(for: .bonjour(type: AppConfig.lanServiceType, domain: nil), using: params)

        browser?.browseResultsChangedHandler = { [weak self] results, _ in
            Task { @MainActor [weak self] in self?.handleResults(results) }
        }

        browser?.stateUpdateHandler = { state in
            Task { @MainActor in
                switch state {
                case .ready:
                    LanRuntimeDiagnostics.shared.clear()
                case .failed(let error):
                    LanRuntimeDiagnostics.shared.discoveryFailed(error.localizedDescription)
                case .waiting(let error):
                    LanRuntimeDiagnostics.shared.discoveryFailed(error.localizedDescription)
                default:
                    break
                }
            }
        }

        browser?.start(queue: .main)
    }

    func stop() {
        browser?.cancel()
        browser = nil
        // Clear the endpoint cache so stale entries don't linger after disconnect.
        // (New entries are populated on next start/discovery.)
    }

    // MARK: - Discovery

    private func handleResults(_ results: Set<NWBrowser.Result>) {
        let myId = AirClipIdentity.shared.deviceId ?? ""

        // Track which device IDs are currently visible
        var visibleIds = Set<String>()

        for result in results {
            guard case .service(let name, _, _, _) = result.endpoint else { continue }
            guard !name.isEmpty, name != myId else { continue }

            visibleIds.insert(name)
            // Cache endpoint so PairingClient can probe it during Join flow.
            ResolvedEndpointCache.shared.put(name, endpoint: result.endpoint)
            PeerManager.shared.connectIfNeeded(to: result.endpoint, peerHint: name)
        }

        // Remove endpoints that have disappeared from mDNS.
        let cached = Set(ResolvedEndpointCache.shared.all.keys)
        for gone in cached.subtracting(visibleIds) {
            ResolvedEndpointCache.shared.remove(gone)
        }
    }
}
