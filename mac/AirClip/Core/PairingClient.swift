import Foundation
import Network

// MARK: - Resolved Endpoint Cache

/// Maps discovered mDNS device_ids to their NWEndpoints so PairingClient
/// can connect directly for pair_probe / pair_request exchanges.
final class ResolvedEndpointCache {
    static let shared = ResolvedEndpointCache()
    private var cache: [String: NWEndpoint] = [:]
    private init() {}

    func put(_ deviceId: String, endpoint: NWEndpoint) { cache[deviceId] = endpoint }
    func remove(_ deviceId: String)                     { cache.removeValue(forKey: deviceId) }
    var all: [String: NWEndpoint]                       { cache }
    var isEmpty: Bool                                   { cache.isEmpty }
}

// MARK: - Pairing Client

/// Handles the outgoing side of the pairing flow (Mac joining an existing AirClip network):
///
///   Strategy (in order):
///   1. Poll mDNS cache up to 8s — catches most cases once discovery completes.
///   2. Subnet scan in parallel — catches cases where mDNS is slow/broken.
///      Derives the /24 subnet from our own LAN IP and probes port 7878 on all hosts.
@MainActor
final class PairingClient {
    static let shared = PairingClient()

    // Keep exchanges alive until they complete.
    private var activeExchanges: Set<PairingExchange> = []
    private var subnetDone = false

    private init() {}

    // MARK: - Public API

    func joinAirClip(
        code: String,
        myName: String,
        onSuccess: @escaping (String, [PairedDevice]) -> Void,
        onError: @escaping (String) -> Void
    ) {
        AirClipIdentity.shared.ensureDeviceId()
        subnetDone = false

        Task { @MainActor [weak self] in
            guard let self else { return }

            // Phase 1: Poll mDNS for up to 8 seconds (16 × 500 ms).
            for _ in 0..<16 {
                let endpoints = Array(ResolvedEndpointCache.shared.all.values)
                if !endpoints.isEmpty {
                    self.probeAll(endpoints, code: code, myName: myName,
                                  onSuccess: onSuccess, onError: onError)
                    return
                }
                try? await Task.sleep(nanoseconds: 500_000_000)
            }

            // Phase 2: mDNS gave us nothing — scan the local /24 subnet directly.
            self.scanSubnet(code: code, myName: myName, onSuccess: onSuccess, onError: onError)
        }
    }

    // MARK: - Probe endpoints from mDNS cache

    private func probeAll(
        _ endpoints: [NWEndpoint],
        code: String,
        myName: String,
        onSuccess: @escaping (String, [PairedDevice]) -> Void,
        onError: @escaping (String) -> Void
    ) {
        probeNext(Array(endpoints), code: code, myName: myName, onSuccess: onSuccess, onError: onError)
    }

    private func probeNext(
        _ endpoints: [NWEndpoint],
        code: String,
        myName: String,
        onSuccess: @escaping (String, [PairedDevice]) -> Void,
        onError: @escaping (String) -> Void
    ) {
        guard let endpoint = endpoints.first else {
            onError("No device found with that code. Check the code and try again.")
            return
        }
        let rest = Array(endpoints.dropFirst())

        let ex = PairingExchange(endpoint: endpoint)
        activeExchanges.insert(ex)

        ex.sendAndReceive(["type": "pair_probe", "code": code]) { [weak self] response in
            guard let self else { return }
            self.activeExchanges.remove(ex)

            guard
                let resp     = response,
                (resp["type"] as? String) == "pair_info",
                let targetId = resp["device_id"]  as? String,
                let targetPk = resp["public_key"] as? String
            else {
                self.probeNext(rest, code: code, myName: myName, onSuccess: onSuccess, onError: onError)
                return
            }

            let targetName   = resp["device_name"] as? String ?? targetId
            let targetAirClipId = resp["airclip_id"]     as? String ?? ""

            self.sendPairRequest(
                to: endpoint,
                targetId: targetId, targetName: targetName,
                targetPubKey: targetPk, targetAirClipId: targetAirClipId,
                code: code, myName: myName,
                onSuccess: onSuccess, onError: onError
            )
        }
    }

    // MARK: - Subnet scan (fallback when mDNS finds nothing)

    private func scanSubnet(
        code: String,
        myName: String,
        onSuccess: @escaping (String, [PairedDevice]) -> Void,
        onError: @escaping (String) -> Void
    ) {
        guard let myIP = PairingSession.localLANAddress() else {
            onError("No AirClip devices found. Make sure you're on the same Wi-Fi.")
            return
        }

        let parts = myIP.split(separator: ".")
        guard parts.count == 4 else {
            onError("No AirClip devices found. Make sure you're on the same Wi-Fi.")
            return
        }
        let prefix = "\(parts[0]).\(parts[1]).\(parts[2])."

        var remaining = 253  // 254 hosts minus ourselves
        subnetDone = false

        for i in 1...254 {
            let host = "\(prefix)\(i)"
            guard host != myIP else { remaining -= 1; continue }

            let endpoint = NWEndpoint.hostPort(
                host: NWEndpoint.Host(host),
                port: AppConfig.lanPort
            )
            let ex = PairingExchange(endpoint: endpoint)
            activeExchanges.insert(ex)

            ex.sendAndReceive(["type": "pair_probe", "code": code], timeout: 2.5) { [weak self] response in
                guard let self, !self.subnetDone else { return }
                self.activeExchanges.remove(ex)
                remaining -= 1

                if let resp = response,
                   (resp["type"] as? String) == "pair_info",
                   let targetId = resp["device_id"]  as? String,
                   let targetPk = resp["public_key"] as? String {
                    self.subnetDone = true
                    let targetName   = resp["device_name"] as? String ?? targetId
                    let targetAirClipId = resp["airclip_id"]     as? String ?? ""
                    self.sendPairRequest(
                        to: endpoint,
                        targetId: targetId, targetName: targetName,
                        targetPubKey: targetPk, targetAirClipId: targetAirClipId,
                        code: code, myName: myName,
                        onSuccess: onSuccess, onError: onError
                    )
                } else if remaining <= 0 && !self.subnetDone {
                    self.subnetDone = true
                    onError("No AirClip devices found. Make sure you're on the same Wi-Fi.")
                }
            }
        }
    }

