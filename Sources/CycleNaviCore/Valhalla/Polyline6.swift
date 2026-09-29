public enum Polyline6 {
    public static func decode(_ encoded: String) throws -> [Coordinate] {
        guard encoded.utf8.count <= 2_000_000 else { throw InputError.invalidValue }
        let bytes = Array(encoded.utf8)
        var cursor = 0
        func delta() throws -> Int64 {
            var value: Int64 = 0
            var shift = 0
            while true {
                guard cursor < bytes.count, (63...126).contains(bytes[cursor]), shift <= 60 else {
                    throw InputError.invalidValue
                }
                let byte = Int64(bytes[cursor] - 63)
                cursor += 1
                let payload = byte & 31
                guard shift < 60 || payload <= 7 else { throw InputError.invalidValue }
                value |= payload << shift
                if byte < 32 { return (value & 1) == 1 ? ~(value >> 1) : value >> 1 }
                shift += 5
            }
        }
        var latitude: Int64 = 0
        var longitude: Int64 = 0
        var result: [Coordinate] = []
        while cursor < bytes.count {
            guard result.count < 100_000 else { throw InputError.invalidValue }
            let (lat, latOverflow) = latitude.addingReportingOverflow(try delta())
            let (lon, lonOverflow) = longitude.addingReportingOverflow(try delta())
            guard !latOverflow, !lonOverflow else { throw InputError.invalidValue }
            result.append(try Coordinate(latitude: Double(lat) / 1_000_000,
                                         longitude: Double(lon) / 1_000_000))
            latitude = lat
            longitude = lon
        }
        return result
    }
}
