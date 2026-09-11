import Foundation
import Testing
@testable import ColorSense

@Suite("Account deletion API contract")
struct AccountDeletionServiceTests {
    private let endpoint = AppConfig.apiBaseURL.appendingPathComponent("account")

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

    private func response(status: Int, body: String) -> (Data, URLResponse) {
        let response = HTTPURLResponse(
            url: endpoint,
            statusCode: status,
            httpVersion: nil,
            headerFields: nil
        )!
        return (Data(body.utf8), response)
    }
}
