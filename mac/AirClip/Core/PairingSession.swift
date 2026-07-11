import Foundation
import CoreImage
import AppKit
import Darwin

// MARK: - Pairing Payload

struct PairingPayload: Codable {
    let airclip_id: String?
    let device_id: String
    let device_name: String
    let public_key: String
    let code: String
    /// LAN IP of the host so the joining device can connect directly (no mDNS race).
    let host: String?
    /// WiFi SSID of the host — shown to joining device if it's on a different network.
    let ssid: String?
}

// MARK: - Pairing Session

/// Manages the ephemeral pairing session for this device.
///
/// - Generates a 6-digit OTP refreshed every 60 s silently.
/// - Renders a QR code (via Core Image) embedding airclip_id + device identity + OTP.
/// - `verifyCode(_:)` used by PeerConnection to validate incoming pair_request / pair_probe.
@MainActor
final class PairingSession: ObservableObject {
    static let shared = PairingSession()

    @Published private(set) var currentCode: String?
    @Published private(set) var qrImage: NSImage?

    /// Called by PeerConnection when a pair_request is accepted.
    var onPairSuccess: (() -> Void)?

    private var payload: PairingPayload?
    private var timer: Timer?

    private init() {}

    // MARK: - Lifecycle

    func start() {
        stop()
        AirClipIdentity.shared.ensureDeviceId()
        guard
            let deviceId  = AirClipIdentity.shared.deviceId,
            let publicKey = try? CryptoManager.shared.publicKeyBase64
        else { return }

        refresh(deviceId: deviceId, publicKey: publicKey)
        timer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.refresh(deviceId: deviceId, publicKey: publicKey)
            }
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        payload = nil
        currentCode = nil
        qrImage = nil
    }

    // MARK: - Verification

    func verifyCode(_ code: String) -> Bool {
        payload?.code == Self.normalizedCode(code)
    }

    // MARK: - Private

    private func refresh(deviceId: String, publicKey: String) {
        let code = String(format: "%06d", Int.random(in: 0...999_999))
        let p = PairingPayload(
            airclip_id:     AirClipIdentity.shared.airClipId,
            device_id:   deviceId,
            device_name: AirClipIdentity.shared.deviceName,
            public_key:  publicKey,
            code:        code,
            host:        PairingSession.localLANAddress(),
            ssid:        PairingSession.currentSSID()
        )
        payload     = p
        currentCode = code

        Task.detached(priority: .utility) { [p] in
            let img = PairingSession.generateQR(from: p)
            await MainActor.run { [weak self] in self?.qrImage = img }
        }
    }

    nonisolated static func normalizedCode(_ code: String) -> String {
        code.filter(\.isNumber)
    }

    // MARK: - Network helpers

    /// Returns the first non-loopback IPv4 address (the LAN IP visible to peers).
    nonisolated static func localLANAddress() -> String? {
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddr) == 0, let first = ifaddr else { return nil }
        defer { freeifaddrs(first) }
        for ptr in sequence(first: first, next: { $0.pointee.ifa_next }) {
            let flags = Int32(ptr.pointee.ifa_flags)
            guard (flags & IFF_LOOPBACK) == 0,
                  (flags & IFF_UP) != 0,
                  (flags & IFF_RUNNING) != 0,
                  ptr.pointee.ifa_addr.pointee.sa_family == UInt8(AF_INET) else { continue }
            var host = [CChar](repeating: 0, count: Int(NI_MAXHOST))
            let rc = getnameinfo(ptr.pointee.ifa_addr,
                                 socklen_t(ptr.pointee.ifa_addr.pointee.sa_len),
                                 &host, socklen_t(host.count), nil, 0, NI_NUMERICHOST)
            if rc == 0 {
                let ip = String(cString: host)
                if !ip.isEmpty { return ip }
            }
        }
        return nil
    }

    /// Returns the current Wi-Fi SSID (best-effort; nil if unavailable or on Ethernet).
    nonisolated static func currentSSID() -> String? {
        // CoreWLAN is available on macOS; import is done via AppKit umbrella.
        // Use NSClassFromString to avoid a hard link on simulators / CI.
        guard let clientClass = NSClassFromString("CWWiFiClient") as? NSObject.Type,
              let client = clientClass.value(forKey: "sharedWiFiClient") as? NSObject,
              let iface  = client.value(forKey: "interface") as? NSObject,
              let ssid   = iface.value(forKey: "ssid") as? String
        else { return nil }
        return ssid
    }

    // MARK: - QR generation (Core Image)

    nonisolated private static func generateQR(from payload: PairingPayload) -> NSImage? {
        guard
            let data = try? JSONEncoder().encode(payload),
            let filter = CIFilter(name: "CIQRCodeGenerator")
        else { return nil }

        filter.setValue(data, forKey: "inputMessage")
        filter.setValue("M",  forKey: "inputCorrectionLevel")

        guard let output = filter.outputImage else { return nil }

        // Scale to ~300 pt
        let size: CGFloat = 300
        let scale = size / output.extent.width
        let scaled = output.transformed(by: CGAffineTransform(scaleX: scale, y: scale))

        let rep    = NSCIImageRep(ciImage: scaled)
        let image  = NSImage(size: rep.size)
        image.addRepresentation(rep)
        return image
    }
}
