import CoreWLAN
import CoreLocation
import Foundation

enum WiFiNetworkNameStatus: Equatable {
    case available(String)
    case permissionNeeded
    case unavailable

    var displayName: String {
        switch self {
        case .available(let name):
            return name
        case .permissionNeeded, .unavailable:
            return "Wi-Fi name unavailable"
        }
    }

    var helperText: String? {
        switch self {
        case .available:
            return nil
        case .permissionNeeded:
            return "Allow Location access to show Wi-Fi name."
        case .unavailable:
            return "Check Wi-Fi and Location access."
        }
    }
}

@MainActor
final class CurrentWiFiNetwork: NSObject, ObservableObject, @preconcurrency CLLocationManagerDelegate {
    static let shared = CurrentWiFiNetwork()

    @Published private(set) var name: String?
    @Published private(set) var status: WiFiNetworkNameStatus = .unavailable

    private let locationManager = CLLocationManager()

    private override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyThreeKilometers
        refresh()
    }

    func requestAccessAndRefresh() {
        switch locationManager.authorizationStatus {
        case .notDetermined:
            status = .permissionNeeded
            locationManager.requestWhenInUseAuthorization()
            locationManager.startUpdatingLocation()
        default:
            refresh()
        }
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        refresh()
        if manager.authorizationStatus != .notDetermined {
            manager.stopUpdatingLocation()
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        refresh()
        manager.stopUpdatingLocation()
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        refresh()
        manager.stopUpdatingLocation()
    }

    func refresh() {
        name = CWWiFiClient.shared().interface()?.ssid()
        if let name, !name.isEmpty {
            status = .available(name)
            return
        }

        switch locationManager.authorizationStatus {
        case .notDetermined, .restricted, .denied:
            status = .permissionNeeded
        default:
            status = .unavailable
        }
    }
}
