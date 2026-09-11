import Foundation
import ClerkKit

/// Deletes the signed-in ColorSense account through the server-owned lifecycle.
enum AccountDeletionService {
    struct AppleChallenge: Equatable {
        let id: UUID
        let nonce: String
        let expiresAt: Date
    }

    struct AppleAuthorization {
        let challenge: AppleChallenge
        let identityToken: String
        let authorizationCode: String
    }

    enum DeleteError: LocalizedError, Equatable {
        case notSignedIn, unauthorized, identityDeletionPending, appleReauthenticationUnavailable
        case rejected(status: Int)
        case invalidResponse, offline

        var errorDescription: String? {
            switch self {
            case .notSignedIn, .unauthorized: "Your session expired. Sign in again before retrying account deletion."
            case .identityDeletionPending: "ColorSense removed your local account data, but could not finish deleting your sign-in identity. Please try again."
            case .appleReauthenticationUnavailable: "ColorSense couldn't revoke Sign in with Apple automatically."
            case .rejected: "ColorSense couldn't delete your account. Please try again."
            case .invalidResponse: "ColorSense returned an invalid response. Your account has not been reported as deleted."
            case .offline: "Couldn't reach ColorSense. Check your connection and try again."
            }
        }
    }

    private struct DeleteResponse: Decodable {
        let deleted: Bool?
        let manualRevocationAvailable: Bool?
    }

    private struct ChallengeResponse: Decodable {
        let appleReauthenticationRequired: Bool
        let challengeId: UUID?
        let nonce: String?
        let expiresAt: Date?
    }

    private struct DeleteRequest: Encodable {
        struct Authorization: Encodable {
            let challengeId: UUID
            let nonce, identityToken, authorizationCode: String
        }
        let appleAuthorization: Authorization?
        let manualAppleRevocationAccepted: Bool?
    }

    typealias DataLoader = (URLRequest) async throws -> (Data, URLResponse)

    static func challenge() async -> Result<AppleChallenge?, DeleteError> {
        guard let token = await sessionToken() else { return .failure(.unauthorized) }
        return await challenge(token: token) { try await URLSession.shared.data(for: $0) }
    }

    static func delete() async -> Result<Void, DeleteError> {
        guard let token = await sessionToken() else { return .failure(.unauthorized) }
        return await delete(token: token) { try await URLSession.shared.data(for: $0) }
    }

    static func delete(appleAuthorization: AppleAuthorization) async -> Result<Void, DeleteError> {
        guard let token = await sessionToken() else { return .failure(.unauthorized) }
        return await delete(token: token, appleAuthorization: appleAuthorization) {
            try await URLSession.shared.data(for: $0)
        }
    }

    static func deleteWithManualAppleRevocation() async -> Result<Void, DeleteError> {
        guard let token = await sessionToken() else { return .failure(.unauthorized) }
        return await delete(token: token, manualRevocationAccepted: true) {
            try await URLSession.shared.data(for: $0)
        }
    }

    private static func sessionToken() async -> String? {
        guard let session = await Clerk.shared.session else { return nil }
        return try? await session.getToken()
    }

    static func challenge(token: String, dataLoader: DataLoader) async -> Result<AppleChallenge?, DeleteError> {
        var request = URLRequest(url: AppConfig.apiBaseURL.appendingPathComponent("account/apple-deletion-challenge"))
        request.httpMethod = "POST"
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        do {
            let (data, response) = try await dataLoader(request)
            guard let http = response as? HTTPURLResponse else { return .failure(.invalidResponse) }
            guard http.statusCode == 200 else {
                return .failure(http.statusCode == 401 ? .unauthorized : .rejected(status: http.statusCode))
            }
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .custom { decoder in
                let value = try decoder.singleValueContainer().decode(String.self)
                let fractional = ISO8601DateFormatter()
                fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                if let date = fractional.date(from: value) { return date }
                let standard = ISO8601DateFormatter()
                standard.formatOptions = [.withInternetDateTime]
                guard let date = standard.date(from: value) else {
                    throw DecodingError.dataCorruptedError(
                        in: try decoder.singleValueContainer(),
                        debugDescription: "Invalid ISO 8601 timestamp"
                    )
                }
                return date
            }
            guard let response = try? decoder.decode(ChallengeResponse.self, from: data) else {
                return .failure(.invalidResponse)
            }
            guard response.appleReauthenticationRequired else { return .success(nil) }
            guard let id = response.challengeId, let nonce = response.nonce, !nonce.isEmpty,
                  let expiresAt = response.expiresAt else { return .failure(.invalidResponse) }
            return .success(.init(id: id, nonce: nonce, expiresAt: expiresAt))
        } catch { return .failure(.offline) }
    }

    static func delete(
        token: String,
        appleAuthorization: AppleAuthorization? = nil,
        manualRevocationAccepted: Bool = false,
        dataLoader: DataLoader
    ) async -> Result<Void, DeleteError> {
        var request = URLRequest(url: AppConfig.apiBaseURL.appendingPathComponent("account"))
        request.httpMethod = "DELETE"
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        if appleAuthorization != nil || manualRevocationAccepted {
            let body = DeleteRequest(
                appleAuthorization: appleAuthorization.map {
                    .init(challengeId: $0.challenge.id, nonce: $0.challenge.nonce,
                          identityToken: $0.identityToken, authorizationCode: $0.authorizationCode)
                },
                manualAppleRevocationAccepted: manualRevocationAccepted ? true : nil
            )
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            guard let data = try? JSONEncoder().encode(body) else { return .failure(.invalidResponse) }
            request.httpBody = data
        }
        do {
            let (data, response) = try await dataLoader(request)
            guard let http = response as? HTTPURLResponse else { return .failure(.invalidResponse) }
            let decoded = try? JSONDecoder().decode(DeleteResponse.self, from: data)
            switch http.statusCode {
            case 200 where decoded?.deleted == true: return .success(())
            case 200: return .failure(.invalidResponse)
            case 401: return .failure(.unauthorized)
            case 502: return .failure(.identityDeletionPending)
            case _ where decoded?.manualRevocationAvailable == true:
                return .failure(.appleReauthenticationUnavailable)
            default: return .failure(.rejected(status: http.statusCode))
            }
        } catch { return .failure(.offline) }
    }
}