    // MARK: - Pair request

    private func sendPairRequest(
        to endpoint: NWEndpoint,
        targetId: String, targetName: String,
        targetPubKey: String, targetAirClipId: String,
        code: String, myName: String,
        onSuccess: @escaping (String, [PairedDevice]) -> Void,
        onError: @escaping (String) -> Void
    ) {
        guard
            let myId  = AirClipIdentity.shared.deviceId,
            let myKey = try? CryptoManager.shared.publicKeyBase64
        else { onError("Device not initialized"); return }

        let myAirClipId = AirClipIdentity.shared.airClipId ?? targetAirClipId

        let ex = PairingExchange(endpoint: endpoint)
        activeExchanges.insert(ex)

        ex.sendAndReceive([
            "type":        "pair_request",
            "code":        code,
            "device_id":   myId,
            "device_name": myName,
            "public_key":  myKey,
            "airclip_id":     myAirClipId,
            "platform":    "mac",
        ]) { [weak self] response in
            guard let self else { return }
            self.activeExchanges.remove(ex)

            guard
                let resp   = response,
                (resp["type"] as? String) == "pair_ok",
                let airClipId = resp["airclip_id"] as? String
            else {
                let reason = (response?["reason"] as? String) ?? "Unexpected response"
                onError("Pairing failed: \(reason)")
                return
            }

            let rawDevices = resp["all_devices"] as? [[String: String]] ?? []
            let devices = rawDevices.compactMap { d -> PairedDevice? in
                guard let id = d["device_id"], let name = d["device_name"], let pk = d["public_key"]
                else { return nil }
                return PairedDevice(deviceId: id, deviceName: name, publicKey: pk, platform: d["platform"] ?? "")
            }

            let newPeer = PairedDevice(
                deviceId: targetId, deviceName: targetName,
                publicKey: targetPubKey, platform: "android"
            )
            let allDevices = devices.filter { $0.deviceId != targetId && $0.deviceId != myId } + [newPeer]
            onSuccess(airClipId, allDevices)
        }
    }
}

// MARK: - Pairing Exchange (one-shot WS connection)

final class PairingExchange: Hashable {
    private let connection: NWConnection
    private var completionHandler: (([String: Any]?) -> Void)?
    private var timeoutTask: DispatchWorkItem?

    init(endpoint: NWEndpoint) {
        let params    = NWParameters.tcp
        let wsOpts    = NWProtocolWebSocket.Options()
        wsOpts.autoReplyPing = true
        params.defaultProtocolStack.applicationProtocols.insert(wsOpts, at: 0)
        connection = NWConnection(to: endpoint, using: params)
    }

    func sendAndReceive(_ payload: [String: Any], timeout: TimeInterval = 8, completion: @escaping ([String: Any]?) -> Void) {
        completionHandler = completion

        connection.stateUpdateHandler = { [weak self] state in
            Task { @MainActor [weak self] in
                switch state {
                case .ready:             self?.send(payload)
                case .failed, .cancelled: self?.finish(with: nil)
                default: break
                }
            }
        }
        connection.start(queue: .main)

        let work = DispatchWorkItem { [weak self] in
            Task { @MainActor [weak self] in self?.finish(with: nil) }
        }
        timeoutTask = work
        DispatchQueue.main.asyncAfter(deadline: .now() + timeout, execute: work)
    }

    private func send(_ payload: [String: Any]) {
        guard let data = try? JSONSerialization.data(withJSONObject: payload) else {
            finish(with: nil); return
        }
        let meta    = NWProtocolWebSocket.Metadata(opcode: .text)
        let context = NWConnection.ContentContext(identifier: "pair", metadata: [meta])
        connection.send(content: data, contentContext: context, isComplete: true, completion: .idempotent)
        receiveResponse()
    }

    private func receiveResponse() {
        connection.receiveMessage { [weak self] data, _, _, error in
            Task { @MainActor [weak self] in
                guard let self else { return }
                if let data, error == nil,
                   let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    self.finish(with: json)
                } else {
                    self.finish(with: nil)
                }
            }
        }
    }

    private func finish(with response: [String: Any]?) {
        timeoutTask?.cancel()
        timeoutTask = nil
        let handler = completionHandler
        completionHandler = nil
        connection.cancel()
        handler?(response)
    }

    static func == (l: PairingExchange, r: PairingExchange) -> Bool { l === r }
    func hash(into hasher: inout Hasher) { hasher.combine(ObjectIdentifier(self)) }
}
