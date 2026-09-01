import SwiftUI
import ClerkKit

/// Deletes the Clerk user, mirroring the web app's `user.delete()` in Account.tsx.
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
                VStack(alignment: .leading, spacing: 16) {
                    Text("Deleting your account removes your saved palettes and profile from ColorSense. This can't be undone, and it applies everywhere — the web app too.")
                        .font(BrandFont.ui(15))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)

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
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 15)
                        .background(.red)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                    .buttonStyle(.plain)
                    .disabled(isDeleting)
                }
                .padding(20)
            }
            .navigationTitle("Delete account")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() } }
            }
            .confirmationDialog(
                "Delete your ColorSense account?",
                isPresented: $isConfirming,
                titleVisibility: .visible
            ) {
                Button("Delete account", role: .destructive) { Task { await deleteAccount() } }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Your saved palettes and profile will be permanently removed.")
            }
        }
    }

    private func deleteAccount() async {
        guard let user = clerk.user else { return }
        isDeleting = true
        errorMessage = nil
        do {
            try await user.delete()
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
            isDeleting = false
        }
    }
}
