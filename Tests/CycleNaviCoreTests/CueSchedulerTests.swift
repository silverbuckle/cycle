import Testing
@testable import CycleNaviCore

struct CueSchedulerTests {
    @Test func poorLocationDoesNotConsumeCue() {
        var scheduler = CueScheduler()
        #expect(scheduler.next(routeID: "r", turnID: "t", meters: 180,
            accuracyMeters: 100, sampleAgeSeconds: 0) == nil)
        #expect(scheduler.next(routeID: "r", turnID: "t", meters: 180,
            accuracyMeters: 5, sampleAgeSeconds: 20) == nil)
        #expect(scheduler.next(routeID: "r", turnID: "t", meters: 180,
            accuracyMeters: 5, sampleAgeSeconds: 0) == .advance)
    }

    // Catches repeated announcements when measured progress moves backwards.
    @Test func jitterDoesNotRepeatOrReverseCues() {
        var scheduler = CueScheduler()
        #expect(scheduler.next(routeID: "r", turnID: "t", meters: 20,
            accuracyMeters: 5, sampleAgeSeconds: 0) == .immediate)
        #expect(scheduler.next(routeID: "r", turnID: "t", meters: 100,
            accuracyMeters: 5, sampleAgeSeconds: 0) == nil)
        #expect(scheduler.next(routeID: "r", turnID: "t", meters: 20,
            accuracyMeters: 5, sampleAgeSeconds: 0) == nil)
        #expect(scheduler.next(routeID: "new", turnID: "t", meters: 180,
            accuracyMeters: 5, sampleAgeSeconds: 0) == .advance)
    }

    @Test(arguments: [-1.0, Double.nan, Double.infinity, -Double.infinity])
    func invalidSamplesAreSuppressed(_ bad: Double) {
        var scheduler = CueScheduler()
        #expect(scheduler.next(routeID: "r", turnID: "t", meters: bad,
            accuracyMeters: 5, sampleAgeSeconds: 0) == nil)
        #expect(scheduler.next(routeID: "r", turnID: "t", meters: 20,
            accuracyMeters: bad, sampleAgeSeconds: 0) == nil)
        #expect(scheduler.next(routeID: "r", turnID: "t", meters: 20,
            accuracyMeters: 5, sampleAgeSeconds: bad) == nil)
        #expect(scheduler.next(routeID: "r", turnID: "t", meters: 20,
            accuracyMeters: 5, sampleAgeSeconds: 0) == .immediate)
    }

    @Test func progressEmitsTwoCuesOnce() {
        var scheduler = CueScheduler()
        let distances = [300.0, 200, 210, 180, 31, 30, 29, 0]
        let actual = distances.map {
            scheduler.next(routeID: "r", turnID: "t", meters: $0,
                accuracyMeters: 5, sampleAgeSeconds: 0)
        }
        #expect(actual == [nil, .advance, nil, nil, nil, .immediate, nil, nil])
    }

    @Test func eachTurnHasIndependentAnnouncementState() {
        var scheduler = CueScheduler()
        #expect(scheduler.next(routeID: "r", turnID: "one", meters: 20,
            accuracyMeters: 5, sampleAgeSeconds: 0) == .immediate)
        #expect(scheduler.next(routeID: "r", turnID: "two", meters: 180,
            accuracyMeters: 5, sampleAgeSeconds: 0) == .advance)
        #expect(scheduler.next(routeID: "r", turnID: "one", meters: 20,
            accuracyMeters: 5, sampleAgeSeconds: 0) == nil)
    }

    @Test func rejectsMissingIdentifiers() {
        var scheduler = CueScheduler()
        #expect(scheduler.next(routeID: "", turnID: "t", meters: 20,
            accuracyMeters: 5, sampleAgeSeconds: 0) == nil)
        #expect(scheduler.next(routeID: "r", turnID: "", meters: 20,
            accuracyMeters: 5, sampleAgeSeconds: 0) == nil)
    }

    @Test func locationQualityBoundariesDoNotConsumeCue() {
        var scheduler = CueScheduler()
        #expect(scheduler.next(routeID: "r", turnID: "t", meters: 20,
            accuracyMeters: 30.01, sampleAgeSeconds: 0) == nil)
        #expect(scheduler.next(routeID: "r", turnID: "t", meters: 20,
            accuracyMeters: 30, sampleAgeSeconds: 10.01) == nil)
        #expect(scheduler.next(routeID: "r", turnID: "t", meters: 20,
            accuracyMeters: 30, sampleAgeSeconds: 10) == .immediate)
    }

    @Test func invalidSampleDoesNotResetRouteHistory() {
        var scheduler = CueScheduler()
        #expect(scheduler.next(routeID: "r", turnID: "t", meters: 180,
            accuracyMeters: 5, sampleAgeSeconds: 0) == .advance)
        #expect(scheduler.next(routeID: "other", turnID: "t", meters: 180,
            accuracyMeters: 5, sampleAgeSeconds: 20) == nil)
        #expect(scheduler.next(routeID: "r", turnID: "t", meters: 180,
            accuracyMeters: 5, sampleAgeSeconds: 0) == nil)
    }
}
