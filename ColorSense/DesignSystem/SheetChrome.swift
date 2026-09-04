import SwiftUI

/// Leaving a tool.
///
/// The shared tool workspace is a full screen you go *into* from the palette and come back from, so
/// the control says
/// **Back** and sits on the leading edge with a chevron, which is where a back control belongs on
/// this platform. "Done" was wrong twice over: it sat on the trailing edge in the older tools and
/// the leading edge in the newer ones, and it implies finishing something, when nothing here is
/// submitted and the palette has been saving itself all along.
///
/// This is only for the panels in `ToolWorkspaceView`. Settings screens and nested editors
/// keep Done and Cancel, where those words mean what they say.
struct BackToPalette: ToolbarContent {
    let action: () -> Void

    var body: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            Button(action: action) {
                // An explicit HStack, not a `Label`. A toolbar collapses a Label to its icon alone,
                // which left a bare chevron and none of the word that was the point of the change.
                HStack(spacing: 3) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 15, weight: .semibold))
                    Text("Back")
                }
            }
            .accessibilityLabel("Back to the palette")
        }
    }
}

/// Asks before throwing away work that only exists on this screen.
///
/// Two things together, because either alone leaves a hole. `interactiveDismissDisabled` stops the
/// swipe, which is the accidental gesture; the confirmation covers the deliberate tap on Back. It
/// is applied only where something would actually be lost: a palette edit has already been written
/// to `PaletteStore` by the time you could swipe, so guarding the Visualizer would be friction
/// protecting nothing.
struct ConfirmsDiscard: ViewModifier {
    let hasWork: Bool
    let message: String
    @Binding var isAsking: Bool
    let onDiscard: () -> Void

    func body(content: Content) -> some View {
        content
            .interactiveDismissDisabled(hasWork)
            .confirmationDialog("Discard this?", isPresented: $isAsking, titleVisibility: .visible) {
                Button("Discard", role: .destructive, action: onDiscard)
                Button("Keep working", role: .cancel) { }
            } message: {
                Text(message)
            }
    }
}

extension View {
    func confirmsDiscard(
        hasWork: Bool,
        message: String,
        isAsking: Binding<Bool>,
        onDiscard: @escaping () -> Void
    ) -> some View {
        modifier(ConfirmsDiscard(hasWork: hasWork, message: message, isAsking: isAsking, onDiscard: onDiscard))
    }
}
