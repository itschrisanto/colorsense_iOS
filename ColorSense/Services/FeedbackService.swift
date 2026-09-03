import Foundation

/// Sending feedback to `POST /api/feedback`, the same endpoint the web app's form uses.
///
/// **Unauthenticated on purpose.** That route carries no `requireAuth`, and it should not: somebody
/// whose problem *is* that they cannot sign in has to be able to tell us so. Every other call in
/// this app goes through `SavedPaletteService.authorizedRequest`, which bails without a session, so
/// this deliberately does not.
///
/// **The `website` honeypot field is never sent.** The server treats any value in it as a bot and
/// silently accepts without recording, so a native form must simply not have it. This is written
/// down because "add the missing field" is exactly the wrong instinct if anyone reads the API later.
///
/// Delivery is the server's business: it writes the row and fires the Loops `feedback_received`
/// event, which is what reaches hello@. The Loops API key is server-side and must stay there, so
/// nothing in this app talks to Loops directly.
enum FeedbackService {

    enum SendError: LocalizedError, Equatable {
        /// The server's own validation message, shown as written rather than reworded, so the app
        /// cannot disagree with the service about what is wrong.
        case rejected(String)
        case offline

        var message: String {
            switch self {
            case .rejected(let reason): return reason
            case .offline: return "Couldn't reach ColorSense. Check your connection."
            }
        }
    }

    /// Mirrors the server's validation so the button can be gated before a round trip. These bounds
    /// are the route's, not invented: name at least 2 characters, a plausible email, and a message
    /// between 10 and 2000.
    static func validationMessage(name: String, email: String, message: String) -> String? {
        let name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let email = email.trimmingCharacters(in: .whitespacesAndNewlines)
        let body = message.trimmingCharacters(in: .whitespacesAndNewlines)

        if name.count < 2 { return "Please enter your name." }
        if !isPlausibleEmail(email) { return "Please enter a valid email address." }
        if body.count < 10 { return "Message must be at least 10 characters." }
        if body.count > 2000 { return "Message must be 2000 characters or fewer." }
        return nil
    }

    /// The server's own pattern, kept identical rather than improved: a stricter check here would
    /// reject addresses the service is willing to accept.
    static func isPlausibleEmail(_ value: String) -> Bool {
        let parts = value.split(separator: "@", omittingEmptySubsequences: false)
        guard parts.count == 2,
              !parts[0].isEmpty, !parts[1].isEmpty,
              !parts[0].contains(" "), !parts[1].contains(" "),
              parts[1].contains(".")
        else { return false }
        return !parts[1].hasPrefix(".") && !parts[1].hasSuffix(".")
    }

    private struct Body: Encodable {
        let name: String
        let email: String
        let message: String
    }

    private struct Reply: Decodable {
        let success: Bool
        let error: String?
    }

    static func send(name: String, email: String, message: String) async -> Result<Void, SendError> {
        var request = URLRequest(url: AppConfig.apiBaseURL.appendingPathComponent("feedback"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONEncoder().encode(
            Body(
                name: name.trimmingCharacters(in: .whitespacesAndNewlines),
                email: email.trimmingCharacters(in: .whitespacesAndNewlines),
                message: message.trimmingCharacters(in: .whitespacesAndNewlines)
            )
        )

        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            let reply = try? JSONDecoder().decode(Reply.self, from: data)
            if reply?.success == true { return .success(()) }
            // The route answers 400 for validation and 429 for rate limiting, both with a written
            // reason. Passing it through beats guessing from the status code.
            return .failure(.rejected(reply?.error ?? "Something went wrong. Please try again."))
        } catch {
            return .failure(.offline)
        }
    }
}
