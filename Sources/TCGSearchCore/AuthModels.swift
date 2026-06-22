import Foundation

struct TokenPair: Codable, Equatable {
    let accessToken: String
    let refreshToken: String
    let tokenType: String
    let expiresIn: Int

    var authorizationHeader: String {
        "\(tokenType) \(accessToken)"
    }

    private enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case tokenType = "token_type"
        case expiresIn = "expires_in"
    }
}

struct CredentialRequest: Encodable {
    let id: String
    let password: String
    let deviceId: String

    private enum CodingKeys: String, CodingKey {
        case id
        case password
        case deviceId = "device_id"
    }
}

struct RefreshTokenRequest: Encodable {
    let refreshToken: String

    private enum CodingKeys: String, CodingKey {
        case refreshToken = "refresh_token"
    }
}
