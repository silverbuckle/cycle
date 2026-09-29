import Testing
@testable import CycleNaviCore

struct RouteSelectionTests {
    // Catches deriving the baseline from a forbidden/unknown/unpaved shortcut.
    @Test func excludesForbiddenAndUnknownBeforeBaseline() throws {
        let candidates = [
            RouteCandidate(id: "closed", seconds: 100, accessAllowed: false, surface: .paved),
            RouteCandidate(id: "unknown", seconds: 200, accessAllowed: true, surface: .unknown),
            RouteCandidate(id: "dirt", seconds: 300, accessAllowed: true, surface: .unpaved),
            RouteCandidate(id: "road", seconds: 1000, accessAllowed: true, surface: .paved),
            RouteCandidate(id: "quiet", seconds: 1200, accessAllowed: true, surface: .paved),
            RouteCandidate(id: "long", seconds: 1201, accessAllowed: true, surface: .paved)
        ]
        let result = try selectRoutes(candidates, surface: .pavedOnly, detour: .fraction(0.2))
        #expect(result.baselineSeconds == 1000)
        #expect(result.candidates.map(\.id) == ["road", "quiet"])
        let exhausted = try selectRoutes(candidates, surface: .pavedOnly,
            detour: .fraction(0.2), remainingBudgetSeconds: 900)
        #expect(exhausted.baselineSeconds == 1000)
        #expect(exhausted.candidates.isEmpty)
    }

    @Test func noCandidateIsExplicit() throws {
        let result = try selectRoutes([], surface: .pavedOnly, detour: .fraction(0.2))
        #expect(result.baselineSeconds == nil)
        #expect(result.candidates.isEmpty)
        let rejected = try selectRoutes([
            RouteCandidate(id: "closed", seconds: 100, accessAllowed: false, surface: .paved)
        ], surface: .allowUnpaved, detour: .extraSeconds(600))
        #expect(rejected.baselineSeconds == nil)
        #expect(rejected.candidates.isEmpty)
    }

    @Test(arguments: [-1.0, Double.nan, Double.infinity, -Double.infinity])
    func invalidDurationIsNeverRecommended(_ bad: Double) throws {
        let result = try selectRoutes([
            RouteCandidate(id: "bad", seconds: bad, accessAllowed: true, surface: .paved),
            RouteCandidate(id: "valid", seconds: 100, accessAllowed: true, surface: .paved)
        ], surface: .pavedOnly, detour: .fraction(0.2))
        #expect(result.baselineSeconds == 100)
        #expect(result.candidates.map(\.id) == ["valid"])
    }

    @Test func unpavedPermissionPreservesUnknownSurface() throws {
        let result = try selectRoutes([
            RouteCandidate(id: "dirt", seconds: 100, accessAllowed: true, surface: .unpaved),
            RouteCandidate(id: "unknown", seconds: 110, accessAllowed: true, surface: .unknown),
            RouteCandidate(id: "closed", seconds: 90, accessAllowed: false, surface: .unpaved)
        ], surface: .allowUnpaved, detour: .extraSeconds(10))
        #expect(result.candidates.map(\.id) == ["dirt", "unknown"])
        #expect(result.candidates.map(\.surface) == [.unpaved, .unknown])
    }

    @Test func zeroDetourKeepsTiedFastestRoutesInInputOrder() throws {
        let result = try selectRoutes([
            RouteCandidate(id: "slow", seconds: 101, accessAllowed: true, surface: .paved),
            RouteCandidate(id: "second", seconds: 100, accessAllowed: true, surface: .paved),
            RouteCandidate(id: "first", seconds: 100, accessAllowed: true, surface: .paved)
        ], surface: .pavedOnly, detour: .extraSeconds(0))
        #expect(result.candidates.map(\.id) == ["second", "first"])
    }

    @Test func remainingBudgetIsAHardCap() throws {
        let candidates = [
            RouteCandidate(id: "fast", seconds: 600, accessAllowed: true, surface: .paved),
            RouteCandidate(id: "fits", seconds: 700, accessAllowed: true, surface: .paved),
            RouteCandidate(id: "over", seconds: 701, accessAllowed: true, surface: .paved)
        ]
        let point = try Coordinate(latitude: 35, longitude: 139)
        let request = try RouteRequest(origin: point, destination: point, orderedStops: [point],
            bike: .gravel, surface: .pavedOnly, totalBudgetSeconds: 1200)
        let rerouted = try request.rerouting(from: point, elapsedSeconds: 500)
        let result = try selectRoutes(candidates, surface: rerouted.surface,
            detour: .extraSeconds(600), remainingBudgetSeconds: rerouted.remainingBudgetSeconds)
        #expect(result.candidates.map(\.id) == ["fast", "fits"])
    }

    @Test(arguments: [-1.0, Double.nan, Double.infinity, -Double.infinity])
    func invalidConstraintsThrowEvenWithoutCandidates(_ bad: Double) {
        #expect(throws: InputError.self) {
            try selectRoutes([], surface: .pavedOnly, detour: .fraction(bad))
        }
        #expect(throws: InputError.self) {
            try selectRoutes([], surface: .pavedOnly, detour: .extraSeconds(bad))
        }
        #expect(throws: InputError.self) {
            try selectRoutes([], surface: .pavedOnly, detour: .fraction(0),
                remainingBudgetSeconds: bad)
        }
    }

    @Test func zeroDurationCanRepresentArrival() throws {
        let result = try selectRoutes([
            RouteCandidate(id: "arrived", seconds: 0, accessAllowed: true, surface: .paved),
            RouteCandidate(id: "not-arrived", seconds: 1, accessAllowed: true, surface: .paved)
        ], surface: .pavedOnly, detour: .fraction(0.2), remainingBudgetSeconds: 0)
        #expect(result.baselineSeconds == 0)
        #expect(result.candidates.map(\.id) == ["arrived"])
    }
}
