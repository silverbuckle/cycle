import Testing
@testable import CycleNaviCore

struct RouteModelsTests {
    // Catches percentage-as-multiplier and additional-time calculation mistakes.
    @Test func detourBudget() throws {
        #expect(try DetourLimit.fraction(0.2).budget(baselineSeconds: 1000) == 1200)
        #expect(try DetourLimit.extraSeconds(600).budget(baselineSeconds: 1000) == 1600)
        #expect(try DetourLimit.fraction(0).budget(baselineSeconds: 1000) == 1000)
        #expect(try DetourLimit.extraSeconds(0).budget(baselineSeconds: 0) == 0)
    }

    @Test(arguments: [-1.0, Double.nan, Double.infinity, -Double.infinity])
    func rejectsInvalidBudgetInputs(_ bad: Double) {
        #expect(throws: InputError.self) {
            try DetourLimit.extraSeconds(bad).budget(baselineSeconds: 1000)
        }
        #expect(throws: InputError.self) {
            try DetourLimit.fraction(bad).budget(baselineSeconds: 1000)
        }
        #expect(throws: InputError.self) {
            try DetourLimit.fraction(0).budget(baselineSeconds: bad)
        }
    }

    @Test func rejectsBudgetOverflow() {
        #expect(throws: InputError.self) {
            try DetourLimit.extraSeconds(.greatestFiniteMagnitude)
                .budget(baselineSeconds: .greatestFiniteMagnitude)
        }
        #expect(throws: InputError.self) {
            try DetourLimit.fraction(1).budget(baselineSeconds: .greatestFiniteMagnitude)
        }
    }

    // Catches resetting a time allowance on each reroute, or dropping the hotel.
    @Test func reroutePreservesStopsAndOriginalBudget() throws {
        let start = try Coordinate(latitude: 35, longitude: 139)
        let cafe = try Coordinate(latitude: 35.05, longitude: 139.05)
        let hotel = try Coordinate(latitude: 35.1, longitude: 139.1)
        let request = try RouteRequest(
            origin: start, destination: hotel, orderedStops: [cafe, hotel],
            bike: .road, surface: .pavedOnly, totalBudgetSeconds: 1200
        )
        let first = try request.rerouting(from: cafe, elapsedSeconds: 300)
        let second = try first.rerouting(from: start, elapsedSeconds: 500)
        #expect(second.origin == start)
        #expect(second.remainingBudgetSeconds == 700)
        #expect(second.totalBudgetSeconds == 1200)
        #expect(second.orderedStops == [cafe, hotel])
        #expect(second.destination == hotel)
        #expect(second.bike == .road)
        #expect(second.surface == .pavedOnly)
        #expect(throws: InputError.self) {
            try second.rerouting(from: start, elapsedSeconds: 400)
        }
        #expect(try second.rerouting(from: start, elapsedSeconds: 500)
            .remainingBudgetSeconds == 700)
        #expect(try second.rerouting(from: start, elapsedSeconds: 1300)
            .remainingBudgetSeconds == 0)
    }

    @Test(arguments: [-1.0, Double.nan, Double.infinity, -Double.infinity])
    func rejectsInvalidRequestTimes(_ bad: Double) throws {
        let point = try Coordinate(latitude: 35, longitude: 139)
        #expect(throws: InputError.self) {
            try RouteRequest(origin: point, destination: point, orderedStops: [],
                bike: .cross, surface: .allowUnpaved, totalBudgetSeconds: bad)
        }
        #expect(throws: InputError.self) {
            try RouteRequest(origin: point, destination: point, orderedStops: [],
                bike: .cross, surface: .allowUnpaved,
                totalBudgetSeconds: 1000, elapsedSeconds: bad)
        }
        let request = try RouteRequest(origin: point, destination: point, orderedStops: [],
            bike: .cross, surface: .allowUnpaved, totalBudgetSeconds: 1000)
        #expect(throws: InputError.self) {
            try request.rerouting(from: point, elapsedSeconds: bad)
        }
    }

    @Test func rejectsInvalidCoordinates() {
        for (lat, lon) in [(91.0, 0.0), (-91, 0), (0, 181), (0, -181),
                           (.nan, 0), (0, .nan), (.infinity, 0), (0, -.infinity)] {
            #expect(throws: InputError.self) { try Coordinate(latitude: lat, longitude: lon) }
        }
    }

    @Test func acceptsCoordinateBoundaries() throws {
        _ = try Coordinate(latitude: -90, longitude: -180)
        _ = try Coordinate(latitude: 90, longitude: 180)
    }

    @Test(arguments: [BikeKind.road, .cross, .gravel])
    func bikeDoesNotOverrideSurfacePreference(_ bike: BikeKind) throws {
        let point = try Coordinate(latitude: 35, longitude: 139)
        let request = try RouteRequest(origin: point, destination: point, orderedStops: [],
            bike: bike, surface: .pavedOnly, totalBudgetSeconds: 0)
        #expect(try request.rerouting(from: point, elapsedSeconds: 0).surface == .pavedOnly)
    }
}
