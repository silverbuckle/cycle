public enum RouteProvider: String, Sendable { case apple, valhalla }

public struct RouteInstruction: Sendable {
    public let text: String
    public let meters: Double
    public let shapeIndex: Int?

    public init(text: String, meters: Double, shapeIndex: Int?) throws {
        guard meters.isFinite, meters >= 0, shapeIndex.map({ $0 >= 0 }) ?? true else {
            throw InputError.invalidValue
        }
        self.text = text
        self.meters = meters
        self.shapeIndex = shapeIndex
    }
}

/// A provider's cycling route, not a guarantee of present-day legal access or road condition.
public struct PlannedRoute: Identifiable, Sendable {
    public let id: String
    public let provider: RouteProvider
    public let name: String
    public let coordinates: [Coordinate]
    public let seconds: Double
    public let meters: Double
    public let instructions: [RouteInstruction]
    public let surface: Surface

    public init(id: String, provider: RouteProvider, name: String,
                coordinates: [Coordinate], seconds: Double, meters: Double,
                instructions: [RouteInstruction], surface: Surface) throws {
        guard !id.isEmpty, coordinates.count >= 2,
              seconds.isFinite, seconds > 0, meters.isFinite, meters > 0,
              instructions.allSatisfy({ $0.shapeIndex.map { coordinates.indices.contains($0) } ?? true })
        else { throw InputError.invalidValue }
        self.id = id
        self.provider = provider
        self.name = name
        self.coordinates = coordinates
        self.seconds = seconds
        self.meters = meters
        self.instructions = instructions
        self.surface = surface
    }
}
