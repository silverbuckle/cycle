import Testing
@testable import CycleNaviCore

struct PlannedRouteTests {
    private func route(id: String = "a", seconds: Double = 10, meters: Double = 20,
                       points: Int = 2, index: Int? = 1) throws -> PlannedRoute {
        try PlannedRoute(id: id, provider: .valhalla, name: "test",
            coordinates: Array(repeating: Coordinate(latitude: 0, longitude: 0), count: points),
            seconds: seconds, meters: meters,
            instructions: [RouteInstruction(text: "go", meters: 0, shapeIndex: index)], surface: .unknown)
    }
    @Test func validAndUnknownIndex() throws {
        #expect(try route().instructions[0].shapeIndex == 1)
        #expect(try route(index: nil).surface == .unknown)
    }
    @Test(arguments: [0.0, -1, Double.nan, .infinity]) func invalidMeasures(_ value: Double) {
        #expect(throws: InputError.self) { try route(seconds: value) }
        #expect(throws: InputError.self) { try route(meters: value) }
    }
    @Test func invalidStructure() {
        #expect(throws: InputError.self) { try route(id: "") }
        #expect(throws: InputError.self) { try route(points: 1) }
        #expect(throws: InputError.self) { try route(index: 2) }
        #expect(throws: InputError.self) { try route(index: -1) }
        #expect(throws: InputError.self) { try RouteInstruction(text: "x", meters: -1, shapeIndex: nil) }
        #expect(throws: InputError.self) { try RouteInstruction(text: "x", meters: .nan, shapeIndex: nil) }
    }
}
