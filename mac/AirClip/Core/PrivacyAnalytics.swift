import Foundation

enum AnalyticsEvent: String, CaseIterable {
    case pairingSuccess = "pairing_success"
    case pairingFailure = "pairing_failure"
    case firstTransfer = "first_transfer"
    case transferFailure = "transfer_failure"
    case updateCheck = "update_check"
    case updateAvailable = "update_available"
    case updateOpened = "update_opened"
    case updateFailure = "update_failure"
}

@MainActor
final class PrivacyAnalytics: ObservableObject {
    static let shared = PrivacyAnalytics()

    @Published var isEnabled: Bool {
        didSet {
            defaults.set(isEnabled, forKey: enabledKey)
            if !isEnabled { clear() }
        }
    }

    private let defaults = UserDefaults.standard
    private let enabledKey = "com.airclip.analytics.enabled"
    private let lastUploadKey = "com.airclip.analytics.lastUpload"
    private let firstTransferKey = "com.airclip.analytics.firstTransfer"
    private let endpoint = URL(string: "https://airclip-silk.vercel.app/api/analytics")!

    private init() {
        isEnabled = defaults.bool(forKey: enabledKey)
    }

    func record(_ event: AnalyticsEvent) {
        guard isEnabled else { return }
        if event == .firstTransfer, defaults.bool(forKey: firstTransferKey) { return }
        let key = "com.airclip.analytics.count.\(event.rawValue)"
        defaults.set(defaults.integer(forKey: key) + 1, forKey: key)
        if event == .firstTransfer { defaults.set(true, forKey: firstTransferKey) }
    }

    func flushIfDue() {
        guard isEnabled else { return }
        let now = Date()
        if let last = defaults.object(forKey: lastUploadKey) as? Date,
           now.timeIntervalSince(last) < 86_400 { return }

        let counts = Dictionary(uniqueKeysWithValues: AnalyticsEvent.allCases.compactMap { event in
            let value = defaults.integer(forKey: "com.airclip.analytics.count.\(event.rawValue)")
            return value > 0 ? (event.rawValue, value) : nil
        })
        guard !counts.isEmpty else { return }

        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "unknown"
        let osMajor = ProcessInfo.processInfo.operatingSystemVersion.majorVersion
        let body: [String: Any] = [
            "schemaVersion": 1,
            "appVersion": version,
            "platform": "macos",
            "osMajor": String(osMajor),
            "counts": counts,
        ]
        guard let data = try? JSONSerialization.data(withJSONObject: body) else { return }
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = data

        Task {
            guard let (_, response) = try? await URLSession.shared.data(for: request),
                  (response as? HTTPURLResponse)?.statusCode == 204 else { return }
            defaults.set(now, forKey: lastUploadKey)
            counts.keys.forEach { defaults.removeObject(forKey: "com.airclip.analytics.count.\($0)") }
        }
    }

    private func clear() {
        defaults.removeObject(forKey: lastUploadKey)
        defaults.removeObject(forKey: firstTransferKey)
        AnalyticsEvent.allCases.forEach {
            defaults.removeObject(forKey: "com.airclip.analytics.count.\($0.rawValue)")
        }
    }
}
