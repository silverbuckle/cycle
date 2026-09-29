public enum Surface: Equatable, Sendable {
    case paved, unpaved, unknown
}

/// A provider-normalized candidate. False access includes unverified permission.
/// `paved` means the entire route is known paved, not just its first section.
public struct RouteCandidate: Sendable {
    public let id: String
    public let seconds: Double
    public let accessAllowed: Bool
    public let surface: Surface

    public init(id: String, seconds: Double, accessAllowed: Bool, surface: Surface) {
        self.id = id
        self.seconds = seconds
        self.accessAllowed = accessAllowed
        self.surface = surface
    }
}

public struct RouteSelection: Sendable {
    /// Fastest eligible supplied candidate, not a globally optimal route guarantee.
    public let baselineSeconds: Double?
    /// Eligible candidates in provider order. This does not rank comfort or scenery.
    public let candidates: [RouteCandidate]
}

/// Filters access and surface before calculating a detour budget.
/// Pass the original ride's remaining budget on every reroute.
/// Unknown surfaces remain unknown when allowed; consumers must display that fact.
public func selectRoutes(
    _ candidates: [RouteCandidate], surface: SurfacePolicy,
    detour: DetourLimit, remainingBudgetSeconds: Double? = nil
) throws -> RouteSelection {
    _ = try detour.budget(baselineSeconds: 0)
    if let remainingBudgetSeconds {
        guard remainingBudgetSeconds.isFinite, remainingBudgetSeconds >= 0 else {
            throw InputError.invalidValue
        }
    }

    let eligible = candidates.filter {
        $0.accessAllowed && $0.seconds.isFinite && $0.seconds >= 0 &&
        (surface == .allowUnpaved || $0.surface == .paved)
    }
    guard let baseline = eligible.map(\.seconds).min() else {
        return RouteSelection(baselineSeconds: nil, candidates: [])
    }
    let limit = min(
        try detour.budget(baselineSeconds: baseline),
        remainingBudgetSeconds ?? .infinity
    )
    return RouteSelection(
        baselineSeconds: baseline,
        candidates: eligible.filter { $0.seconds <= limit }
    )
}
