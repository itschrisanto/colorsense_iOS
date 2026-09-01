import SwiftUI

struct WCAGCheckerView: View {
    @State private var viewModel = WCAGCheckerViewModel()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    preview
                    VStack(spacing: 16) {
                        ColorPicker("Text color", selection: $viewModel.foreground, supportsOpacity: false)
                        ColorPicker("Background color", selection: $viewModel.background, supportsOpacity: false)
                    }
                    .font(BrandFont.ui(16))
                    .padding(.horizontal)

                    ratioCard
                }
                .padding(.vertical)
            }
            .navigationTitle("WCAG Checker")
        }
    }

    private var preview: some View {
        RoundedRectangle(cornerRadius: 16)
            .fill(viewModel.background)
            .frame(height: 140)
            .overlay {
                Text("Sample text")
                    .font(BrandFont.ui(22, weight: .medium))
                    .foregroundStyle(viewModel.foreground)
            }
            .padding(.horizontal)
    }

    private var ratioCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(String(format: "%.2f:1", viewModel.ratio))
                .font(BrandFont.display(40))

            levelRow(title: "Normal text", level: viewModel.normalTextLevel)
            levelRow(title: "Large text", level: viewModel.largeTextLevel)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.quaternary.opacity(0.4))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal)
    }

    private func levelRow(title: String, level: ContrastCalculator.Level) -> some View {
        HStack {
            Text(title)
                .font(BrandFont.ui(15))
            Spacer()
            Text(label(for: level))
                .font(BrandFont.ui(14, weight: .medium))
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(color(for: level).opacity(0.15))
                .foregroundStyle(color(for: level))
                .clipShape(Capsule())
        }
    }

    private func label(for level: ContrastCalculator.Level) -> String {
        switch level {
        case .fail: return "Fail"
        case .aa: return "AA"
        case .aaa: return "AAA"
        }
    }

    private func color(for level: ContrastCalculator.Level) -> Color {
        switch level {
        case .fail: return .red
        case .aa: return BrandColor.teal
        case .aaa: return .green
        }
    }
}

#Preview {
    WCAGCheckerView()
}
