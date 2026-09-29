import Testing
@testable import CycleNaviCore

private actor IntentHistory {
    var values: [CandidateIntent] = []
    func add(_ value: CandidateIntent) { values.append(value) }
}
struct CyclingRoutePlannerTests {
    private func route(_ intent: CandidateIntent, shifted: Bool = false) throws -> PlannedRoute {
        try PlannedRoute(id: intent.rawValue, provider: .valhalla, name: intent.rawValue,
            coordinates: [Coordinate(latitude: 0, longitude: 0),
                          Coordinate(latitude: shifted ? 0.2 : 0.1, longitude: 0.1)],
            seconds: 600, meters: 1250, instructions: [], surface: .unknown)
    }
    @Test func twoIntentsAndDistinctPaths() async throws {
        let history = IntentHistory()
        let planner = CyclingRoutePlanner { query, intent in
            await history.add(intent)
            #expect(query.bike == .gravel)
            return try route(intent, shifted: intent == .preferred)
        }
        let batch = try await planner.routes(for: ValhallaTestData.query())
        #expect(batch.routes.count == 2)
        #expect(!batch.incomplete)
        #expect(await history.values == [.baseline, .preferred])
    }
    @Test func deduplicatesOnlyExactGeometry() async throws {
        let batch = try await CyclingRoutePlanner { _, intent in try route(intent) }
            .routes(for: ValhallaTestData.query())
        #expect(batch.routes.count == 1)
        #expect(!batch.incomplete)
    }
    @Test(arguments: [CandidateIntent.baseline, .preferred]) func partialFailure(_ failed: CandidateIntent) async throws {
        let batch = try await CyclingRoutePlanner { _, intent in
            if intent == failed { throw RoutingFailure.timeout }
            return try route(intent)
        }.routes(for: ValhallaTestData.query())
        #expect(batch.incomplete)
        #expect(batch.routes.count == 1)
        #expect(batch.routes[0].id != failed.rawValue)
    }
    @Test func allFailReturnsFirstFailure() async throws {
        let planner = CyclingRoutePlanner { _, intent in
            throw intent == .baseline ? RoutingFailure.rateLimited : .network
        }
        await #expect(throws: RoutingFailure.rateLimited) { try await planner.routes(for: ValhallaTestData.query()) }
    }
    @Test func cancellationDoesNotStartSecondRequest() async throws {
        let history = IntentHistory()
        let planner = CyclingRoutePlanner { _, intent in
            await history.add(intent)
            throw CancellationError()
        }
        await #expect(throws: CancellationError.self) { try await planner.routes(for: ValhallaTestData.query()) }
        #expect(await history.values == [.baseline])
    }
}
