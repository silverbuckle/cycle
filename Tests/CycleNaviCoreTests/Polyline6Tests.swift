import Testing
@testable import CycleNaviCore

struct Polyline6Tests {
    @Test func microdegreesAndNegativeDelta() throws {
        #expect(try Polyline6.decode("??AABB") == [
            Coordinate(latitude: 0, longitude: 0),
            Coordinate(latitude: 0.000001, longitude: 0.000001),
            Coordinate(latitude: -0.000001, longitude: -0.000001)
        ])
    }
    @Test(arguments: ["?", "?~", "é?", " !", String(repeating: "~", count: 20), "_keqlD?", "_gdtjD?A?"])
    func malformed(_ value: String) {
        #expect(throws: InputError.self) { try Polyline6.decode(value) }
    }
    @Test func limits() {
        #expect(throws: InputError.self) { try Polyline6.decode(String(repeating: "?", count: 2_000_001)) }
        #expect(throws: InputError.self) { try Polyline6.decode(String(repeating: "??", count: 100_001)) }
    }
}
