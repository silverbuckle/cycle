import Foundation
import Testing
@testable import CycleNaviCore

struct ValhallaResponseTests {
    @Test func normalizesUnitsAndPreservesUncertainty() throws {
        let route = try ValhallaResponse.decode(ValhallaTestData.response, name: "test")
        #expect(route.meters == 1250)
        #expect(route.seconds == 600)
        #expect(route.surface == .unknown)
        #expect(route.instructions[0].meters == 1250)
        #expect(route.instructions[0].shapeIndex == 0)
        #expect(route.coordinates.count == 2)
    }
    @Test(arguments: ["status", "units", "emptyLegs", "twoLegs", "reverse", "outside", "drive", "noMode", "shape", "zeroTime", "emptySteps"])
    func rejectsInvalidResponse(_ mutation: String) throws {
        var root = try JSONSerialization.jsonObject(with: ValhallaTestData.response) as! [String: Any]
        var trip = root["trip"] as! [String: Any]
        var legs = trip["legs"] as! [[String: Any]]
        var steps = legs[0]["maneuvers"] as! [[String: Any]]
        switch mutation {
        case "status": trip["status"] = 1
        case "units": trip["units"] = "miles"
        case "emptyLegs": legs = []
        case "twoLegs": legs.append(legs[0])
        case "reverse": steps[0]["begin_shape_index"] = 1; steps[0]["end_shape_index"] = 0
        case "outside": steps[0]["end_shape_index"] = 2
        case "drive": steps[0]["travel_mode"] = "drive"
        case "noMode": steps[0].removeValue(forKey: "travel_mode")
        case "shape": legs[0]["shape"] = "?"
        case "zeroTime": trip["summary"] = ["length": 1.25, "time": 0]
        default: steps = []
        }
        if !legs.isEmpty { legs[0]["maneuvers"] = steps }
        trip["legs"] = legs
        root["trip"] = trip
        let data = try JSONSerialization.data(withJSONObject: root)
        #expect(throws: RoutingFailure.self) { try ValhallaResponse.decode(data, name: "test") }
    }
}
