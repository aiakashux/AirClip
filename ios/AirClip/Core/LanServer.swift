import Foundation
import Network

/// Runs a local WebSocket server on `AppConfig.lanPort`.
/// Advertises `_airclip._tcp` via mDNS so peers on the same LAN can discover it.
/// The service name is the device_id — LanBrowser uses this to skip self-discovery.
@MainActor
final class LanServer {
    static let shared = LanServer()

    private var listener: NWListener?

    private init() {}

    // MARK: - Lifecycle

    func start() {
        guard listener == nil else { return }
        guard let deviceId = AuthManager.shared.deviceId, !deviceId.isEmpty else { return }

        let params    = NWParameters.tcp
        let wsOptions = NWProtocolWebSocket.Options()
        wsOptions.autoReplyPing = true
        params.defaultProtocolStack.applicationProtocols.insert(wsOptions, at: 0)

        guard let l = try? NWListener(using: params, on: AppConfig.lanPort) else { return }
        listener = l

        l.service = NWListener.Service(name: deviceId, type: AppConfig.lanServiceType)

        l.stateUpdateHandler = { state in
            if case .failed(_) = state { }   // swallowed — server restarts on next connect()
        }

        l.newConnectionHandler = { [weak self] connection in
            Task { @MainActor [weak self] in
                guard let self else { return }
                let peer = PeerConnection(connection: connection, isIncoming: true)
                PeerManager.shared.addIncoming(peer)
            }
        }

        l.start(queue: .main)
    }

    func stop() {
        listener?.cancel()
        listener = nil
    }
}
