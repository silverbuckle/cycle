public enum InputError: Error, Equatable, Sendable {
    case invalidValue
}

public enum BikeKind: String, Sendable {
    case road, cross, gravel
}

public enum SurfacePolicy: Equatable, Sendable {
    case pavedOnly, allowUnpaved
}

/// Limits relative to a baseline route. A fraction of 0.2 means 20% extra time.
public enum DetourLimit: Sendable {
    case extraSeconds(Double)
    case fraction(Double)

    public func budget(baselineSeconds: Double) throws -> Double {
        guard baselineSeconds.isFinite, baselineSeconds >= 0 else {
            throw InputError.invalidValue
        }
        let amount: Double
        switch self {
        case .extraSeconds(let value), .fraction(let value): amount = value
        }
        guard amount.isFinite, amount >= 0 else { throw InputError.invalidValue }

        let result: Double
        switch self {
        case .extraSeconds: result = baselineSeconds + amount
        case .fraction: result = baselineSeconds * (1 + amount)
        }
        guard result.isFinite else { throw InputError.invalidValue }
        return result
    }
}

public struct Coordinate: Equatable, Sendable {
    public let latitude: Double
    public let longitude: Double

    public init(latitude: Double, longitude: Double) throws {
        guard latitude.isFinite, longitude.isFinite,
              (-90...90).contains(latitude), (-180...180).contains(longitude) else {
            throw InputError.invalidValue
        }
        self.latitude = latitude
        self.longitude = longitude
    }
}

/// A fixed ride budget and an ordered itinerary, independent of a routing provider.
public struct RouteRequest: Sendable {
    public let origin: Coordinate
    public let destination: Coordinate
    public let orderedStops: [Coordinate]
    public let bike: BikeKind
    public let surface: SurfacePolicy
    public let totalBudgetSeconds: Double
    public let elapsedSeconds: Double

    public var remainingBudgetSeconds: Double {
        max(0, totalBudgetSeconds - elapsedSeconds)
    }

    public init(
        origin: Coordinate, destination: Coordinate, orderedStops: [Coordinate],
        bike: BikeKind, surface: SurfacePolicy, totalBudgetSeconds: Double,
        elapsedSeconds: Double = 0
    ) throws {
        guard totalBudgetSeconds.isFinite, totalBudgetSeconds >= 0,
              elapsedSeconds.isFinite, elapsedSeconds >= 0 else {
            throw InputError.invalidValue
        }
        self.origin = origin
        self.destination = destination
        self.orderedStops = orderedStops
        self.bike = bike
        self.surface = surface
        self.totalBudgetSeconds = totalBudgetSeconds
        self.elapsedSeconds = elapsedSeconds
    }

    /// Elapsed time is measured from ride departure, never from the last reroute.
    /// This preserves every stop; the itinerary owner tracks visited stops separately.
    public func rerouting(from: Coordinate, elapsedSeconds: Double) throws -> RouteRequest {
        guard elapsedSeconds >= self.elapsedSeconds else { throw InputError.invalidValue }
        return try RouteRequest(
            origin: from, destination: destination, orderedStops: orderedStops,
            bike: bike, surface: surface, totalBudgetSeconds: totalBudgetSeconds,
            elapsedSeconds: elapsedSeconds
        )
    }
}
