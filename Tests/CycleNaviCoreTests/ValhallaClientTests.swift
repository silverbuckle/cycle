import Foundation
import Testing
@testable import CycleNaviCore

private struct ResponseTransport: RouteHTTPTransport {
    let status: Int
    let data: Data
    var failure: URLError.Code? = nil
    func post(url: URL, body: Data) async throws -> (Data, Int) {
        if let failure { throw URLError(failure) }
        return (data, status)
    }
}

struct ValhallaClientTests {
    @Test(arguments: [BikeKind.road, .cross, .gravel]) func vehicleAndComparableTime(_ bike: BikeKind) throws {
        let query = try ValhallaTestData.query(bike: bike)
        for intent in [CandidateIntent.baseline, .preferred] {
            let data = try JSONEncoder().encode(ValhallaRequest(query: query, intent: intent))
            let root = try JSONSerialization.jsonObject(with: data) as! [String: Any]
            #expect(root["costing"] as? String == "bicycle")
            #expect(root["language"] as? String == "ja-JP")
            #expect(root["units"] as? String == "kilometers")
            let opts = (root["costing_options"] as! [String: Any])["bicycle"] as! [String: Any]
            let expected: (String, Double) = bike == .road ? ("road", 25) : bike == .cross ? ("hybrid", 18) : ("cross", 20)
            #expect(opts["bicycle_type"] as? String == expected.0)
            #expect(opts["cycling_speed"] as? Double == expected.1)
            #expect(opts["use_roads"] as? Double == (intent == .baseline ? 0.5 : 0.25))
            #expect(opts["use_hills"] as? Double == 0.25)
            #expect(opts["avoid_bad_surfaces"] as? Double == 0.75)
            let points = root["locations"] as! [[String: Double]]
            #expect(points[0]["lat"] == 35.7)
            #expect(points[1]["lon"] == 139.51)
        }
    }
    @Test(arguments: [-1.0, 1.1, Double.nan, .infinity]) func invalidPreferences(_ n: Double) {
        #expect(throws: InputError.self) { try CyclingPreferences(useRoads: n) }
        #expect(throws: InputError.self) { try CyclingPreferences(useHills: n) }
        #expect(throws: InputError.self) { try CyclingPreferences(avoidBadSurfaces: n) }
    }
    @Test(arguments: [200, 400, 429, 500]) func statusHandling(_ code: Int) async throws {
        let client = try ValhallaClient(endpoint: RoutingEndpoint("https://example.com/route"),
            transport: ResponseTransport(status: code, data: ValhallaTestData.response))
        if code == 200 {
            #expect(try await client.route(ValhallaTestData.query(), intent: .baseline).meters == 1250)
        } else {
            let expected: RoutingFailure = code == 429 ? .rateLimited : .http(code)
            await #expect(throws: expected) { try await client.route(ValhallaTestData.query(), intent: .baseline) }
        }
    }
    @Test(arguments: [URLError.timedOut, .cancelled, .notConnectedToInternet])
    func transportFailures(_ code: URLError.Code) async throws {
        let client = try ValhallaClient(endpoint: RoutingEndpoint("https://example.com/route"),
            transport: ResponseTransport(status: 200, data: Data(), failure: code))
        if code == .cancelled {
            await #expect(throws: CancellationError.self) { try await client.route(ValhallaTestData.query(), intent: .baseline) }
        } else {
            await #expect(throws: code == .timedOut ? RoutingFailure.timeout : .network) {
                try await client.route(ValhallaTestData.query(), intent: .baseline)
            }
        }
    }
    @Test func invalidJSON() async throws {
        let client = try ValhallaClient(endpoint: RoutingEndpoint("https://example.com/route"),
            transport: ResponseTransport(status: 200, data: Data("not json".utf8)))
        await #expect(throws: RoutingFailure.invalidResponse) { try await client.route(ValhallaTestData.query(), intent: .baseline) }
    }
}
