import Foundation

struct AuthClient: AuthAPI {
    private let baseURL: URL
    private let transport: HTTPTransport

    init(
        baseURL: URL,
        transport: HTTPTransport = URLSessionHTTPTransport(),
    ) {
        self.baseURL = baseURL
        self.transport = transport
    }

    func login(id: String, password: String, deviceId: String) async throws -> TokenPair {
        try await sendTokenRequest(
            path: "/api/auth/login",
            body: CredentialRequest(id: id, password: password, deviceId: deviceId),
            expectedStatus: 200,
        )
    }

    func signUp(id: String, password: String, deviceId: String) async throws -> TokenPair {
        try await sendTokenRequest(
            path: "/api/auth/signup",
            body: CredentialRequest(id: id, password: password, deviceId: deviceId),
            expectedStatus: 201,
        )
    }

    func refresh(refreshToken: String) async throws -> TokenPair {
        try await sendTokenRequest(
            path: "/api/auth/refresh",
            body: RefreshTokenRequest(refreshToken: refreshToken),
            expectedStatus: 200,
        )
    }

    func logout(refreshToken: String) async throws {
        let request = try makeRequest(
            path: "/api/auth/logout",
            body: RefreshTokenRequest(refreshToken: refreshToken),
        )
        let (_, response) = try await transport.data(for: request)

        guard response.statusCode == 204 else {
            throw AuthClientError.httpStatus(response.statusCode)
        }
    }

    private func sendTokenRequest<Body: Encodable>(
        path: String,
        body: Body,
        expectedStatus: Int,
    ) async throws -> TokenPair {
        let request = try makeRequest(path: path, body: body)
        let (data, response) = try await transport.data(for: request)

        guard response.statusCode == expectedStatus else {
            throw AuthClientError.httpStatus(response.statusCode)
        }

        return try JSONDecoder().decode(TokenPair.self, from: data)
    }

    private func makeRequest<Body: Encodable>(path: String, body: Body) throws -> URLRequest {
        let endpoint = baseURL.appendingPathComponent(path.trimmingCharacters(in: CharacterSet(charactersIn: "/")))
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(body)
        return request
    }
}

enum AuthClientError: Error, Equatable {
    case invalidResponse
    case httpStatus(Int)
}
