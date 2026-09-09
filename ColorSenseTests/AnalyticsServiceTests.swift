import Testing
@testable import ColorSense

@Suite("Analytics privacy gate")
struct AnalyticsServiceTests {
    @Test("Allowed product events disable GeoIP without dropping their properties")
    func allowedEventsDisableGeoIP() throws {
        let properties = try #require(
            AnalyticsService.privacyFilteredProperties(
                eventName: AnalyticsService.Event.paletteGenerated.rawValue,
                properties: ["colors": 5, "$geoip_disable": false]
            )
        )

        #expect(properties["colors"] as? Int == 5)
        #expect(properties["$geoip_disable"] as? Bool == true)
    }

    @Test("Crash reports pass through the same location privacy gate")
    func crashReportsDisableGeoIP() throws {
        let properties = try #require(
            AnalyticsService.privacyFilteredProperties(
                eventName: "$exception",
                properties: ["$exception_type": "SyntheticError"]
            )
        )

        #expect(properties["$geoip_disable"] as? Bool == true)
    }

    @Test("SDK events outside the allowlist are still dropped")
    func unknownEventsAreDropped() {
        let properties = AnalyticsService.privacyFilteredProperties(
            eventName: "Application Opened",
            properties: [:]
        )

        #expect(properties == nil)
    }
}
