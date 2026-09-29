import Foundation

public enum RoutingFailure: Error, Equatable, Sendable {
    case unconfigured, invalidEndpoint, invalidResponse, noRoute, rateLimited
    case http(Int), network, timeout
}

public struct RoutingEndpoint: Sendable {
    public let routeURL: URL
    public init(_ raw: String) throws {
        guard !raw.isEmpty else { throw RoutingFailure.unconfigured }
        guard raw == raw.trimmingCharacters(in: .whitespacesAndNewlines),
              let parts = URLComponents(string: raw), parts.scheme == "https",
              let host = parts.host, !host.isEmpty,
              parts.user == nil, parts.password == nil, parts.query == nil, parts.fragment == nil,
              parts.path.hasSuffix("/route"), let url = parts.url else {
            throw RoutingFailure.invalidEndpoint
        }
        routeURL = url
    }
}
