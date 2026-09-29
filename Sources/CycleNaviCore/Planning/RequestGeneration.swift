import Foundation

/// Confines late asynchronous results to the request which created them.
/// Mutate on one actor; this value does not provide synchronization itself.
public struct RequestGeneration: Sendable {
    private var current: UUID?

    public init() {}

    public mutating func begin() -> UUID {
        let token = UUID()
        current = token
        return token
    }

    public func accepts(_ token: UUID) -> Bool { current == token }

    public mutating func cancel() { current = nil }
}
