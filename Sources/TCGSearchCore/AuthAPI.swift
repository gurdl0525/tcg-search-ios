import Foundation

protocol AuthAPI: Sendable {
    func login(id: String, password: String, deviceId: String) async throws -> TokenPair

    func signUp(id: String, password: String, deviceId: String) async throws -> TokenPair

    func refresh(refreshToken: String) async throws -> TokenPair

    func logout(refreshToken: String) async throws
}
