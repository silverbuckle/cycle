public enum Cue: Equatable, Sendable {
    case advance, immediate
}

/// Emits guidance events; does not play audio or determine the next maneuver.
/// Thresholds are initial test values, not validated for real-world navigation.
public struct CueScheduler: Sendable {
    private var currentRoute: String?
    private var advanced: Set<String> = []
    private var immediate: Set<String> = []

    public init() {}

    /// - Parameters:
    ///   - routeID: Unique route revision. Caller must discard obsolete async samples.
    ///   - turnID: Unique maneuver occurrence, including on repeated loop segments.
    ///   - meters: Remaining distance along the matched route, not straight-line distance.
    ///   - accuracyMeters: Location accuracy. Negative/unknown accuracy suppresses cues.
    ///   - sampleAgeSeconds: Age derived from a monotonic clock.
    /// - Returns: At most one event per stage and maneuver. Event emission is not
    ///   confirmation of audio playback; interruptions/retries belong to the audio owner.
    public mutating func next(
        routeID: String, turnID: String, meters: Double,
        accuracyMeters: Double, sampleAgeSeconds: Double
    ) -> Cue? {
        guard !routeID.isEmpty, !turnID.isEmpty,
              meters.isFinite, meters >= 0,
              accuracyMeters.isFinite, accuracyMeters >= 0, accuracyMeters <= 30,
              sampleAgeSeconds.isFinite, sampleAgeSeconds >= 0, sampleAgeSeconds <= 10 else {
            return nil
        }

        if currentRoute != routeID {
            currentRoute = routeID
            advanced.removeAll()
            immediate.removeAll()
        }
        guard !immediate.contains(turnID) else { return nil }
        if meters <= 30 {
            immediate.insert(turnID)
            advanced.insert(turnID)
            return .immediate
        }
        if meters <= 200 && !advanced.contains(turnID) {
            advanced.insert(turnID)
            return .advance
        }
        return nil
    }
}
