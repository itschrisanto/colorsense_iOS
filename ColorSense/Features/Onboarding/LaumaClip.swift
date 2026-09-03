import SwiftUI

/// Lauma as an animation rather than a drawn pose.
///
/// The clips come from generated video Chris supplied, cut to 30 PNG frames each by the extractor
/// described in CLAUDE.md. Two things always have to be dealt with, and they are the same every
/// time: a burned-in "KlingAI 3.0" watermark, and a solid white plate instead of alpha.
///
/// The watermark is found as **the part of the picture that never changes** (it is burned in, so
/// it is present in every frame in the same place and colour, while Lauma moves) and painted back
/// to white before anything else reads the pixels. The alpha is then cut the way the whole mascot
/// kit was cut: flood-filled inward from the border rather than keyed on white, because her eye
/// whites sample at the same value as the paper and a global key punches holes through them.
///
/// **Every frame of a clip shares one crop box**, unlike the still poses, which are each trimmed to
/// their own alpha bounds so `LaumaStage` can stand them on a band seam. Trimming per frame would
/// cancel out any movement toward or away from the camera, which in `wave` is the whole animation.
///
/// The current frame is a pure function of the clock rather than a timer. See `LaumaBlink` for why:
/// a `.task` chain of sleeps is cancelled by any rebuild, a bug that only shows itself on a device
/// fast enough to rebuild early.
struct LaumaClip: View {
    enum Clip {
        /// She waves, recedes into the distance and returns. Used on the `hello` beat.
        case wave
        /// She cheers, staying at the same distance throughout. Used on the `plan` beat.
        case cheer
        /// She cycles through expressions in place. Used on the `naming` beat.
        case naming

        var prefix: String {
            switch self {
            case .wave: return "LaumaWave"
            case .cheer: return "LaumaCheer"
            case .naming: return "LaumaName"
            }
        }

        /// Width over height of the cut frames, so the image is framed on its art rather than on
        /// the letterboxing a height-only frame would leave.
        var aspect: CGFloat {
            switch self {
            case .wave: return 653.0 / 900.0
            case .cheer: return 369.0 / 520.0
            case .naming: return 476.0 / 620.0
            }
        }

        /// Where she stands in each frame: horizontal centre, width, and the bottom of her
        /// silhouette, all as fractions of the frame. Measured by the extractor off the cut frames,
        /// never estimated.
        ///
        /// This exists so the ground shadow can follow her. In `wave` she recedes to a fifth of her
        /// full size, and a fixed ellipse would sit at full size underneath her, which is precisely
        /// the detached-sticker look the shadow was introduced to avoid.
        var stand: [(x: CGFloat, width: CGFloat, bottom: CGFloat)] {
            switch self {
            case .wave:
                return [
                    (0.4943, 0.9043, 0.9972), (0.5064, 0.9847, 0.9981), (0.4994, 0.9987, 0.9981),
                    (0.4994, 0.9987, 0.9981), (0.4866, 0.9120, 0.9981), (0.5344, 0.9286, 0.9981),
                    (0.5293, 0.8520, 0.9944), (0.5166, 0.7398, 0.9981), (0.5989, 0.7819, 0.9926),
                    (0.5446, 0.7321, 0.7882), (0.5185, 0.3253, 0.6531), (0.5249, 0.2360, 0.6855),
                    (0.5268, 0.1735, 0.7576), (0.5281, 0.1990, 0.7576), (0.5300, 0.2156, 0.7512),
                    (0.5293, 0.1964, 0.7243), (0.5261, 0.1875, 0.7447), (0.5274, 0.2309, 0.7817),
                    (0.5293, 0.2730, 0.7863), (0.5255, 0.2883, 0.7521), (0.5210, 0.2870, 0.7678),
                    (0.5223, 0.3635, 0.8316), (0.5236, 0.4681, 0.8464), (0.5242, 0.5179, 0.8242),
                    (0.5230, 0.5714, 0.8150), (0.5255, 0.6429, 0.9510), (0.5395, 0.9184, 0.9917),
                    (0.5236, 0.9503, 0.9972), (0.5051, 0.9796, 0.9991), (0.4872, 0.8980, 0.9963),
                ]
            case .cheer:
                return [
                    (0.5225, 0.9005, 0.9886), (0.5080, 0.8780, 0.9544), (0.5217, 0.9438, 0.9806),
                    (0.5209, 0.9551, 0.9989), (0.5064, 0.9711, 0.9977), (0.5064, 0.9197, 0.9806),
                    (0.4848, 0.9663, 0.9704), (0.4912, 0.9085, 0.9499), (0.5217, 0.9470, 0.9829),
                    (0.5201, 0.9535, 0.9989), (0.4928, 0.9759, 0.9977), (0.5080, 0.9133, 0.9795),
                    (0.4928, 0.9663, 0.9727), (0.4735, 0.9470, 0.9487), (0.5209, 0.9551, 0.9989),
                    (0.5136, 0.9599, 0.9966), (0.4848, 0.9567, 0.9977), (0.5064, 0.9230, 0.9784),
                    (0.5040, 0.9021, 0.9226), (0.4711, 0.9390, 0.8702), (0.5120, 0.9213, 0.9932),
                    (0.5024, 0.8443, 0.9909), (0.5024, 0.8700, 0.9909), (0.5048, 0.9358, 0.9909),
                    (0.4992, 0.9759, 0.9909), (0.5016, 0.9679, 0.9909), (0.5048, 0.9583, 0.9909),
                    (0.5040, 0.9599, 0.9909), (0.5040, 0.9599, 0.9909), (0.5040, 0.9599, 0.9909),
                ]
            case .naming:
                return [
                    (0.4341, 0.7739, 0.9915), (0.4341, 0.7739, 0.9915), (0.4341, 0.7739, 0.9915),
                    (0.4341, 0.7739, 0.9915), (0.4334, 0.7753, 0.9915), (0.4487, 0.7448, 0.9936),
                    (0.4785, 0.7490, 0.9947), (0.5014, 0.8086, 0.9989), (0.5062, 0.9293, 0.9915),
                    (0.4993, 0.9986, 0.9564), (0.4903, 0.9750, 0.8383), (0.4854, 0.9376, 0.7957),
                    (0.4778, 0.8724, 0.9479), (0.4854, 0.8294, 0.9968), (0.4993, 0.8627, 0.9936),
                    (0.5028, 0.9723, 0.9883), (0.4958, 0.9889, 0.8394), (0.4917, 0.9390, 0.7000),
                    (0.4840, 0.9015, 0.6681), (0.4757, 0.8405, 0.8553), (0.4667, 0.7947, 0.9926),
                    (0.4743, 0.8322, 0.9936), (0.4917, 0.8280, 0.9904), (0.5264, 0.8474, 0.9883),
                    (0.5208, 0.9168, 0.9872), (0.5111, 0.8918, 0.9872), (0.4903, 0.8086, 0.9862),
                    (0.4882, 0.7878, 0.9862), (0.4882, 0.7878, 0.9862), (0.4882, 0.7878, 0.9862),
                ]
            }
        }
    }

