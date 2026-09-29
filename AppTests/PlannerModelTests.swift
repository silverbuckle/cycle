import XCTest
import CycleNaviCore
import CoreLocation
@testable import CycleNavi

private actor PendingRoutes: CyclingRouteProviding {
    private var continuation: CheckedContinuation<RouteBatch, Error>?
    private var started: CheckedContinuation<Void, Never>?
    func routes(for query: CyclingQuery) async throws -> RouteBatch {
        try await withCheckedThrowingContinuation {
            continuation = $0
            started?.resume(); started = nil
        }
    }
    func waitForRequest() async {
        if continuation != nil { return }
        await withCheckedContinuation { started = $0 }
    }
    func finish(_ batch: RouteBatch) { continuation?.resume(returning: batch); continuation = nil }
}
private struct FixedRoutes: CyclingRouteProviding {
    let batch: RouteBatch
    func routes(for query: CyclingQuery) async throws -> RouteBatch { batch }
}

@MainActor final class PlannerModelTests: XCTestCase {
    private func setup(_ provider: any CyclingRouteProviding) -> PlannerModel {
        let model = PlannerModel(provider: provider)
        model.select(Place(name: "A", subtitle: "", coordinate: .init(latitude: 35, longitude: 139)), asOrigin: true)
        model.select(Place(name: "B", subtitle: "", coordinate: .init(latitude: 35.1, longitude: 139.1)), asOrigin: false)
        return model
    }
    private func route(_ id: String, seconds: Double) throws -> PlannedRoute {
        try PlannedRoute(id: id, provider: .valhalla, name: id,
            coordinates: [Coordinate(latitude: 35, longitude: 139), Coordinate(latitude: 35.1, longitude: 139.1)],
            seconds: seconds, meters: 1000, instructions: [], surface: .unknown)
    }
    func testEveryRoutePreferenceInvalidatesPendingResult() async throws {
        for mutation in 0..<6 {
            let provider = PendingRoutes()
            let model = setup(provider)
            let task = try XCTUnwrap(model.searchRoutes())
            await provider.waitForRequest()
            switch mutation {
            case 0: model.bike = .road
            case 1: model.useRoads = 0.1
            case 2: model.useHills = 0.8
            case 3: model.avoidBadSurfaces = 1
            case 4: model.swap()
            default: model.select(Place(name: "C", subtitle: "", coordinate: .init(latitude: 36, longitude: 139)), asOrigin: true)
            }
            await provider.finish(RouteBatch(routes: [try route("old", seconds: 600)], incomplete: false))
            await task.value
            XCTAssertTrue(model.routes.isEmpty)
            XCTAssertNil(model.selectedID)
            XCTAssertFalse(model.isLoading)
        }
    }
    func testBudgetAndSurfaceReconcileWithoutNewRequest() async throws {
        let provider = FixedRoutes(batch: RouteBatch(routes: [try route("fast", seconds: 600),
            try route("slow", seconds: 1200)], incomplete: true))
        let model = setup(provider)
        await model.searchRoutes()?.value
        XCTAssertEqual(model.eligibleRoutes.count, 2)
        XCTAssertNotNil(model.warningMessage)
        model.selectedID = "slow"
        model.extraMinutes = 0
        XCTAssertEqual(model.eligibleRoutes.count, 1)
        XCTAssertEqual(model.selectedID, "fast")
        model.pavedOnly = true
        XCTAssertTrue(model.eligibleRoutes.isEmpty)
        XCTAssertNil(model.selectedID)
        XCTAssertEqual(model.routes.count, 2)
    }
    func testUnconfiguredProviderDoesNotEnableSearch() throws {
        let configuration = try RoutingConfiguration(rawEndpoint: "")
        let model = configuration.makeModel()
        model.origin = Place(name: "A", subtitle: "", coordinate: .init(latitude: 35, longitude: 139))
        model.destination = model.origin
        XCTAssertFalse(model.canSearch)
        XCTAssertFalse(model.isConfigured)
    }
}
