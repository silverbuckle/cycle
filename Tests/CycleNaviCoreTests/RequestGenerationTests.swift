import Foundation
import Testing
@testable import CycleNaviCore

struct RequestGenerationTests {
    @Test func newestRequestWins() {
        var requests = RequestGeneration()
        let first = requests.begin()
        #expect(requests.accepts(first))
        let second = requests.begin()
        #expect(!requests.accepts(first))
        #expect(requests.accepts(second))
    }

    @Test func cancellationRejectsOutstandingResponse() {
        var requests = RequestGeneration()
        let token = requests.begin()
        requests.cancel()
        #expect(!requests.accepts(token))
        #expect(!requests.accepts(UUID()))
        let next = requests.begin()
        #expect(requests.accepts(next))
        #expect(!requests.accepts(token))
    }
}
