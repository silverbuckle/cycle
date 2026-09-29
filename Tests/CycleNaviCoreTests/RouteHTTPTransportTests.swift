import Foundation
import Testing
@testable import CycleNaviCore

private final class CapturedRequest: @unchecked Sendable {
    private let lock = NSLock()
    private var value: URLRequest?
    func store(_ request: URLRequest) { lock.lock(); defer { lock.unlock() }; value = request }
    func get() -> URLRequest? { lock.lock(); defer { lock.unlock() }; return value }
}
private final class LocalRouteProtocol: URLProtocol, @unchecked Sendable {
    static let captured = CapturedRequest()
    override class func canInit(with request: URLRequest) -> Bool { request.url?.host == "test.invalid" }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        Self.captured.store(request)
        client?.urlProtocol(self, didReceive: HTTPURLResponse(url: request.url!, statusCode: 200,
            httpVersion: nil, headerFields: nil)!, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Data("{}".utf8))
        client?.urlProtocolDidFinishLoading(self)
    }
    override func stopLoading() {}
}
struct RouteHTTPTransportTests {
    @Test func pacingReservesSeparateSlotsForConcurrentRequests() async {
        let pacer = RouteRequestPacer()
        let now = ContinuousClock.now
        let first = await pacer.reserve(now: now)
        let second = await pacer.reserve(now: now)
        let third = await pacer.reserve(now: now)
        #expect(first == now)
        #expect(first.duration(to: second) == .milliseconds(1100))
        #expect(first.duration(to: third) == .milliseconds(2200))
    }
    @Test func usesPrivatePOST() async throws {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [LocalRouteProtocol.self]
        let transport = URLSessionRouteTransport(configuration: config)
        let (data, status) = try await transport.post(url: URL(string: "https://test.invalid/route")!, body: Data("{}".utf8))
        #expect(status == 200)
        #expect(data == Data("{}".utf8))
        let request = try #require(LocalRouteProtocol.captured.get())
        #expect(request.httpMethod == "POST")
        #expect(request.value(forHTTPHeaderField: "Content-Type") == "application/json")
        #expect(request.value(forHTTPHeaderField: "User-Agent")?.contains("CycleNavi") == true)
        #expect(request.value(forHTTPHeaderField: "X-Client-Id") == "jp.artico.cyclenavi.development")
        #expect(request.cachePolicy == .reloadIgnoringLocalCacheData)
        #expect(request.timeoutInterval == 30)
        // URLSession may expose the POST body as a stream to URLProtocol.
        if let body = request.httpBody { #expect(body == Data("{}".utf8)) }
        else {
            let stream = try #require(request.httpBodyStream)
            stream.open(); defer { stream.close() }
            var bytes = [UInt8](repeating: 0, count: 16)
            let count = stream.read(&bytes, maxLength: bytes.count)
            #expect(count == 2)
            #expect(Array(bytes.prefix(2)) == [123, 125])
        }
    }
    @Test func refusesRedirectBeforeResendingLocation() async throws {
        let delegate = RouteSessionDelegate()
        let session = URLSession(configuration: .ephemeral)
        defer { session.invalidateAndCancel() }
        let url = URL(string: "https://test.invalid/route")!
        let task = session.dataTask(with: url)
        let result: URLRequest? = await withCheckedContinuation { continuation in
            delegate.urlSession(session, task: task,
                willPerformHTTPRedirection: HTTPURLResponse(url: url, statusCode: 307, httpVersion: nil, headerFields: nil)!,
                newRequest: URLRequest(url: URL(string: "https://other.invalid/route")!)) {
                    continuation.resume(returning: $0)
                }
        }
        #expect(result == nil)
    }
}
