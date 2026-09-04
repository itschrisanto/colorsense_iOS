import SwiftUI

/// The Color Scheme Generator, ported from the web's `SchemePanel`.
///
/// Free, matching the web, where only `website` and `svgrecolor` carry `pro: true`. Charging for
/// colour theory in an app whose contrast checker is free would sit badly.
///
/// The wheel is the point of this tool rather than decoration: it shows *where the scheme lives*
/// relative to the base, so complementary reads as opposite and triadic as evenly spaced. A list of
/// swatches alone would give the colours without the idea.
struct SchemeView: View {
    @Environment(PaletteStore.self) private var store
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var base: PaletteColor
    @State private var harmony: ColorScheme.Harmony = .complementary
    @State private var editorColor: Color = .clear
    @State private var editorIsValid = true
    @State private var editorIsPresented = false
    @State private var toast: String?

    init(palette: ExtractedPalette) {
        // Seeded from the palette's first colour, as the web seeds from `colors[0]`.
        _base = State(initialValue: palette.colors.first ?? PaletteColor(hex: 0x6C5CE7, dominance: 0))
    }

    private var scheme: [PaletteColor] { ColorScheme.colors(base: base, harmony: harmony) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                wheelSection
                harmonySection
                resultSection
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 24)
        }
        .background(Color(.systemBackground))
        .safeAreaInset(edge: .bottom, spacing: 0) { applyBar }
        .overlay(alignment: .top) { if let toast { toastView(toast) } }
        .sheet(isPresented: $editorIsPresented) {
            NavigationStack {
                CustomColorEditor(color: $editorColor, isValid: $editorIsValid)
                    .navigationTitle("Base color")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Cancel") { editorIsPresented = false }
                        }
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Done") {
                                base = PaletteColor(color: editorColor)
                                editorIsPresented = false
                            }
                            .disabled(!editorIsValid)
                        }
                    }
            }
            .presentationDetents([.medium])
        }
    }

    private var wheelSection: some View {
        VStack(spacing: 14) {
            SchemeWheel(base: $base, scheme: scheme)
                .frame(maxWidth: .infinity)

            HStack(spacing: 10) {
                // The hex goes through `CustomColorEditor`, which owns the only hex field in the
                // app. A second one here would be a second set of validation and paste rules to
                // keep in step, which is exactly what that component exists to prevent.
                Button {
                    editorColor = base.color
                    editorIsPresented = true
                } label: {
                    HStack(spacing: 8) {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(base.color)
                            .frame(width: 22, height: 22)
                            .overlay { RoundedRectangle(cornerRadius: 6).strokeBorder(.primary.opacity(0.15)) }
                        Text(base.hex).brandMono(15, weight: .medium)
                    }
                }
                .buttonStyle(.secondaryAction)
                .accessibilityLabel("Base color \(base.name), \(base.hex). Change")

                Button {
                    withAnimation(PaletteMotion.recolor(reduceMotion: reduceMotion)) {
                        base = ColorScheme.randomBase()
                    }
                } label: {
                    Label("Random", systemImage: "shuffle")
                }
                .buttonStyle(.secondaryAction)
            }
        }
    }

    private var harmonySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Harmony")
                .font(BrandFont.ui(13, weight: .bold))
                .foregroundStyle(.secondary)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(ColorScheme.Harmony.allCases) { option in
                        let isOn = option == harmony
                        Button {
                            withAnimation(PaletteMotion.recolor(reduceMotion: reduceMotion)) {
                                harmony = option
                            }
                        } label: {
                            Text(option.title)
                                .font(BrandFont.ui(14, weight: .medium))
                                .padding(.horizontal, 14)
                                .padding(.vertical, 9)
                                .background {
                                    Capsule().fill(isOn ? BrandColor.coral : Color(.secondarySystemBackground))
                                }
                                .foregroundStyle(isOn ? PaletteColor(color: BrandColor.coral).legibleForeground : .primary)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("\(option.title). \(option.summary)")
                        .accessibilityAddTraits(isOn ? .isSelected : [])
                    }
                }
                .padding(.horizontal, 2)
            }

            Text(harmony.summary)
                .font(BrandFont.ui(14))
                .foregroundStyle(.secondary)
        }
    }

    private var resultSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("\(scheme.count) colors")
                .font(BrandFont.ui(13, weight: .bold))
                .foregroundStyle(.secondary)

            HStack(spacing: 8) {
                ForEach(scheme) { swatch in
                    Button {
                        UIPasteboard.general.string = swatch.hex
                        showToast("Copied \(swatch.hex)")
                    } label: {
                        VStack(spacing: 6) {
                            RoundedRectangle(cornerRadius: 12)
                                .fill(swatch.color)
                                .frame(height: 76)
                                .overlay { RoundedRectangle(cornerRadius: 12).strokeBorder(.primary.opacity(0.12)) }
                            Text(swatch.hex)
                                .brandMono(11, weight: .medium)
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)
                        }
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(swatch.name), \(swatch.hex). Copy")
                }
            }
        }
    }

    private var applyBar: some View {
        VStack(spacing: 0) {
            Divider()
            Button("Use as my palette") {
                withAnimation(PaletteMotion.replace(reduceMotion: reduceMotion)) {
                    store.recolor(to: scheme)
                }
                AnalyticsService.capture(.paletteGenerated, ["colors": scheme.count])
                showToast("Palette updated")
            }
            .buttonStyle(.primaryAction)
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 8)
        }
        .background(.bar)
    }

    private func toastView(_ message: String) -> some View {
        Text(message)
            .font(BrandFont.ui(14, weight: .medium))
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(.ultraThinMaterial, in: Capsule())
            .overlay { Capsule().strokeBorder(.primary.opacity(0.12), lineWidth: 0.5) }
            .padding(.top, 8)
            .transition(.move(edge: .top).combined(with: .opacity))
    }

    private func showToast(_ message: String) {
        withAnimation(.snappy) { toast = message }
        Task {
            try? await Task.sleep(for: .seconds(1.6))
            withAnimation(.snappy) { if toast == message { toast = nil } }
        }
    }
}

