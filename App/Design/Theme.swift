import SwiftUI

enum Theme {
    static let paper = Color(red: 0.97, green: 0.96, blue: 0.93)
    static let forest = Color(red: 0.13, green: 0.29, blue: 0.22)
    static let ink = Color(red: 0.16, green: 0.19, blue: 0.17)
    static let rust = Color(red: 0.65, green: 0.29, blue: 0.15)
}

struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 17)
            .foregroundStyle(.white)
            .background(Theme.forest.opacity(configuration.isPressed ? 0.75 : 1))
            .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

enum RideFormat {
    static func duration(_ seconds: Double) -> String {
        let minutes = max(1, Int((seconds / 60).rounded(.up)))
        return minutes < 60 ? "\(minutes)分" : "\(minutes / 60)時間\(minutes % 60)分"
    }
    static func distance(_ meters: Double) -> String {
        meters < 1000 ? "\(Int(meters.rounded())) m" : String(format: "%.1f km", meters / 1000)
    }
}
