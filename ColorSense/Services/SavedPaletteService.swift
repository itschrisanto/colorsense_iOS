import Foundation
import ClerkKit

/// Saves a palette to the user's ColorSense **account**, matching the web app's
/// `POST /api/saved-palettes` (see `artifacts/api-server/src/routes/saved-palettes.ts` and its
/// client in `lib/savedPalettes.ts`). Saving to the *device* is a different action entirely —
/// that is `PaletteExportService.saveToPhotos`.
///
/// This is the only networking in the app besides Clerk itself; the extractor and contrast
/// checker stay fully on-device.
enum SavedPaletteService {
    enum SaveError: LocalizedError {
        case notSignedIn
        case unauthorized
        case rejected(status: Int)
        case offline

        var message: String {
            switch self {
            case .notSignedIn: return "Sign in to save palettes to your account."
            case .unauthorized: return "Your session expired — sign in again."
            case .rejected(let status): return "Couldn't save the palette (\(status))."
            case .offline: return "Couldn't reach ColorSense. Check your connection."
            }
        }

        var errorDescription: String? { message }
    }

    /// The server validates each colour against `/^#[0-9A-Fa-f]{6}$/` and caps a palette at 20,
    /// so send exactly the shape it expects rather than relying on it to normalise.
    private struct SaveRequest: Encodable {
        let name: String
        let colors: [String]
    }

    static func save(_ palette: ExtractedPalette, name: String? = nil) async -> Result<Void, SaveError> {
        // Clerk.shared is actor-isolated, so reading the session has to be awaited.
        guard let session = await Clerk.shared.session else { return .failure(.notSignedIn) }

        let token: String?
        do {
            token = try await session.getToken()
        } catch {
            return .failure(.unauthorized)
        }
        guard let token else { return .failure(.unauthorized) }

        var request = URLRequest(url: AppConfig.apiBaseURL.appendingPathComponent("saved-palettes"))
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body = SaveRequest(
            name: name ?? defaultName(),
            colors: palette.colors.map { $0.hex.uppercased() }
        )
        request.httpBody = try? JSONEncoder().encode(body)

        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse else { return .failure(.rejected(status: 0)) }
            switch http.statusCode {
            case 200..<300: return .success(())
            case 401: return .failure(.unauthorized)
            default: return .failure(.rejected(status: http.statusCode))
            }
        } catch {
            return .failure(.offline)
        }
    }

    /// Mirrors the server's own fallback (`Palette of <date>`) so a palette saved from iOS is
    /// named the same way as one saved from the web.
    private static func defaultName() -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .none
        return "Palette of \(formatter.string(from: Date()))"
    }
}
