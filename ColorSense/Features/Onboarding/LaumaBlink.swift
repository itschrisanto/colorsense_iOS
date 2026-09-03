import SwiftUI

/// Lauma's head, blinking.
///
/// The frames come from a 24fps animation Chris generated (`2026-09-03 13:43:33.MOV`). The video
/// itself is not shippable: it carries a burned-in "KlingAI 3.0" watermark in the top-right and
/// bottom-right, and a 4.7MB H.264 with an audio track is a silly way to play 0.4 seconds of
/// eyelid. What made it usable is that the head's bounding box is **pixel-identical in all 35
/// frames** (195,660,780,1176) and sits well clear of both watermarks, so cropping to the head
/// drops the watermarks entirely and the frames can be swapped with no jitter.
///
/// Ten frames were kept, sampled from the source's own blink: open, three closing, shut, four
/// opening, open. They are matted off the video's coral, which is a different coral from
/// `BrandColor.coral`, so they must be composited rather than laid on a matching background.
///
/// This is the blink that could not be synthesised. Two attempts at drawing or baking eyelids over
/// the still art were rejected for looking like artifacts; real animation frames simply work.
///
/// # Why this is driven by the clock and holds no state
///
/// The first version advanced the frames with a chain of `Task.sleep` calls in a `.task` on this
/// view, and it played reliably in the simulator while Chris never once caught it on a phone.
/// That is the same asymmetry, and the same cause, as the splash timer bug recorded in CLAUDE.md:
/// a `.task` is tied to the view's lifetime, so any early rebuild cancels it, `try? await` hides
/// the cancellation, and the sequence silently restarts from its initial delay. On a device the
/// app initialises fast enough for that to happen repeatedly in the first seconds, which is
/// exactly the window the blink was supposed to play in. The simulator is slow and idle there, so
/// it never reproduced.
///
/// So there is no timer, no task and no stored progress here. The frame is a pure function of the
/// wall clock, and `TimelineView` asks for it on the render loop. A rebuild cannot restart, stall
/// or desynchronise something that remembers nothing: at any instant the blink is simply wherever
/// the clock says it is.
struct LaumaBlink: View {
    let height: CGFloat
    /// How long she holds her eyes open between blinks. The gap is jittered per cycle so she reads
    /// as a living thing rather than a metronome. The splash passes a much tighter range than this
    /// default: a blink is barely half a second, so on a short screen a four-second gap can hide
    /// it completely, which is what happened on device.
    var gap: ClosedRange<Double> = 2.2...4.4

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private static let frameCount = 10
    /// The source runs at 24fps. Holding each frame for one source frame keeps the blink at the
    /// speed it was animated at; faster reads as a flicker and slower reads as a wink.
    private static let frameDuration = 0.042
    /// The frame where her eyes are fully shut.
    private static let shutFrame = 4
    /// An extra beat on the shut frame. Real eyes rest closed for an instant, and without it the
    /// whole blink is 420ms of continuous motion that the eye reads as a flicker and misses.
    private static let shutHold = 0.1

    private static var blinkDuration: Double {
        Double(frameCount) * frameDuration + shutHold
    }

    var body: some View {
        // Under Reduce Motion she simply keeps her eyes open. Frame 0 is the resting pose.
        if reduceMotion {
            image(0)
        } else {
            TimelineView(.animation(minimumInterval: Self.frameDuration)) { context in
                image(frame(at: context.date))
            }
        }
    }

    private func image(_ index: Int) -> some View {
        Image(decorative: String(format: "LaumaBlink%02d", index))
            .resizable()
            .scaledToFit()
            .frame(height: height)
    }

    /// Where the blink is at a given instant.
    ///
    /// Time is cut into fixed slots, each long enough to hold one blink plus the longest gap. The
    /// blink starts at a jittered offset inside its slot, so the spacing between blinks varies
    /// while the slot arithmetic stays a single division. Every value is derived from `date`, so
    /// two views asking at the same instant agree and nothing has to be remembered between frames.
    private func frame(at date: Date) -> Int {
        let slot = Self.blinkDuration + gap.upperBound
        let now = date.timeIntervalSinceReferenceDate
        let index = (now / slot).rounded(.down)
        let start = Self.jitter(inSlot: Int(index)) * (gap.upperBound - gap.lowerBound)
        let phase = now - index * slot - start

        // Outside her blink she is simply open.
        guard phase >= 0, phase < Self.blinkDuration else { return 0 }

        // The shut frame is held, so everything after it is offset by that hold.
        let shutStarts = Double(Self.shutFrame) * Self.frameDuration
        if phase < shutStarts {
            return Int(phase / Self.frameDuration)
        }
        if phase < shutStarts + Self.shutHold {
            return Self.shutFrame
        }
        let after = phase - Self.shutHold
        return min(Self.frameCount - 1, Int(after / Self.frameDuration))
    }

    /// A stable 0..<1 value per slot. Deterministic rather than `random`, because the frame has to
    /// be a pure function of the clock: a random draw would give a different answer every time the
    /// view rebuilt, and she would stutter mid-blink.
    private static func jitter(inSlot slot: Int) -> Double {
        var x = UInt64(bitPattern: Int64(slot)) &* 0x9E37_79B9_7F4A_7C15
        x ^= x >> 29
        x = x &* 0xBF58_476D_1CE4_E5B9
        x ^= x >> 32
        return Double(x % 1000) / 1000
    }
}
