import Testing
@testable import ColorSense

struct ContrastCalculatorTests {
    @Test func blackOnWhiteIsMaxContrast() {
        let ratio = ContrastCalculator.ratio(r1: 0, g1: 0, b1: 0, r2: 1, g2: 1, b2: 1)
        #expect(abs(ratio - 21.0) < 0.01)
    }

    @Test func sameColorIsMinContrast() {
        let ratio = ContrastCalculator.ratio(r1: 0.4, g1: 0.4, b1: 0.4, r2: 0.4, g2: 0.4, b2: 0.4)
        #expect(abs(ratio - 1.0) < 0.001)
    }

    @Test func orderOfArgumentsDoesNotMatter() {
        let a = ContrastCalculator.ratio(r1: 0, g1: 0, b1: 0, r2: 1, g2: 1, b2: 1)
        let b = ContrastCalculator.ratio(r1: 1, g1: 1, b1: 1, r2: 0, g2: 0, b2: 0)
        #expect(a == b)
    }

    @Test func normalTextThresholds() {
        #expect(ContrastCalculator.normalTextLevel(for: 7.0) == .aaa)
        #expect(ContrastCalculator.normalTextLevel(for: 4.5) == .aa)
        #expect(ContrastCalculator.normalTextLevel(for: 4.49) == .fail)
    }

    @Test func largeTextThresholds() {
        #expect(ContrastCalculator.largeTextLevel(for: 4.5) == .aaa)
        #expect(ContrastCalculator.largeTextLevel(for: 3.0) == .aa)
        #expect(ContrastCalculator.largeTextLevel(for: 2.99) == .fail)
    }
}
