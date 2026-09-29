import Foundation
@testable import CycleNaviCore

enum ValhallaTestData {
    static let response = Data(#"{"trip":{"status":0,"units":"kilometers","language":"ja-JP","summary":{"length":1.25,"time":600},"legs":[{"shape":"??AA","summary":{"length":1.25,"time":600},"maneuvers":[{"instruction":"直進します","length":1.25,"begin_shape_index":0,"end_shape_index":1,"travel_mode":"bicycle"}]}]}}"#.utf8)
    static func query(bike: BikeKind = .gravel) throws -> CyclingQuery {
        try CyclingQuery(origin: Coordinate(latitude: 35.7, longitude: 139.5),
                         destination: Coordinate(latitude: 35.71, longitude: 139.51),
                         bike: bike, preferences: CyclingPreferences())
    }
}
