import Foundation

public protocol RouteHTTPTransport: Sendable {
    func post(url: URL, body: Data) async throws -> (Data, Int)
}

final class RouteSessionDelegate: NSObject, URLSessionTaskDelegate, Sendable {
    func urlSession(_ session: URLSession, task: URLSessionTask,
                    willPerformHTTPRedirection response: HTTPURLResponse, newRequest request: URLRequest,
                    completionHandler: @escaping @Sendable (URLRequest?) -> Void) {
        completionHandler(nil)
    }
}

public struct URLSessionRouteTransport: RouteHTTPTransport {
    private let session: URLSession
    public init(configuration: URLSessionConfiguration = .ephemeral) {
        configuration.urlCache = nil
        configuration.httpCookieStorage = nil
        configuration.urlCredentialStorage = nil
        session = URLSession(configuration: configuration, delegate: RouteSessionDelegate(), delegateQueue: nil)
    }
    public func post(url: URL, body: Data) async throws -> (Data, Int) {
        var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 30)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = body
        let (data, response) = try await session.data(for: request)
        guard let response = response as? HTTPURLResponse else { throw RoutingFailure.invalidResponse }
        return (data, response.statusCode)
    }
}

public struct ValhallaClient: Sendable {
    private let endpoint: RoutingEndpoint
    private let transport: any RouteHTTPTransport
    public init(endpoint: RoutingEndpoint, transport: any RouteHTTPTransport) {
        self.endpoint = endpoint; self.transport = transport
    }
    public func route(_ query: CyclingQuery, intent: CandidateIntent) async throws -> PlannedRoute {
        do {
            try Task.checkCancellation()
            let body = try JSONEncoder().encode(ValhallaRequest(query: query, intent: intent))
            let (data, status) = try await transport.post(url: endpoint.routeURL, body: body)
            try Task.checkCancellation()
            guard status != 429 else { throw RoutingFailure.rateLimited }
            guard status == 200 else { throw RoutingFailure.http(status) }
            return try ValhallaResponse.decode(data, name: intent == .baseline ? "基準候補" : "車道回避設定の候補")
        } catch is CancellationError { throw CancellationError() }
        catch let error as RoutingFailure { throw error }
        catch let error as URLError {
            if error.code == .cancelled { throw CancellationError() }
            throw error.code == .timedOut ? RoutingFailure.timeout : .network
        } catch { throw RoutingFailure.network }
    }
}
