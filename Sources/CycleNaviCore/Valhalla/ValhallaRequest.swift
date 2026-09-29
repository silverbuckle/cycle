import Foundation

public struct CyclingPreferences: Equatable, Sendable {
    public let useRoads: Double
    public let useHills: Double
    public let avoidBadSurfaces: Double
    public init(useRoads: Double = 0.25, useHills: Double = 0.25, avoidBadSurfaces: Double = 0.75) throws {
        guard [useRoads, useHills, avoidBadSurfaces].allSatisfy({ $0.isFinite && (0...1).contains($0) })
        else { throw InputError.invalidValue }
        self.useRoads = useRoads
        self.useHills = useHills
        self.avoidBadSurfaces = avoidBadSurfaces
    }
}
public enum CandidateIntent: String, Sendable { case baseline, preferred }
public struct CyclingQuery: Sendable {
    public let origin: Coordinate
    public let destination: Coordinate
    public let bike: BikeKind
    public let preferences: CyclingPreferences
    public init(origin: Coordinate, destination: Coordinate, bike: BikeKind, preferences: CyclingPreferences) {
        self.origin = origin; self.destination = destination
        self.bike = bike; self.preferences = preferences
    }
}

public struct ValhallaRequest: Encodable, Sendable {
    private struct Location: Encodable, Sendable { let lat: Double; let lon: Double }
    private struct Options: Encodable, Sendable {
        let bicycle_type: String
        let cycling_speed: Double
        let use_roads: Double
        let use_hills: Double
        let avoid_bad_surfaces: Double
    }
    private let locations: [Location]
    private let costing = "bicycle"
    private let units = "kilometers"
    private let language = "ja-JP"
    private let alternates = 0
    private let costing_options: [String: Options]

    public init(query: CyclingQuery, intent: CandidateIntent) {
        locations = [query.origin, query.destination].map { Location(lat: $0.latitude, lon: $0.longitude) }
        let profile: (String, Double)
        switch query.bike {
        case .road: profile = ("road", 25)
        case .cross: profile = ("hybrid", 18)
        case .gravel: profile = ("cross", 20)
        }
        costing_options = ["bicycle": Options(bicycle_type: profile.0, cycling_speed: profile.1,
            use_roads: intent == .baseline ? 0.5 : query.preferences.useRoads,
            use_hills: query.preferences.useHills, avoid_bad_surfaces: query.preferences.avoidBadSurfaces)]
    }
}
