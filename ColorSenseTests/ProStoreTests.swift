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

    @Test func restoreUsesActiveBackendEntitlementWhenAppStoreSyncFails() async {
        struct SyncFailure: Error {}
        let store = StoreKitProStore(
            hasAuthenticatedSession: { true },
            syncAppStore: { throw SyncFailure() },
            fetchCurrentPlan: { .success("pro") }
        )

        #expect(await store.restore() == .purchased)
    }

    @Test func restoreDoesNotGrantFreeAccountWhenAppStoreSyncFails() async {
        struct SyncFailure: Error {}
        let store = StoreKitProStore(
            hasAuthenticatedSession: { true },
            syncAppStore: { throw SyncFailure() },
            fetchCurrentPlan: { .success("free") }
        )

        #expect(
            await store.restore()
                == .failed("Purchases could not be restored. Please try again.")
        )
    }

    @Test func reconciliationRetriesUntilSharedEntitlementBecomesPaid() async {
        actor PlanResponses {
            private var responses: [String?] = ["free", "free", "pro"]
            private(set) var reads = 0

            func next() -> Result<String?, SavedPaletteService.SaveError> {
                reads += 1
                return .success(responses.removeFirst())
            }
        }

        actor DelayRecorder {
            private(set) var values: [Duration] = []
            func append(_ value: Duration) { values.append(value) }
        }

        let plans = PlanResponses()
        let delays = DelayRecorder()
        let store = StoreKitProStore(
            fetchCurrentPlan: { await plans.next() },
            pauseBeforePlanRetry: { await delays.append($0) }
        )

        #expect(await store.confirmsPaidPlanAfterReconciliation())
        #expect(await plans.reads == 3)
        #expect(await delays.values == [.milliseconds(250), .milliseconds(500)])
    }

    @Test func reconciliationStopsAfterBoundedRetriesWithoutGrantingAccess() async {
        actor CallCounts {
            private(set) var reads = 0
            private(set) var pauses = 0

            func recordRead() -> Result<String?, SavedPaletteService.SaveError> {
                reads += 1
                return .success("free")
            }

            func recordPause() { pauses += 1 }
        }

        let calls = CallCounts()
        let store = StoreKitProStore(
            fetchCurrentPlan: { await calls.recordRead() },
            pauseBeforePlanRetry: { _ in await calls.recordPause() }
        )

        #expect(!(await store.confirmsPaidPlanAfterReconciliation()))
        #expect(await calls.reads == 4)
        #expect(await calls.pauses == 3)
    }
}
