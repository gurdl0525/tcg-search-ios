import Foundation
import XCTest
@testable import TCGSearchCore

final class AuthClientTests: XCTestCase {
    func testLoginPostsBackendContractAndDecodesTokenPair() async throws {
        let transport = MockHTTPTransport(
            statusCode: 200,
            body: Self.tokenResponseJSON,
        )
        let client = AuthClient(
            baseURL: URL(string: "http://localhost:8080")!,
            transport: transport,
        )

        let tokenPair = try await client.login(
            id: "collector01",
            password: "password123!",
            deviceId: "ios-primary",
        )

        XCTAssertEqual(tokenPair.accessToken, "access-token")
        XCTAssertEqual(tokenPair.refreshToken, "refresh-token")
        XCTAssertEqual(tokenPair.tokenType, "Bearer")
        XCTAssertEqual(tokenPair.expiresIn, 900)

        let request = try XCTUnwrap(transport.requests.first)
        XCTAssertEqual(request.httpMethod, "POST")
        XCTAssertEqual(request.url?.path, "/api/auth/login")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Content-Type"), "application/json")

        let payload = try decodedBody(from: request)
        XCTAssertEqual(payload["id"] as? String, "collector01")
        XCTAssertEqual(payload["password"] as? String, "password123!")
        XCTAssertEqual(payload["device_id"] as? String, "ios-primary")
    }

    func testSignUpAcceptsCreatedTokenResponse() async throws {
        let transport = MockHTTPTransport(
            statusCode: 201,
            body: Self.tokenResponseJSON,
        )
        let client = AuthClient(
            baseURL: URL(string: "http://localhost:8080")!,
            transport: transport,
        )

        let tokenPair = try await client.signUp(
            id: "collector01",
            password: "password123!",
            deviceId: "ios-primary",
        )

        XCTAssertEqual(tokenPair.refreshToken, "refresh-token")
        let request = try XCTUnwrap(transport.requests.first)
        XCTAssertEqual(request.url?.path, "/api/auth/signup")

        let payload = try decodedBody(from: request)
        XCTAssertEqual(payload["id"] as? String, "collector01")
        XCTAssertEqual(payload["password"] as? String, "password123!")
        XCTAssertEqual(payload["device_id"] as? String, "ios-primary")
    }

    func testRefreshPostsRefreshTokenAndDecodesRotatedPair() async throws {
        let transport = MockHTTPTransport(
            statusCode: 200,
            body: Self.tokenResponseJSON,
        )
        let client = AuthClient(
            baseURL: URL(string: "http://localhost:8080")!,
            transport: transport,
        )

        let tokenPair = try await client.refresh(refreshToken: "old-refresh-token")

        XCTAssertEqual(tokenPair.accessToken, "access-token")
        let request = try XCTUnwrap(transport.requests.first)
        XCTAssertEqual(request.url?.path, "/api/auth/refresh")

        let payload = try decodedBody(from: request)
        XCTAssertEqual(payload["refresh_token"] as? String, "old-refresh-token")
    }

    func testLogoutAcceptsNoContentResponse() async throws {
        let transport = MockHTTPTransport(statusCode: 204, body: Data())
        let client = AuthClient(
            baseURL: URL(string: "http://localhost:8080")!,
            transport: transport,
        )

        try await client.logout(refreshToken: "refresh-token")

        let request = try XCTUnwrap(transport.requests.first)
        XCTAssertEqual(request.url?.path, "/api/auth/logout")

        let payload = try decodedBody(from: request)
        XCTAssertEqual(payload["refresh_token"] as? String, "refresh-token")
    }

    func testUnexpectedStatusThrowsHTTPStatus() async throws {
        let transport = MockHTTPTransport(
            statusCode: 401,
            body: Data(#"{"code":"INVALID_LOGIN_CREDENTIALS"}"#.utf8),
        )
        let client = AuthClient(
            baseURL: URL(string: "http://localhost:8080")!,
            transport: transport,
        )

        do {
            _ = try await client.login(
                id: "collector01",
                password: "wrong-password",
                deviceId: "ios-primary",
            )
            XCTFail("Expected login to throw")
        } catch let error as AuthClientError {
            XCTAssertEqual(error, .httpStatus(401))
        }
    }

    private func decodedBody(from request: URLRequest) throws -> [String: Any] {
        let body = try XCTUnwrap(request.httpBody)
        return try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: Any])
    }

    private static let tokenResponseJSON = Data(
        """
        {
          "access_token": "access-token",
          "refresh_token": "refresh-token",
          "token_type": "Bearer",
          "expires_in": 900
        }
        """.utf8,
    )
}

private final class MockHTTPTransport: HTTPTransport, @unchecked Sendable {
    private let statusCode: Int
    private let body: Data
    private(set) var requests: [URLRequest] = []

    init(statusCode: Int, body: Data) {
        self.statusCode = statusCode
        self.body = body
    }

    func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        requests.append(request)
        let response = HTTPURLResponse(
            url: request.url!,
            statusCode: statusCode,
            httpVersion: nil,
            headerFields: nil,
        )!

        return (body, response)
    }
}
