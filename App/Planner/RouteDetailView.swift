import SwiftUI

struct RouteDetailView: View {
    let ride: RideRoute
    @Environment(\.dismiss) private var dismiss
    @State private var speech = SpeechService()

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text(ride.route.name).font(.title3.weight(.semibold))
                    Label("\(RideFormat.distance(ride.route.distance)) · 約\(RideFormat.duration(ride.route.expectedTravelTime))",
                          systemImage: "bicycle")
                    Text("案内文をタップすると読み上げます。現在地に応じた自動ナビはまだ接続していません。")
                        .font(.caption).foregroundStyle(.secondary)
                    if let error = speech.errorMessage {
                        Text(error).font(.caption).foregroundStyle(Theme.rust)
                    }
                }
                Section("道順") {
                    ForEach(Array(ride.route.steps.enumerated()), id: \.offset) { index, step in
                        if !step.instructions.isEmpty {
                            Button { speech.speak(step.instructions) } label: {
                                HStack(alignment: .top, spacing: 14) {
                                    Text(String(index + 1)).font(.caption.monospacedDigit())
                                        .frame(width: 25, height: 25)
                                        .background(Theme.forest.opacity(0.1), in: Circle())
                                    VStack(alignment: .leading, spacing: 6) {
                                        Text(step.instructions).foregroundStyle(Theme.ink)
                                        Text(RideFormat.distance(step.distance)).font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    Spacer(minLength: 0)
                                    Image(systemName: "speaker.wave.2")
                                }
                                .padding(.vertical, 6)
                            }
                        }
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Theme.paper)
            .navigationTitle("ルートの道順")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("閉じる") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("音声停止") { speech.stop() } }
            }
            .onDisappear { speech.stop() }
        }
        .tint(Theme.forest)
    }
}
