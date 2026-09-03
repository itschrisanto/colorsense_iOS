import SwiftUI
import ClerkKit

/// Telling us something, from inside the app.
///
/// Posts to the same `POST /api/feedback` the web form uses, so a message from a phone lands in the
/// same table and fires the same Loops `feedback_received` event that reaches hello@. Nothing here
/// talks to Loops: the API key is server-side and stays there.
///
/// **No account required**, matching the route. Someone whose problem is that they cannot sign in
/// still has to be able to say so. When there *is* a signed-in user the name and email are filled
/// in from it, because retyping what the app already knows is friction for no benefit.
struct FeedbackView: View {
    @Environment(Clerk.self) private var clerk
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var email = ""
    @State private var message = ""
    @State private var isSending = false
    @State private var failure: String?
    @State private var didSend = false
    @FocusState private var messageIsFocused: Bool

    private var problem: String? {
        FeedbackService.validationMessage(name: name, email: email, message: message)
    }

    var body: some View {
        NavigationStack {
            Group {
                if didSend {
                    LaumaNotice(
                        pose: .celebrating,
                        title: "Thank you",
                        message: "That reached us. If it needs an answer, we will reply to \(email.trimmingCharacters(in: .whitespacesAndNewlines))."
                    ) {
                        Button("Done") { dismiss() }
                            .buttonStyle(.primaryAction)
                    }
                } else {
                    form
                }
            }
            .navigationTitle("Feedback")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(didSend ? "Done" : "Cancel") { dismiss() }
                }
            }
        }
        .presentationDetents([.large])
        .onAppear(perform: prefill)
    }

    private var form: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Bugs, requests, or anything that felt wrong. It goes straight to Chris.")
                    .font(BrandFont.ui(14))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                field("Your name", text: $name)
                    .textContentType(.name)
                field("Email", text: $email)
                    .textContentType(.emailAddress)
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()

                VStack(alignment: .leading, spacing: 6) {
                    TextEditor(text: $message)
                        .font(BrandFont.ui(15))
                        .frame(minHeight: 150)
                        .scrollContentBackground(.hidden)
                        .padding(10)
                        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
                        .focused($messageIsFocused)
                        .overlay(alignment: .topLeading) {
                            if message.isEmpty {
                                Text("What's on your mind?")
                                    .font(BrandFont.ui(15))
                                    .foregroundStyle(.tertiary)
                                    .padding(.horizontal, 15)
                                    .padding(.vertical, 18)
                                    .allowsHitTesting(false)
                            }
                        }

                    // The server refuses anything over 2000, so the count is shown rather than the
                    // message being truncated or silently rejected on submit.
                    Text("\(message.trimmingCharacters(in: .whitespacesAndNewlines).count) / 2000")
                        .font(BrandFont.ui(11))
                        .foregroundStyle(message.count > 2000 ? AnyShapeStyle(.red) : AnyShapeStyle(.tertiary))
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }

                if let failure {
                    Text(failure)
                        .font(BrandFont.ui(13))
                        .foregroundStyle(.red)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Button {
                    send()
                } label: {
                    if isSending {
                        ProgressView().tint(.white)
                    } else {
                        Text("Send feedback")
                    }
                }
                .buttonStyle(.primaryAction)
                .disabled(isSending || problem != nil)
                .opacity(problem == nil && !isSending ? 1 : 0.55)

                // Shown rather than enforced silently: a disabled button with no reason is the
                // thing people write support emails about.
                if let problem, !isSending {
                    Text(problem)
                        .font(BrandFont.ui(12))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                }
            }
            .padding(20)
        }
    }

    private func field(_ title: String, text: Binding<String>) -> some View {
        TextField(title, text: text)
            .font(BrandFont.ui(15))
            .padding(12)
            .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
    }

    private func prefill() {
        guard let user = clerk.user else { return }
        if name.isEmpty {
            let parts = [user.firstName, user.lastName].compactMap { $0 }.filter { !$0.isEmpty }
            name = parts.joined(separator: " ")
        }
        if email.isEmpty {
            email = user.primaryEmailAddress?.emailAddress ?? ""
        }
    }

    private func send() {
        failure = nil
        isSending = true
        Task {
            let result = await FeedbackService.send(name: name, email: email, message: message)
            isSending = false
            switch result {
            case .success:
                AnalyticsService.capture(.feedbackSent)
                didSend = true
            case .failure(let error):
                failure = error.message
            }
        }
    }
}
