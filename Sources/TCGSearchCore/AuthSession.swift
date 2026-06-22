import Foundation
import Combine

@MainActor
final class AuthSession: ObservableObject {
    private let api: AuthAPI
    private let tokenStore: TokenStore

    @Published private(set) var tokenPair: TokenPair?
    @Published var isRequestInFlight = false
    @Published var errorMessage: String?

    var isSignedIn: Bool {
        tokenPair != nil
    }

    init(api: AuthAPI, tokenStore: TokenStore = KeychainTokenStore()) {
        self.api = api
        self.tokenStore = tokenStore
    }

    func restore() {
        do {
            tokenPair = try tokenStore.load()
            errorMessage = nil
        } catch {
            errorMessage = Self.message(for: error)
        }
    }

    func login(id: String, password: String, deviceId: String) async {
        isRequestInFlight = true
        defer { isRequestInFlight = false }

        do {
            let tokenPair = try await api.login(id: id, password: password, deviceId: deviceId)
            try save(tokenPair)
        } catch {
            errorMessage = Self.message(for: error)
        }
    }

    func signUp(id: String, password: String, deviceId: String) async {
        isRequestInFlight = true
        defer { isRequestInFlight = false }

        do {
            let tokenPair = try await api.signUp(id: id, password: password, deviceId: deviceId)
            try save(tokenPair)
        } catch {
            errorMessage = Self.message(for: error)
        }
    }

    func refresh() async {
        guard let refreshToken = tokenPair?.refreshToken else {
            errorMessage = "저장된 리프레시 토큰이 없습니다."
            return
        }

        isRequestInFlight = true
        defer { isRequestInFlight = false }

        do {
            let tokenPair = try await api.refresh(refreshToken: refreshToken)
            try save(tokenPair)
        } catch {
            errorMessage = Self.message(for: error)
        }
    }

    func logout() async {
        let refreshToken = tokenPair?.refreshToken
        isRequestInFlight = true
        defer { isRequestInFlight = false }

        do {
            if let refreshToken {
                try await api.logout(refreshToken: refreshToken)
            }
            try tokenStore.clear()
            tokenPair = nil
            errorMessage = nil
        } catch {
            errorMessage = Self.message(for: error)
        }
    }

    private func save(_ tokenPair: TokenPair) throws {
        try tokenStore.save(tokenPair)
        self.tokenPair = tokenPair
        errorMessage = nil
    }

    private static func message(for error: Error) -> String {
        guard let error = error as? AuthClientError else {
            return "요청을 처리하지 못했습니다."
        }

        switch error {
        case .httpStatus(401):
            return "인증 정보를 확인해 주세요."
        case .httpStatus(409):
            return "이미 사용 중인 ID입니다."
        case .httpStatus:
            return "서버 요청이 실패했습니다."
        case .invalidResponse:
            return "서버 응답을 확인할 수 없습니다."
        }
    }
}
