import SwiftUI
import ClerkKit
import AuthenticationServices
import CryptoKit

struct DeleteAccountView: View {
    @Environment(Clerk.self) private var clerk
    @Environment(\.dismiss) private var dismiss
    @State private var isConfirming = false
    @State private var isDeleting = false
    @State private var errorMessage: String?
    @State private var appleChallenge: AccountDeletionService.AppleChallenge?
    @State private var isOfferingManualRevocation = false
    @State private var manualRevocationInstructions = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    header
                    consequences
                    Text("Deleting your account does not cancel an active Apple or website subscription. Cancel it separately first if you want future billing to stop.")
                        .font(BrandFont.ui(14, weight: .medium)).fixedSize(horizontal: false, vertical: true)
                    Link("Manage Apple subscriptions", destination: URL(string: "https://apps.apple.com/account/subscriptions")!)
                        .font(BrandFont.ui(14, weight: .medium))
                    if let errorMessage {
                        Text(errorMessage).font(BrandFont.ui(14)).foregroundStyle(.red)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    if let appleChallenge { appleConfirmation(for: appleChallenge) }
                    Button(role: .destructive) { isConfirming = true } label: {
                        HStack {
                            if isDeleting { ProgressView().tint(.white) }
                            Text(isDeleting ? "Deleting…" : "Delete my account")
                                .font(BrandFont.ui(16, weight: .medium))
                        }
                    }
                    .buttonStyle(.primaryAction(tint: .red))
                    .disabled(isDeleting || appleChallenge != nil)
                }
                .padding(20)
            }
            .navigationTitle("Delete account").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() } } }
            .alert("Delete your ColorSense account?", isPresented: $isConfirming) {
                Button("Delete account", role: .destructive) { Task { await beginDeletion() } }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Your ColorSense account and saved content will be permanently removed. Active subscriptions must be canceled separately.")
            }
            .alert("Apple revocation unavailable", isPresented: $isOfferingManualRevocation) {
                Button("Retry Apple confirmation") { appleChallenge = nil; Task { await beginDeletion() } }
                Button("Delete and revoke manually", role: .destructive) { Task { await deleteManually() } }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("You can retry automatic revocation, keep your account, or delete it now and then revoke ColorSense in Apple Settings.")
            }
            .alert("Finish revoking Apple access", isPresented: $manualRevocationInstructions) {
                Button("OK") { Task { await finishDeletion() } }
            } message: {
                Text("Open Settings, tap your name, tap Sign in with Apple, select ColorSense, then tap Delete.")
            }
        }
        .presentationDetents([.medium, .large])
    }

    private var header: some View {
        VStack(spacing: 12) {
            Image(systemName: "trash.fill").font(.system(size: 24, weight: .semibold))
                .foregroundStyle(.red).frame(width: 52, height: 52)
                .background(.red.opacity(0.12), in: Circle())
            Text("Permanently delete your account").font(BrandFont.ui(20, weight: .bold))
            Text("This affects ColorSense everywhere, including the web app, and cannot be undone.")
                .font(BrandFont.ui(14)).foregroundStyle(.secondary)
                .multilineTextAlignment(.center).fixedSize(horizontal: false, vertical: true)
        }.frame(maxWidth: .infinity)
    }

    private var consequences: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Your profile, saved palettes, linked feature data and sign-in identity will be removed.", systemImage: "checkmark.circle")
            Label("Some billing, security and independently subscribed mailing records may be retained where needed.", systemImage: "archivebox")
        }
        .font(BrandFont.ui(14)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
        .padding(16).background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 16))
    }

    private func appleConfirmation(for challenge: AccountDeletionService.AppleChallenge) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Confirm with Apple").font(BrandFont.ui(16, weight: .bold))
            Text("Apple requires one final confirmation so ColorSense can revoke your Apple sign-in before deleting the account.")
                .font(BrandFont.ui(14)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            SignInWithAppleButton(.continue) { request in
                request.nonce = SHA256.hash(data: Data(challenge.nonce.utf8))
                    .map { String(format: "%02x", $0) }.joined()
            } onCompletion: { handleAppleAuthorization($0, challenge: challenge) }
            .signInWithAppleButtonStyle(.black).frame(height: 50).disabled(isDeleting)
            .accessibilityLabel("Confirm account deletion with Apple")
        }
        .padding(16).background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 16))
    }

    private func beginDeletion() async {
        guard clerk.user != nil else { show(.notSignedIn); return }
        isDeleting = true
        errorMessage = nil
        switch await AccountDeletionService.challenge() {
        case .success(let challenge):
            if let challenge { appleChallenge = challenge; isDeleting = false }
            else { await performDeletion(await AccountDeletionService.delete()) }
        case .failure(let error): show(error)
        }
    }

    private func handleAppleAuthorization(_ result: Result<ASAuthorization, Error>, challenge: AccountDeletionService.AppleChallenge) {
        switch result {
        case .success(let authorization):
            guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
                  let identityData = credential.identityToken, let codeData = credential.authorizationCode,
                  let identityToken = String(data: identityData, encoding: .utf8),
                  let authorizationCode = String(data: codeData, encoding: .utf8) else {
                errorMessage = "Apple did not return the credentials needed to revoke access. Please try again."
                return
            }
            isDeleting = true
            errorMessage = nil
            Task {
                let value = AccountDeletionService.AppleAuthorization(
                    challenge: challenge, identityToken: identityToken, authorizationCode: authorizationCode
                )
                await performDeletion(await AccountDeletionService.delete(appleAuthorization: value))
            }
        case .failure(let error):
            if (error as? ASAuthorizationError)?.code != .canceled {
                errorMessage = "Apple couldn't confirm account deletion. Please try again."
            }
        }
    }

    private func deleteManually() async {
        isDeleting = true
        errorMessage = nil
        switch await AccountDeletionService.deleteWithManualAppleRevocation() {
        case .success: appleChallenge = nil; isDeleting = false; manualRevocationInstructions = true
        case .failure(let error): show(error)
        }
    }

    private func performDeletion(_ result: Result<Void, AccountDeletionService.DeleteError>) async {
        switch result {
        case .success: appleChallenge = nil; await finishDeletion()
        case .failure(.appleReauthenticationUnavailable): isDeleting = false; isOfferingManualRevocation = true
        case .failure(let error): show(error)
        }
    }

    private func finishDeletion() async {
        URLCache.shared.removeAllCachedResponses()
        do { try await clerk.auth.signOut() } catch { _ = try? await clerk.refreshClient() }
        if clerk.user == nil { dismiss() }
        else {
            errorMessage = "Your account was deleted, but this device couldn't finish signing out. Try again or restart the app."
            isDeleting = false
        }
    }

    private func show(_ error: AccountDeletionService.DeleteError) {
        errorMessage = error.localizedDescription
        isDeleting = false
    }
}
