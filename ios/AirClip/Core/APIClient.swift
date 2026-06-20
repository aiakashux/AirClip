import Foundation

// MARK: - Response models

struct AuthResponse: Codable {
    let accountToken: String
    enum CodingKeys: String, CodingKey {
        case accountToken = "token"
    }
}

struct DeviceRegisterResponse: Codable {
    let deviceId: String
    let deviceToken: String?
    let trustStatus: String
    enum CodingKeys: String, CodingKey {
        case deviceId    = "device_id"
        case deviceToken = "token"
        case trustStatus = "trust_status"
    }
}

struct DeviceInfo: Codable, Identifiable {
    let id: String
    let name: String
    let trustStatus: String
    let publicKey: String?
    let isOnline: Bool?
    enum CodingKeys: String, CodingKey {
        case id          = "device_id"
        case name        = "device_name"
        case trustStatus = "trust_status"
        case publicKey   = "public_key"
        case isOnline    = "is_online"
    }
}

// MARK: - Errors

enum APIError: Error, LocalizedError {
    case invalidURL
    case httpError(Int, String)
    case decodingError(Error)
    case noToken

    var errorDescription: String? {
        switch self {
        case .invalidURL:              return "Invalid server URL"
        case .httpError(let c, let m): return "Server error \(c): \(m)"
        case .decodingError(let e):    return "Parse error: \(e.localizedDescription)"
        case .noToken:                 return "Not authenticated"
        }
    }
}

// MARK: - Client

@MainActor
final class APIClient {
    static let shared = APIClient()
    private init() {}

    private var baseURL: String {
        UserDefaults.standard.string(forKey: "serverURL") ?? AppConfig.defaultServerURL
    }

    // MARK: Auth

    func register(email: String, password: String) async throws -> AuthResponse {
        try await post(path: "/auth/register", body: ["email": email, "password": password], token: nil)
    }

    func login(email: String, password: String) async throws -> AuthResponse {
        try await post(path: "/auth/login", body: ["email": email, "password": password], token: nil)
    }

    // MARK: Devices

    func registerDevice(name: String, publicKey: String) async throws -> DeviceRegisterResponse {
        guard let token = AuthManager.shared.accountToken else { throw APIError.noToken }
        return try await post(
            path: "/devices/register",
            body: ["device_name": name, "public_key": publicKey, "platform": "ios"],
            token: token
        )
    }

    func listDevices() async throws -> [DeviceInfo] {
        guard let token = AuthManager.shared.accountToken else { throw APIError.noToken }
        return try await get(path: "/devices/", token: token)
    }

    func deleteDevice(id: String) async throws {
        guard let token = AuthManager.shared.accountToken else { throw APIError.noToken }
        guard let url = URL(string: baseURL + "/devices/\(id)") else { throw APIError.invalidURL }
        var req = URLRequest(url: url)
        req.httpMethod = "DELETE"
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        let (_, response) = try await URLSession.shared.data(for: req)
        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            throw APIError.httpError(http.statusCode, "Delete failed")
        }
    }

    // MARK: HTTP helpers

    private func post<Body: Encodable, Response: Decodable>(
        path: String,
        body: Body,
        token: String?
    ) async throws -> Response {
        guard let url = URL(string: baseURL + path) else { throw APIError.invalidURL }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let token { req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization") }
        req.httpBody = try JSONEncoder().encode(body)
        return try await execute(req)
    }

    private func get<Response: Decodable>(path: String, token: String?) async throws -> Response {
        guard let url = URL(string: baseURL + path) else { throw APIError.invalidURL }
        var req = URLRequest(url: url)
        if let token { req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization") }
        return try await execute(req)
    }

    private func execute<Response: Decodable>(_ req: URLRequest) async throws -> Response {
        let (data, response) = try await URLSession.shared.data(for: req)
        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            let body = String(data: data, encoding: .utf8) ?? ""
            throw APIError.httpError(http.statusCode, body)
        }
        do {
            return try JSONDecoder().decode(Response.self, from: data)
        } catch {
            throw APIError.decodingError(error)
        }
    }
}
