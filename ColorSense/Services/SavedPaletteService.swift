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

    /// One row of `GET /saved-palettes`, matching the `SavedPalette` interface in the web
    /// client's lib/savedPalettes.ts.
    struct SavedPalette: Identifiable, Decodable, Equatable {
        let id: Int
        let name: String
        let colors: [String]
        let createdAt: String

        /// The stored hexes as palette swatches. Dominance is not persisted server-side — the
        /// web app stores colours only — so an even split is the honest reconstruction.
        var paletteColors: [PaletteColor] {
            let share = colors.isEmpty ? 0 : 1.0 / Double(colors.count)
            return colors.compactMap { hex in
                guard let value = UInt32(hex.replacingOccurrences(of: "#", with: ""), radix: 16)
                else { return nil }
                return PaletteColor(hex: value, dominance: share)
            }
        }

        var asExtractedPalette: ExtractedPalette {
            ExtractedPalette(colors: paletteColors, createdAt: Date())
        }
    }

    private struct ListResponse: Decodable {
        let palettes: [SavedPalette]
    }

    /// Fetches the signed-in user's saved palettes — the same list the web app's Library shows.
    static func list() async -> Result<[SavedPalette], SaveError> {
        await authorizedRequest(path: "saved-palettes", method: "GET") { data in
            (try? JSONDecoder().decode(ListResponse.self, from: data))?.palettes ?? []
        }
    }

    static func delete(id: Int) async -> Result<Void, SaveError> {
        await authorizedRequest(path: "saved-palettes/\(id)", method: "DELETE") { _ in () }
    }

    private struct MeResponse: Decodable {
        struct User: Decodable { let plan: String? }
        let user: User
    }

    /// The signed-in user's effective plan from `GET /api/me`. The server recomputes this per
    /// request so trial and voucher Pro grants lapse without a cron job — don't cache it.
    static func currentPlan() async -> Result<String?, SaveError> {
        await authorizedRequest(path: "me", method: "GET") { data in
            (try? JSONDecoder().decode(MeResponse.self, from: data))?.user.plan
        }
    }

    /// Shared token-fetch, request and status handling for the saved-palette endpoints.
    private static func authorizedRequest<T>(
        path: String,
        method: String,
        body: Data? = nil,
        decode: @escaping (Data) -> T
    ) async -> Result<T, SaveError> {
        // Clerk.shared is actor-isolated, so reading the session has to be awaited.
        guard let session = await Clerk.shared.session else { return .failure(.notSignedIn) }

        let token: String?
        do {
            token = try await session.getToken()
        } catch {
            return .failure(.unauthorized)
        }
        guard let token else { return .failure(.unauthorized) }

        var request = URLRequest(url: AppConfig.apiBaseURL.appendingPathComponent(path))
        request.httpMethod = method
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        if let body {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = body
        }

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse else { return .failure(.rejected(status: 0)) }
            switch http.statusCode {
            case 200..<300: return .success(decode(data))
            case 401: return .failure(.unauthorized)
            default: return .failure(.rejected(status: http.statusCode))
            }
        } catch {
            return .failure(.offline)
        }
    }

    static func save(_ palette: ExtractedPalette, name: String? = nil) async -> Result<Void, SaveError> {
        let body = SaveRequest(
            name: name ?? defaultName(),
            colors: palette.colors.map { $0.hex.uppercased() }
        )
        return await authorizedRequest(
            path: "saved-palettes",
            method: "POST",
            body: try? JSONEncoder().encode(body)
        ) { _ in () }
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
