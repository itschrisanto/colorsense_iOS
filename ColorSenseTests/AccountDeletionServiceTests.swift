import Foundation
import Testing
@testable import ColorSense

@Suite("Account deletion API contract")
struct AccountDeletionServiceTests {
    private let endpoint = AppConfig.apiBaseURL.appendingPathComponent("account")

    @Test func requestsAppleDeletionChallenge() async {
        let id = UUID()
        let result = await AccountDeletionService.challenge(token: "test-token") { request in
            #expect(request.url == self.endpoint.appendingPathComponent("apple-deletion-challenge"))
            #expect(request.httpMethod == "POST")
            #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer test-token")
            return self.response(
                status: 200,
                body: #"{"appleReauthenticationRequired":true,"challengeId":"\#(id)","nonce":"raw-nonce","expiresAt":"2026-09-12T12:00:00.000Z"}"#,
                url: request.url!
            )
        }
        guard case .success(let challenge?) = result else {
            Issue.record("Expected a complete Apple challenge")
            return
        }
        #expect(challenge.id == id)
        #expect(challenge.nonce == "raw-nonce")
    }

    @Test func nonAppleChallengeNeedsNoReauthentication() async {
        let result = await AccountDeletionService.challenge(token: "test-token") { request in
            self.response(status: 200, body: #"{"appleReauthenticationRequired":false}"#, url: request.url!)
        }
        guard case .success(nil) = result else {
            Issue.record("Expected no Apple challenge")
            return
        }
    }

    @Test func sendsAppleAuthorizationOnlyInRequestBody() async {
        let id = UUID()
        let challenge = AccountDeletionService.AppleChallenge(id: id, nonce: "raw-nonce", expiresAt: .now)
        let authorization = AccountDeletionService.AppleAuthorization(
            challenge: challenge, identityToken: "identity-secret", authorizationCode: "code-secret"
        )
        let result = await AccountDeletionService.delete(token: "test-token", appleAuthorization: authorization) { request in
            #expect(request.value(forHTTPHeaderField: "Content-Type") == "application/json")
            let body = try #require(request.httpBody)
            let json = try #require(JSONSerialization.jsonObject(with: body) as? [String: Any])
            let apple = try #require(json["appleAuthorization"] as? [String: Any])
            #expect(apple["challengeId"] as? String == id.uuidString)
            #expect(apple["nonce"] as? String == "raw-nonce")
            #expect(apple["identityToken"] as? String == "identity-secret")
            #expect(apple["authorizationCode"] as? String == "code-secret")
            return self.response(status: 200, body: #"{"deleted":true}"#)
        }
        guard case .success = result else { Issue.record("Expected deletion success"); return }
    }

    @Test func sendsExplicitManualRevocationAcceptance() async {
        let result = await AccountDeletionService.delete(
            token: "test-token", manualRevocationAccepted: true
        ) { request in
            let body = try #require(request.httpBody)
            let json = try #require(JSONSerialization.jsonObject(with: body) as? [String: Any])
            #expect(json["manualAppleRevocationAccepted"] as? Bool == true)
            #expect(json["appleAuthorization"] == nil)
            return self.response(status: 200, body: #"{"deleted":true}"#)
        }
        guard case .success = result else { Issue.record("Expected manual deletion success"); return }
    }

    @Test func exposesManualFallbackOnlyWhenServerOffersIt() async {
        let result = await AccountDeletionService.delete(token: "test-token") { _ in
            self.response(status: 409, body: #"{"deleted":false,"manualRevocationAvailable":true}"#)
        }
        guard case .failure(.appleReauthenticationUnavailable) = result else {
            Issue.record("Expected the explicit manual fallback")
            return
        }
    }

    @Test func sendsAuthenticatedDeleteAndRequiresExplicitSuccess() async {
        let result = await AccountDeletionService.delete(token: "test-token") { request in
            #expect(request.url == endpoint)
            #expect(request.httpMethod == "DELETE")
            #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer test-token")
            return response(status: 200, body: #"{"deleted":true}"#)
        }

        guard case .success = result else {
            Issue.record("Expected an explicit deleted response to succeed")
            return
        }
    }

    @Test(arguments: [
        (200, #"{"deleted":false}"#, AccountDeletionService.DeleteError.invalidResponse),
        (200, #"{}"#, AccountDeletionService.DeleteError.invalidResponse),
        (401, #"{"error":"Unauthorized"}"#, AccountDeletionService.DeleteError.unauthorized),
        (502, #"{"error":"Identity deletion pending"}"#, AccountDeletionService.DeleteError.identityDeletionPending),
        (503, #"{"error":"Unavailable"}"#, AccountDeletionService.DeleteError.rejected(status: 503)),
    ])
    func mapsServerResponses(
        status: Int,
        body: String,
        expected: AccountDeletionService.DeleteError
    ) async {
        let result = await AccountDeletionService.delete(token: "test-token") { _ in
            response(status: status, body: body)
        }
        guard case .failure(let error) = result else {
            Issue.record("Expected status \(status) to fail")
            return
        }
        #expect(error == expected)
    }

    @Test func mapsTransportFailureWithoutLeakingToken() async {
        struct Offline: Error {}
        let secret = "never-print-this-token"
        let result = await AccountDeletionService.delete(token: secret) { _ in throw Offline() }

        guard case .failure(let error) = result else {
            Issue.record("Expected the transport failure to fail")
            return
        }
        #expect(error == .offline)
        #expect(!error.localizedDescription.contains(secret))
    }

    private func response(
        status: Int,
        body: String,
        url: URL? = nil
    ) -> (Data, URLResponse) {
        let response = HTTPURLResponse(
            url: url ?? endpoint,
            statusCode: status,
            httpVersion: nil,
            headerFields: nil
        )!
        return (Data(body.utf8), response)
    }
}
