import SwiftUI
import CycleNaviCore

struct PlaceSearchView: View {
    let title: String
    let onSelect: (Place) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""
    @State private var places: [Place] = []
    @State private var message: String?
    @State private var loading = false
    @State private var requests = RequestGeneration()
    @FocusState private var focused: Bool

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                HStack {
                    Image(systemName: "magnifyingglass").foregroundStyle(Theme.forest)
                    TextField("駅・公園・お店・住所", text: $query)
                        .accessibilityIdentifier("placeSearchField")
                        .submitLabel(.search)
                        .focused($focused)
                        .autocorrectionDisabled()
                    if !query.isEmpty {
                        Button { query = "" } label: { Image(systemName: "xmark.circle.fill") }
                            .accessibilityLabel("検索文字を消す")
                    }
                }
                .padding(16)
                .background(.white, in: RoundedRectangle(cornerRadius: 14))
                .padding()

                if loading {
                    ProgressView("場所を探しています").padding(30)
                } else if let message {
                    ContentUnavailableView(message, systemImage: "map")
                } else if query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    ContentUnavailableView("次の目的地を見つけよう", systemImage: "bicycle",
                        description: Text("駅や公園の名前、住所から探せます。"))
                }

                List(places) { place in
                    Button {
                        onSelect(place)
                        dismiss()
                    } label: {
                        HStack(spacing: 14) {
                            Image(systemName: "mappin.circle")
                                .font(.title2).foregroundStyle(Theme.forest)
                            VStack(alignment: .leading, spacing: 5) {
                                Text(place.name).font(.headline).foregroundStyle(Theme.ink)
                                Text(place.subtitle).font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Image(systemName: "arrow.up.left").foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 5)
                    }
                    .listRowBackground(Color.white.opacity(0.7))
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .scrollDismissesKeyboard(.interactively)
            }
            .background(Theme.paper)
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("閉じる") { dismiss() } }
            }
            .task { focused = true }
            .task(id: query) { await search() }
            .onDisappear { requests.cancel() }
        }
        .tint(Theme.forest)
    }

    @MainActor private func search() async {
        let token = requests.begin()
        places = []
        message = nil
        let value = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { loading = false; return }
        loading = true
        do {
            try await Task.sleep(for: .milliseconds(400))
            let result = try await AppleRouteService().search(value)
            guard !Task.isCancelled, requests.accepts(token) else { return }
            places = result
            loading = false
            if result.isEmpty { message = "場所が見つかりませんでした" }
        } catch {
            guard !Task.isCancelled, requests.accepts(token) else { return }
            loading = false
            message = "検索できませんでした。通信状態をご確認ください。"
        }
    }
}
