import SwiftUI

enum AppAppearanceSetting: Int, CaseIterable {
    case system = 0
    case light
    case dark

    var label: String {
        switch self {
        case .system: return "System"
        case .light: return "Light"
        case .dark: return "Dark"
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}

@MainActor
final class AppAppearanceStore: ObservableObject {
    static let shared = AppAppearanceStore()

    @Published var rawValue: Int {
        didSet {
            UserDefaults.standard.set(rawValue, forKey: Self.userDefaultsKey)
        }
    }

    var setting: AppAppearanceSetting {
        AppAppearanceSetting(rawValue: rawValue) ?? .system
    }

    var colorScheme: ColorScheme? {
        setting.colorScheme
    }

    private static let userDefaultsKey = "appearanceSetting"

    private init() {
        rawValue = UserDefaults.standard.object(forKey: Self.userDefaultsKey) as? Int ?? AppAppearanceSetting.system.rawValue
    }
}
