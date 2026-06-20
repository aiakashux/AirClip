import Foundation
import Network
import Combine

enum LanRuntimeIssue {
    case none
    case serverFailed
    case discoveryFailed
}

struct LanRuntimeDiagnostic {
    var issue: LanRuntimeIssue = .none
    var detail: String?
}

@MainActor
final class LanRuntimeDiagnostics: ObservableObject {
    static let shared = LanRuntimeDiagnostics()

    @Published private(set) var diagnostic = LanRuntimeDiagnostic()

    private init() {}

    func clear() {
        diagnostic = LanRuntimeDiagnostic()
    }

    func serverFailed(_ detail: String?) {
        diagnostic = LanRuntimeDiagnostic(issue: .serverFailed, detail: detail)
    }

    func discoveryFailed(_ detail: String?) {
        diagnostic = LanRuntimeDiagnostic(issue: .discoveryFailed, detail: detail)
    }
}

/// Runs a local WebSocket server on `AppConfig.lanPort`.
/// Advertises `_airclip._tcp` via mDNS with device_id as the service name.
/// Incoming connections become PeerConnection objects — all auth/pairing
/// logic lives there.
@MainActor
final class LanServer {
    static let shared = LanServer()

    private var listener: NWListener?

    private init() {}

    // MARK: - Lifecycle

    func start() {
        guard listener == nil else { return }
        guard let deviceId = AirClipIdentity.shared.deviceId, !deviceId.isEmpty else { return }

        let params    = NWParameters.tcp
        let wsOptions = NWProtocolWebSocket.Options()
        wsOptions.autoReplyPing = true
        params.defaultProtocolStack.applicationProtocols.insert(wsOptions, at: 0)

        let l: NWListener
        do {
            l = try NWListener(using: params, on: AppConfig.lanPort)
        } catch {
            LanRuntimeDiagnostics.shared.serverFailed(error.localizedDescription)
            return
        }
        listener = l

        // Bonjour service name = device_id so peers can skip self-connection.
        l.service = NWListener.Service(name: deviceId, type: AppConfig.lanServiceType)

        l.stateUpdateHandler = { state in
            Task { @MainActor in
                switch state {
                case .ready:
                    LanRuntimeDiagnostics.shared.clear()
                case .failed(let error):
                    LanRuntimeDiagnostics.shared.serverFailed(error.localizedDescription)
                default:
                    break
                }
            }
        }

        l.newConnectionHandler = { [weak self] connection in
            Task { @MainActor [weak self] in
                guard self != nil else { return }
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
