import SwiftUI

/// Lauma carrying a message on a screen that has nothing else to show.
///
/// Empty lists and failed loads were an SF Symbol in coral over two lines of text, repeated in four
/// places with the same shape and slightly different spacing. This is that shape with the mascot in
/// place of the glyph, in one component, so the app says these things the same way everywhere.
///
/// # Where this belongs, and where it does not
///
/// She earns a place at a **moment**: an empty list, a load that failed, a permission that was
/// refused. She does not belong on a working screen. In particular she does not go on the palette
/// itself, which is the product, and she does not go on a spinner: most waits in this app resolve
/// in well under a second, and a mascot that flashes for 400ms is noise. A wait has to be long
/// enough to be *felt*, roughly over 1.5 seconds, before she improves it.
///
/// She is a **still** here, never one of the onboarding clips. Those are the first-run moment and
/// cost about 4.5MB each; the drawn poses are already in the bundle, so every notice below is
/// effectively free.
struct LaumaNotice<Actions: View>: View {
    let pose: LaumaPose
    let title: String
    let message: String
    @ViewBuilder var actions: () -> Actions

    /// Smaller than her onboarding sizes. These appear inside sheets and lists, where she is
    /// illustrating a sentence rather than being the subject of the screen.
    private var height: CGFloat { 132 }

    var body: some View {
        VStack(spacing: 10) {
            LaumaStage(pose: pose, height: height)
                .padding(.bottom, 2)

            Text(title)
                .font(BrandFont.ui(17, weight: .bold))
                .multilineTextAlignment(.center)

            Text(message)
                .font(BrandFont.ui(14))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            actions()
                .font(BrandFont.ui(15, weight: .medium))
                .padding(.top, 2)
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        // One label for the whole notice. Read as separate elements it becomes "image, heading,
        // paragraph" with the mascot announced as nothing useful; `LaumaStage` is decorative, so
        // without this the picture is silent and the two strings arrive unrelated.
        .accessibilityElement(children: .contain)
        .accessibilityLabel("\(title). \(message)")
    }
}

extension LaumaNotice where Actions == EmptyView {
    init(pose: LaumaPose, title: String, message: String) {
        self.init(pose: pose, title: title, message: message, actions: { EmptyView() })
    }
}
