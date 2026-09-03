import SwiftUI

/// Lauma's poses, as delivered in the mascot kit.
///
/// Every file was cut out of its white plate by flood-filling inward from the border rather than
/// keying on white, because her eye whites sample at the same 254 to 255 as the paper and a global
/// key punched holes through them. Each sprite is then trimmed to its alpha bounding box, so the
/// bottom of the frame is the bottom of her hooves.
enum LaumaPose: String, Equatable, CaseIterable {
    case welcome = "LaumaWelcome"
    case guiding = "LaumaGuide"
    case walking = "LaumaWalk"
    case celebrating = "LaumaCelebrate"
    case happy = "LaumaHappy"
    case standing = "LaumaStanding"
    case curious = "LaumaCurious"
    case delighted = "LaumaDelighted"
    case surprised = "LaumaSurprised"
    case unsure = "LaumaUnsure"
    case sad = "LaumaSad"

    /// Width over height of the trimmed sprite, read from each PNG header. `LaumaStage` pins the
    /// frame to this so the eyelid overlay lands on the art rather than on the letterboxing
    /// `scaledToFit` would otherwise leave inside a height-only frame.
    var aspect: CGFloat {
        switch self {
        case .welcome: return 0.6939
        case .guiding: return 0.7341
        case .walking: return 0.6159
        case .celebrating: return 0.6915
        case .happy: return 0.6171
        case .standing: return 0.6256
        case .curious: return 0.6780
        case .delighted: return 0.6634
        case .surprised: return 0.5451
        case .unsure: return 0.6098
        case .sad: return 0.7829
        }
    }

}

/// Lauma on screen: the drawn pose, a slow breath, and a soft drop shadow for depth.
///
/// The pose carries the expression, so there is no transform-based acting here beyond the breath,
/// which exists so she never reads as a frozen sticker. The shadow is taken after
/// `compositingGroup()` so the figure casts one silhouette rather than each layer casting its own,
/// and its radius and offset scale with `height` so a 300pt Lauma and a 130pt one sit the same
/// distance off the surface.
///
/// **There is no blink**, and that is deliberate rather than an omission. Two implementations were
/// tried and both looked wrong: fur-coloured lids drawn over the measured eye boxes read as flat
/// stamps against the art's paper texture, and lids baked into a patch from neighbouring pixels
/// left ghost outlines where the sclera had been. A convincing blink needs closed-eye art for each
/// pose, which the mascot kit does not yet include.
struct LaumaStage: View {
    let pose: LaumaPose
    let height: CGFloat
    var flipped: Bool = false

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var breathing = false

    var body: some View {
        ZStack(alignment: .bottom) {
            groundShadow

            // `decorative:` rather than `Image(_:)`: a plain Image adopts its asset name as an
            // accessibility label, which put the literal string "LaumaPrototype" into the tree.
            Image(decorative: pose.rawValue)
                .resizable()
                .scaledToFit()
                .frame(width: height * pose.aspect, height: height)
                .scaleEffect(y: breathing && !reduceMotion ? 1.015 : 0.993, anchor: .bottom)
                .id(pose)
                .transition(.opacity)
                .scaleEffect(x: flipped ? -1 : 1)
        }
        .animation(.easeInOut(duration: 0.28), value: pose)
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 2.1).repeatForever(autoreverses: true)) {
                breathing = true
            }
        }
    }

    /// The shadow she casts on the ground, not a copy of her silhouette offset behind her.
    ///
    /// A `.shadow()` on the sprite traces its outline, which is what makes a flat character read as
    /// a sticker laid on the surface: a second Lauma, in grey, peeking out from behind the first.
    /// A standing figure lit from the front doesn't do that. It puts a pool on the floor under
    /// itself, densest where the hooves meet the ground and dissolving outward.
    ///
    /// So this is an ellipse at her feet, not a silhouette: a radial gradient so the centre is
    /// dark and the rim vanishes, and `.multiply` rather than a grey fill so it *darkens the band
    /// it lands on* instead of laying neutral grey over it. That is the difference between a
    /// shadow on CORAL looking like deeper coral and looking like dirt.
    private var groundShadow: some View {
        Ellipse()
            .fill(
                RadialGradient(
                    colors: [.black.opacity(0.34), .black.opacity(0.16), .clear],
                    center: .center,
                    startRadius: 0,
                    endRadius: height * 0.32
                )
            )
            .frame(width: height * 0.64, height: height * 0.115)
            .blur(radius: height * 0.022)
            .blendMode(.multiply)
            // Tucked up so the pool starts under the hooves rather than trailing below them.
            .offset(y: -height * 0.008)
    }
}
