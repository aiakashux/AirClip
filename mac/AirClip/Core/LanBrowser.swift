import Foundation
import Network
import SystemConfiguration

/// Browses for `_airclip._tcp` services on the local network.
/// On discovery, caches the endpoint in ResolvedEndpointCache and hands off
/// to PeerManager to establish an outgoing connection.
@MainActor
final class LanBrowser {
    static let shared = LanBrowser()

    private var browser: NWBrowser?
    private var hotspotFallbackTimer: Timer?
    private var visiblePeerCount = 0

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

        browser?.stateUpdateHandler = { [weak self] state in
            Task { @MainActor [weak self] in
                switch state {
                case .ready:
                    LanRuntimeDiagnostics.shared.clear()
                case .failed(let error):
                    LanRuntimeDiagnostics.shared.discoveryFailed(error.localizedDescription)
                    self?.browser?.cancel()
                    self?.browser = nil
                    Task { @MainActor [weak self] in
                        try? await Task.sleep(for: .seconds(2))
                        guard AirclipIdentity.shared.isPaired,
                              SyncModeStore.shared.mode.keepsLanServiceRunning else { return }
                        self?.start()
                    }
                case .waiting(let error):
                    LanRuntimeDiagnostics.shared.discoveryFailed(error.localizedDescription)
                default:
                    break
                }
            }
        }

        browser?.start(queue: .main)
        hotspotFallbackTimer = Timer.scheduledTimer(withTimeInterval: 15, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in self?.probeHotspotGatewayIfNeeded() }
        }
    }

    func stop() {
        browser?.cancel()
        browser = nil
        hotspotFallbackTimer?.invalidate()
        hotspotFallbackTimer = nil
        visiblePeerCount = 0
        // Clear the endpoint cache so stale entries don't linger after disconnect.
        // (New entries are populated on next start/discovery.)
    }

    // MARK: - Discovery

    private func handleResults(_ results: Set<NWBrowser.Result>) {
        let myId = AirclipIdentity.shared.deviceId ?? ""

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
        visiblePeerCount = visibleIds.intersection(AirclipIdentity.shared.pairedDevices.keys).count
        probeHotspotGatewayIfNeeded()

        // Remove endpoints that have disappeared from mDNS.
        let cached = Set(ResolvedEndpointCache.shared.all.keys)
        for gone in cached.subtracting(visibleIds) {
            ResolvedEndpointCache.shared.remove(gone)
        }
    }

    private func probeHotspotGatewayIfNeeded() {
        let androidDevice = AirclipIdentity.shared.pairedDevices.values.first {
            let identity = "\($0.platform) \($0.deviceName)".lowercased()
            return identity.contains("android") || identity.contains("oneplus") || identity.contains("pixel") || identity.contains("samsung")
        }
        guard HotspotFallbackPolicy.shouldProbeDefaultGateway(
            visiblePeerCount: visiblePeerCount,
            connectedPeerCount: PeerManager.shared.connectedCount,
            hasPairedAndroidDevice: androidDevice != nil
        ), let androidDevice, let gateway = Self.defaultGateway() else { return }

        PeerManager.shared.connectIfNeeded(
            to: .hostPort(host: NWEndpoint.Host(gateway), port: AppConfig.lanPort),
            peerHint: androidDevice.deviceId
        )
    }

    private static func defaultGateway() -> String? {
        let key = "State:/Network/Global/IPv4" as CFString
        let state = SCDynamicStoreCopyValue(nil, key) as? [String: Any]
        return state?["Router"] as? String
    }
}
