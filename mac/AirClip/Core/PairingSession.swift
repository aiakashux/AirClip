import Foundation
import CoreImage
import AppKit
import Darwin

// MARK: - Pairing Payload

struct PairingPayload: Codable {
    let airclip_id: String?
    let device_id: String
    let device_name: String
    let space_name: String?
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
/// - Generates a 6-digit OTP refreshed every 30 s silently.
/// - Renders a QR code (via Core Image) embedding airclip_id + device identity + OTP.
/// - `verifyCode(_:)` used by PeerConnection to validate incoming pair_request / pair_probe.
@MainActor
final class PairingSession: ObservableObject {
    static let shared = PairingSession()
    static let codeLifetime: TimeInterval = 30
    static let previousCodeGracePeriod: TimeInterval = 30

    @Published private(set) var currentCode: String?
    @Published private(set) var qrImage: NSImage?
    @Published private(set) var qrRevision = 0
    @Published private(set) var expiresAt: Date?

    /// Called by PeerConnection when a pair_request is accepted.
    var onPairSuccess: (() -> Void)?

    private var payload: PairingPayload?
    private var previousCode: String?
    private var previousCodeValidUntil: Date?
    private var timer: Timer?

    private init() {}

    // MARK: - Lifecycle

    func start() {
        stop()
        AirclipIdentity.shared.ensureDeviceId()
        guard
            let deviceId  = AirclipIdentity.shared.deviceId,
            let publicKey = try? CryptoManager.shared.publicKeyBase64
        else { return }

        refresh(deviceId: deviceId, publicKey: publicKey)
        timer = Timer.scheduledTimer(withTimeInterval: Self.codeLifetime, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.refresh(deviceId: deviceId, publicKey: publicKey)
            }
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        payload = nil
        previousCode = nil
        previousCodeValidUntil = nil
        currentCode = nil
        qrImage = nil
        expiresAt = nil
    }

    func refreshNow() {
        guard
            let deviceId = AirclipIdentity.shared.deviceId,
            let publicKey = try? CryptoManager.shared.publicKeyBase64
        else { return }
        refresh(deviceId: deviceId, publicKey: publicKey)
    }

    // MARK: - Verification

    func verifyCode(_ code: String) -> Bool {
        let normalized = Self.normalizedCode(code)
        if payload?.code == normalized { return true }
        guard previousCode == normalized, let validUntil = previousCodeValidUntil else { return false }
        return Date() <= validUntil
    }

    // MARK: - Private

    private func refresh(deviceId: String, publicKey: String) {
        if let currentCode {
            previousCode = currentCode
            previousCodeValidUntil = Date().addingTimeInterval(Self.previousCodeGracePeriod)
        }
        let code = String(format: "%06d", Int.random(in: 0...999_999))
        let p = PairingPayload(
            airclip_id:     AirclipIdentity.shared.airClipId,
            device_id:   deviceId,
            device_name: AirclipIdentity.shared.deviceName,
            space_name:  AirclipIdentity.shared.spaceName,
            public_key:  publicKey,
            code:        code,
            host:        PairingSession.localLANAddress(),
            ssid:        PairingSession.currentSSID()
        )
        payload     = p
        currentCode = code
        expiresAt = Date().addingTimeInterval(Self.codeLifetime)

        Task.detached(priority: .utility) { [p] in
            let img = PairingSession.generateQR(from: p)
            await MainActor.run { [weak self] in
                guard let self, self.currentCode == p.code else { return }
                self.qrImage = img
                self.qrRevision += 1
            }
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
        filter.setValue("L",  forKey: "inputCorrectionLevel")

        guard let output = filter.outputImage else { return nil }

        let width = Int(output.extent.width)
        let height = Int(output.extent.height)
        var modules = [UInt8](repeating: 0, count: width * height * 4)
        CIContext().render(
            output,
            toBitmap: &modules,
            rowBytes: width * 4,
            bounds: output.extent,
            format: .RGBA8,
            colorSpace: CGColorSpaceCreateDeviceRGB()
        )

        let pixelSize = 600
        guard let context = CGContext(
            data: nil,
            width: pixelSize,
            height: pixelSize,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }

        context.setFillColor(NSColor.white.cgColor)
        context.fill(CGRect(x: 0, y: 0, width: pixelSize, height: pixelSize))
        context.setFillColor(NSColor.black.cgColor)
        let moduleSize = CGFloat(pixelSize) / CGFloat(width)
        let darkCoordinates = (0..<height).flatMap { y in
            (0..<width).compactMap { x in modules[(y * width + x) * 4] < 128 ? (x, y) : nil }
        }
        let minX = darkCoordinates.map(\.0).min() ?? 0
        let maxX = darkCoordinates.map(\.0).max() ?? width - 1
        let minY = darkCoordinates.map(\.1).min() ?? 0
        let maxY = darkCoordinates.map(\.1).max() ?? height - 1

        for y in 0..<height {
            for x in 0..<width where modules[(y * width + x) * 4] < 128 {
                let rect = CGRect(
                    x: CGFloat(x) * moduleSize,
                    y: CGFloat(y) * moduleSize,
                    width: moduleSize,
                    height: moduleSize
                )
                let isFinder =
                    (x < minX + 7 && y < minY + 7) ||
                    (x > maxX - 7 && y < minY + 7) ||
                    (x < minX + 7 && y > maxY - 7)
                let radius = isFinder ? 0 : moduleSize * 0.45
                context.addPath(CGPath(
                    roundedRect: rect,
                    cornerWidth: radius,
                    cornerHeight: radius,
                    transform: nil
                ))
                context.fillPath()
            }
        }

        guard let cgImage = context.makeImage() else { return nil }
        return NSImage(cgImage: cgImage, size: NSSize(width: 300, height: 300))
    }
}
