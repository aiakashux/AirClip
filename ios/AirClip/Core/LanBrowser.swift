import Foundation
import Network

/// Browses for `_airclip._tcp` services on the local network.
/// On discovery, hands off to PeerManager to establish an outgoing connection
/// (skipping self and already-connected peers).
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

        browser?.stateUpdateHandler = { _ in }

        browser?.start(queue: .main)
    }

    func stop() {
        browser?.cancel()
        browser = nil
    }

    // MARK: - Discovery

    private func handleResults(_ results: Set<NWBrowser.Result>) {
        let myId = AuthManager.shared.deviceId ?? ""

        for result in results {
            guard case .service(let name, _, _, _) = result.endpoint else { continue }
            guard name != myId, !name.isEmpty else { continue }
            PeerManager.shared.connectIfNeeded(to: result.endpoint, peerHint: name)
        }
    }
}
