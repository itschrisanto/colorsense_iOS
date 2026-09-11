import Foundation
import ClerkKit

/// Deletes the signed-in ColorSense account through the server-owned lifecycle.
///
/// The backend removes and tombstones ColorSense data before deleting the Clerk identity. The
/// client must never call Clerk's `user.delete()` itself: doing so would bypass that cleanup and
/// could leave saved content or purchase ownership behind.
enum AccountDeletionService {
    enum DeleteError: LocalizedError, Equatable {
        case notSignedIn
        case unauthorized
        case identityDeletionPending
        case rejected(status: Int)
        case invalidResponse
        case offline

        var errorDescription: String? {
            switch self {
            case .notSignedIn, .unauthorized:
                return "Your session expired. Sign in again before retrying account deletion."
            case .identityDeletionPending:
                return "ColorSense removed your local account data, but could not finish deleting your sign-in identity. Please try again."
            case .rejected:
                return "ColorSense couldn't delete your account. Please try again."
            case .invalidResponse:
                return "ColorSense returned an invalid response. Your account has not been reported as deleted."
            case .offline:
                return "Couldn't reach ColorSense. Check your connection and try again."
            }
        }

    }

    private struct DeleteResponse: Decodable {
        let deleted: Bool
    }

    typealias DataLoader = (URLRequest) async throws -> (Data, URLResponse)

    static func delete() async -> Result<Void, DeleteError> {
        guard let session = await Clerk.shared.session else { return .failure(.notSignedIn) }

        let token: String?
        do {
            token = try await session.getToken()
        } catch {
            return .failure(.unauthorized)
        }

        guard let token else { return .failure(.unauthorized) }
        return await delete(token: token) { request in
            try await URLSession.shared.data(for: request)
        }
    }

    /// Internal seam for deterministic status, response and transport tests. The bearer token is
    /// attached only to the request and is never logged or included in an error.
    static func delete(
        token: String,
        dataLoader: DataLoader
    ) async -> Result<Void, DeleteError> {
        var request = URLRequest(url: AppConfig.apiBaseURL.appendingPathComponent("account"))
        request.httpMethod = "DELETE"
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        do {
            let (data, response) = try await dataLoader(request)
            guard let http = response as? HTTPURLResponse else {
                return .failure(.invalidResponse)
            }

            switch http.statusCode {
            case 200:
                guard
                    let response = try? JSONDecoder().decode(DeleteResponse.self, from: data),
                    response.deleted
                else { return .failure(.invalidResponse) }
                return .success(())
            case 401:
                return .failure(.unauthorized)
            case 502:
                // The backend may already have removed and tombstoned local data. Retain the
                // Clerk session so the same idempotent endpoint can finish identity deletion.
                return .failure(.identityDeletionPending)
            default:
                return .failure(.rejected(status: http.statusCode))
            }
        } catch {
            return .failure(.offline)
        }
    }
}
