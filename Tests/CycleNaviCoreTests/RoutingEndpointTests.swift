import Testing
@testable import CycleNaviCore

struct RoutingEndpointTests {
    @Test func acceptsExplicitSecureRoute() throws {
        #expect(try RoutingEndpoint("https://example.com/v1/route").routeURL.host == "example.com")
        #expect(throws: RoutingFailure.unconfigured) { try RoutingEndpoint("") }
    }
    @Test(arguments: ["http://example.com/route", "https:///route", "https://example.com", "https://user:secret@example.com/route", "https://example.com/route?key=secret", "https://example.com/route#x", "file:///route", " https://example.com/route"])
    func rejectsUnsafeEndpoint(_ raw: String) {
        #expect(throws: RoutingFailure.invalidEndpoint) { try RoutingEndpoint(raw) }
    }
}
