import Foundation

public enum ValhallaResponse {
    private struct Envelope: Decodable { let trip: Trip }
    private struct Trip: Decodable {
        let status: Int
        let units: String
        let summary: Summary
        let legs: [Leg]
    }
    private struct Summary: Decodable { let length: Double; let time: Double }
    private struct Leg: Decodable { let shape: String; let maneuvers: [Maneuver] }
    private struct Maneuver: Decodable {
        let instruction: String
        let length: Double
        let begin_shape_index: Int
        let end_shape_index: Int
        let travel_mode: String
    }
    public static func decode(_ data: Data, name: String) throws -> PlannedRoute {
        do {
            guard data.count <= 8_000_000 else { throw RoutingFailure.invalidResponse }
            let trip = try JSONDecoder().decode(Envelope.self, from: data).trip
            guard trip.status == 0 else { throw RoutingFailure.noRoute }
            guard trip.units == "kilometers", trip.legs.count == 1 else { throw RoutingFailure.invalidResponse }
            let leg = trip.legs[0]
            let coordinates = try Polyline6.decode(leg.shape)
            guard !leg.maneuvers.isEmpty else { throw RoutingFailure.invalidResponse }
            let instructions = try leg.maneuvers.map { step in
                guard ["bicycle", "pedestrian"].contains(step.travel_mode),
                      coordinates.indices.contains(step.begin_shape_index),
                      coordinates.indices.contains(step.end_shape_index),
                      step.begin_shape_index <= step.end_shape_index else { throw RoutingFailure.invalidResponse }
                let text = step.travel_mode == "pedestrian" ? "押し歩き：\(step.instruction)" : step.instruction
                return try RouteInstruction(text: text, meters: step.length * 1000, shapeIndex: step.begin_shape_index)
            }
            return try PlannedRoute(id: UUID().uuidString, provider: .valhalla, name: name,
                coordinates: coordinates, seconds: trip.summary.time, meters: trip.summary.length * 1000,
                instructions: instructions, surface: .unknown)
        } catch let error as RoutingFailure { throw error }
        catch { throw RoutingFailure.invalidResponse }
    }
}
