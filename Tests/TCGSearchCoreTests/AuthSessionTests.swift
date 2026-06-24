import Foundation
import Security
import XCTest
@testable import TCGSearchCore

@MainActor
final class AuthSessionTests: XCTestCase {
    func testLoginSavesTokenPairAndMarksSessionSignedIn() async throws {
        let api = MockAuthAPI(tokenPair: .fixture)
        let store = MemoryTokenStore()
        let session = AuthSession(api: api, tokenStore: store)

        await session.login(
            id: "collector01",
            password: "password123!",
            deviceId: "ios-primary",
        )

        XCTAssertEqual(session.tokenPair, .fixture)
        XCTAssertEqual(try store.load(), .fixture)
        XCTAssertEqual(api.loginInput?.id, "collector01")
        XCTAssertNil(session.errorMessage)
    }

    func testRestoreLoadsStoredTokenPair() throws {
        let store = MemoryTokenStore(tokenPair: .fixture)
        let session = AuthSession(api: MockAuthAPI(tokenPair: .fixture), tokenStore: store)

        session.restore()

        XCTAssertEqual(session.tokenPair, .fixture)
    }

    func testLogoutRevokesRefreshTokenAndClearsSession() async throws {
        let api = MockAuthAPI(tokenPair: .fixture)
        let store = MemoryTokenStore(tokenPair: .fixture)
        let session = AuthSession(api: api, tokenStore: store)
        session.restore()

        await session.logout()

        XCTAssertNil(session.tokenPair)
        XCTAssertNil(try store.load())
        XCTAssertEqual(api.logoutRefreshToken, "refresh-token")
    }

    func testRefreshReplacesStoredTokenPair() async throws {
        let refreshed = TokenPair(
            accessToken: "new-access-token",
            refreshToken: "new-refresh-token",
            tokenType: "Bearer",
            expiresIn: 900,
        )
        let api = MockAuthAPI(tokenPair: refreshed)
        let store = MemoryTokenStore(tokenPair: .fixture)
        let session = AuthSession(api: api, tokenStore: store)
        session.restore()

        await session.refresh()

        XCTAssertEqual(session.tokenPair, refreshed)
        XCTAssertEqual(try store.load(), refreshed)
        XCTAssertEqual(api.refreshInput, "refresh-token")
    }

    func testDuplicateSignUpErrorUsesServerErrorCodeMessage() async {
        let api = MockAuthAPI(error: .httpStatus(
            409,
            apiError: APIErrorResponse(
                code: "DUPLICATE_USER_ID",
                message: "User id already exists.",
                status: "409 CONFLICT",
            ),
        ))
        let session = AuthSession(api: api, tokenStore: MemoryTokenStore())

        await session.signUp(
            id: "collector01",
            password: "password123!",
            deviceId: "ios-primary",
        )

        XCTAssertEqual(session.errorMessage, "이미 사용 중인 아이디입니다.")
    }

    func testSuccessfulLoginKeepsInMemorySessionWhenTokenPersistenceFails() async {
        let session = AuthSession(
            api: MockAuthAPI(tokenPair: .fixture),
            tokenStore: FailingTokenStore(error: .keychain(errSecInteractionNotAllowed)),
        )

        await session.login(
            id: "collector01",
            password: "password123!",
            deviceId: "ios-primary",
        )

        XCTAssertEqual(session.tokenPair, .fixture)
        XCTAssertEqual(
            session.errorMessage,
            "세션은 시작됐지만 토큰을 기기에 저장하지 못했습니다. (\(errSecInteractionNotAllowed))",
        )
    }
}

private final class MockAuthAPI: AuthAPI, @unchecked Sendable {
    private let tokenPair: TokenPair
    private let error: AuthClientError?
    private(set) var loginInput: (id: String, password: String, deviceId: String)?
    private(set) var signUpInput: (id: String, password: String, deviceId: String)?
    private(set) var refreshInput: String?
    private(set) var logoutRefreshToken: String?

    init(tokenPair: TokenPair = .fixture, error: AuthClientError? = nil) {
        self.tokenPair = tokenPair
        self.error = error
    }

    func login(id: String, password: String, deviceId: String) async throws -> TokenPair {
        loginInput = (id, password, deviceId)
        if let error {
            throw error
        }
        return tokenPair
    }

    func signUp(id: String, password: String, deviceId: String) async throws -> TokenPair {
        signUpInput = (id, password, deviceId)
        if let error {
            throw error
        }
        return tokenPair
    }

    func refresh(refreshToken: String) async throws -> TokenPair {
        refreshInput = refreshToken
        if let error {
            throw error
        }
        return tokenPair
    }

    func logout(refreshToken: String) async throws {
        logoutRefreshToken = refreshToken
        if let error {
            throw error
        }
    }
}

private final class MemoryTokenStore: TokenStore {
    private var tokenPair: TokenPair?

    init(tokenPair: TokenPair? = nil) {
        self.tokenPair = tokenPair
    }

    func load() throws -> TokenPair? {
        tokenPair
    }

    func save(_ tokenPair: TokenPair) throws {
        self.tokenPair = tokenPair
    }

    func clear() throws {
        tokenPair = nil
    }
}

private final class FailingTokenStore: TokenStore {
    private let error: TokenStoreError

    init(error: TokenStoreError) {
        self.error = error
    }

    func load() throws -> TokenPair? {
        nil
    }

    func save(_ tokenPair: TokenPair) throws {
        throw error
    }

    func clear() throws {}
}

private extension TokenPair {
    static let fixture = TokenPair(
        accessToken: "access-token",
        refreshToken: "refresh-token",
        tokenType: "Bearer",
        expiresIn: 900,
    )
}