/// Hue around, saturation outward, with the scheme's partners marked where they fall.
///
/// Lightness is not on the wheel, so picking always commits at 0.5 — the web does the same, and it
/// is why the hex button exists beside it for anything darker or lighter.
private struct SchemeWheel: View {
    @Binding var base: PaletteColor
    let scheme: [PaletteColor]

    private let size: CGFloat = 236

    var body: some View {
        ZStack {
            Circle()
                .fill(AngularGradient(
                    // Hue 0 at the top, matching `ColorScheme.wheelPosition`.
                    colors: stride(from: 0, through: 360, by: 15).map {
                        let rgb = ColorMath.rgb(from: .init(hue: Double($0), saturation: 1, lightness: 0.5))
                        return Color(red: rgb.red, green: rgb.green, blue: rgb.blue)
                    },
                    center: .center,
                    angle: .degrees(-90)
                ))
                .overlay {
                    Circle().fill(RadialGradient(
                        colors: [Color.white, Color.white.opacity(0)],
                        center: .center, startRadius: 0, endRadius: size / 2
                    ))
                }

            ForEach(Array(scheme.dropFirst().enumerated()), id: \.offset) { _, swatch in
                marker(for: swatch, diameter: 16)
            }
            marker(for: base, diameter: 28)
        }
        .frame(width: size, height: size)
        .contentShape(.circle)
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { value in
                    let centre = CGPoint(x: size / 2, y: size / 2)
                    let dx = value.location.x - centre.x
                    let dy = value.location.y - centre.y
                    let radius = min((dx * dx + dy * dy).squareRoot(), size / 2) / (size / 2)
                    let degrees = atan2(dy, dx) * 180 / .pi
                    base = ColorScheme.color(atAngle: degrees, radius: radius)
                }
        )
        .accessibilityElement()
        .accessibilityLabel("Color wheel")
        .accessibilityValue("\(base.name), \(base.hex)")
        .accessibilityHint("Drag to choose a base color, or use the hex button below")
    }

    private func marker(for swatch: PaletteColor, diameter: CGFloat) -> some View {
        let position = ColorScheme.wheelPosition(of: swatch)
        let radians = position.angle * .pi / 180
        return Circle()
            .fill(swatch.color)
            .frame(width: diameter, height: diameter)
            .overlay { Circle().strokeBorder(.white, lineWidth: diameter > 20 ? 3 : 2) }
            .shadow(color: .black.opacity(0.25), radius: 3, y: 1)
            .offset(
                x: cos(radians) * position.radius * (size / 2),
                y: sin(radians) * position.radius * (size / 2)
            )
            .allowsHitTesting(false)
    }
}

#Preview {
    SchemeView(palette: .brandDefault)
        .environment(PaletteStore())
}
