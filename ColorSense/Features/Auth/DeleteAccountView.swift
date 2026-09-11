import SwiftUI
import ClerkKit

/// Deletes the complete ColorSense account through the server-owned deletion lifecycle.
///
/// This is not only parity — App Store guideline 5.1.1(v) requires an app that lets people create
/// an account to let them delete it from inside the app, not just on a website. So this screen is
/// a submission requirement, not an optional extra.
struct DeleteAccountView: View {
    @Environment(Clerk.self) private var clerk
    @Environment(\.dismiss) private var dismiss

    @State private var isConfirming = false
    @State private var isDeleting = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    VStack(spacing: 12) {
                        Image(systemName: "trash.fill")
                            .font(.system(size: 24, weight: .semibold))
                            .foregroundStyle(.red)
                            .frame(width: 52, height: 52)
                            .background(.red.opacity(0.12), in: Circle())

                        Text("Permanently delete your account")
                            .font(BrandFont.ui(20, weight: .bold))
                            .multilineTextAlignment(.center)

                        Text("This affects ColorSense everywhere, including the web app, and cannot be undone.")
                            .font(BrandFont.ui(14))
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: .infinity)

                    VStack(alignment: .leading, spacing: 10) {
                        Label("Your profile, saved palettes, linked feature data and sign-in identity will be removed.", systemImage: "checkmark.circle")

                        Label("Some billing, security and independently subscribed mailing records may be retained where needed.", systemImage: "archivebox")
                    }
                    .font(BrandFont.ui(14))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(16)
                    .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 16))

                    Text("Deleting your account does not cancel an active Apple or website subscription. Cancel it separately first if you want future billing to stop.")
                        .font(BrandFont.ui(14, weight: .medium))
                        .fixedSize(horizontal: false, vertical: true)

                    Link(
                        "Manage Apple subscriptions",
                        destination: URL(string: "https://apps.apple.com/account/subscriptions")!
                    )
                    .font(BrandFont.ui(14, weight: .medium))

                    if let errorMessage {
                        Text(errorMessage)
                            .font(BrandFont.ui(14))
                            .foregroundStyle(.red)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Button(role: .destructive) {
                        isConfirming = true
                    } label: {
                        HStack {
                            if isDeleting { ProgressView().tint(.white) }
                            Text(isDeleting ? "Deleting\u{2026}" : "Delete my account")
                                .font(BrandFont.ui(16, weight: .medium))
                        }
                    }
                    .buttonStyle(.primaryAction(tint: .red))
                    .disabled(isDeleting)
                }
                .padding(20)
            }
            .navigationTitle("Delete account")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() } }
            }
            .alert(
                "Delete your ColorSense account?",
                isPresented: $isConfirming
            ) {
                Button("Delete account", role: .destructive) { Task { await deleteAccount() } }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Your ColorSense account and saved content will be permanently removed. Active subscriptions must be canceled separately.")
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func deleteAccount() async {
        guard clerk.user != nil else {
            errorMessage = AccountDeletionService.DeleteError.notSignedIn.localizedDescription
            return
        }
        isDeleting = true
        errorMessage = nil

        switch await AccountDeletionService.delete() {
        case .success:
            // No account-scoped model is persisted by the native app. Clear HTTP responses that
            // could contain account data, then ask Clerk to discard the now-deleted session.
            URLCache.shared.removeAllCachedResponses()
            do {
                try await clerk.auth.signOut()
            } catch {
                // The backend has already deleted the Clerk identity, so Clerk's sign-out request
                // can race that deletion. Refreshing the client reconciles the local identity
                // without attempting a second, client-side user deletion.
                _ = try? await clerk.refreshClient()
            }
            if clerk.user == nil {
                dismiss()
            } else {
                errorMessage = "Your account was deleted, but this device couldn't finish signing out. Try again or restart the app."
                isDeleting = false
            }
        case .failure(let error):
            errorMessage = error.localizedDescription
            isDeleting = false
        }
    }
}
