import Testing
@testable import ColorSense

@Suite("StoreKit product contract")
struct ProStoreTests {
    @Test func productIdentifiersMatchAppStoreConnect() {
        #expect(ProProduct.monthly.rawValue == "online.colorsense.ios.pro.monthly")
        #expect(ProProduct.annual.rawValue == "online.colorsense.ios.pro.annual")
        #expect(ProProduct.pass.rawValue == "online.colorsense.ios.pro.pass")
        #expect(Set(ProProduct.allCases.map(\.rawValue)).count == 3)
    }

    @Test func subscriptionsAndConsumableCannotBeConfused() {
        #expect(ProProduct.monthly.kind == .autoRenewable)
        #expect(ProProduct.annual.kind == .autoRenewable)
        #expect(ProProduct.pass.kind == .consumable)
    }

    @Test func placeholderNeverExposesADeadPurchaseScreen() async {
        let store = PlaceholderProStore()
        #expect(!store.isLive)
        #expect(await store.productInfo().isEmpty)
        #expect(await store.purchase(.monthly) == .notConfigured)
        #expect(await store.restore() == .notConfigured)
    }
}