    let clip: Clip
    /// Height of the whole frame, not of Lauma. She fills most but not all of it.
    let height: CGFloat

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Both clips are 30 frames sampled across a 3.042s source, which is roughly 10fps.
    private static let frameCount = 30
    private static let frameDuration = 3.042 / 30

    var body: some View {
        if reduceMotion {
            // Frame 0 of each clip is her at full size, which is the right still of both. Note
            // this is a real accessibility decision and not an accident: these clips move her
            // through space, which is what Reduce Motion is for. `LaumaBlink` deliberately does
            // not follow this rule, because an eyelid moves nothing.
            stage(0)
        } else {
            TimelineView(.animation(minimumInterval: Self.frameDuration)) { context in
                stage(frame(at: context.date))
            }
        }
    }

    private func stage(_ index: Int) -> some View {
        let mark = clip.stand[index]
        let width = height * clip.aspect
        return ZStack(alignment: .topLeading) {
            groundShadow(mark, in: CGSize(width: width, height: height))
            Image(decorative: String(format: "\(clip.prefix)%02d", index))
                .resizable()
                .scaledToFit()
                .frame(width: width, height: height)
        }
        .frame(width: width, height: height)
    }

    /// The pool she casts on the band, scaled and placed from the measured silhouette.
    ///
    /// Same construction as `LaumaStage.groundShadow` and for the same reason: `.multiply` so it
    /// darkens the band it lands on instead of laying grey over it, which is the difference
    /// between a shadow on TEAL looking like deeper teal and looking like dirt.
    private func groundShadow(_ mark: (x: CGFloat, width: CGFloat, bottom: CGFloat), in size: CGSize) -> some View {
        let w = size.width * mark.width * 0.72
        let h = w * 0.18
        return Ellipse()
            .fill(
                RadialGradient(
                    colors: [.black.opacity(0.34), .black.opacity(0.16), .clear],
                    center: .center,
                    startRadius: 0,
                    endRadius: w * 0.5
                )
            )
            .frame(width: w, height: h)
            .blur(radius: max(1, w * 0.035))
            .blendMode(.multiply)
            .offset(
                x: size.width * mark.x - w / 2,
                y: size.height * mark.bottom - h * 0.62
            )
    }

    /// The frame for a given instant. Stateless, so a rebuild cannot restart or stall the loop.
    private func frame(at date: Date) -> Int {
        let loop = Double(Self.frameCount) * Self.frameDuration
        let phase = date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: loop)
        return min(Self.frameCount - 1, Int(phase / Self.frameDuration))
    }
}
