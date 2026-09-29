import SwiftUI
import MapKit
import CycleNaviCore

struct PlannerView: View {
    @State private var model = PlannerModel()
    @State private var location = LocationService()
    @State private var camera: MapCameraPosition = .region(MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 35.675, longitude: 139.47),
        span: MKCoordinateSpan(latitudeDelta: 0.13, longitudeDelta: 0.13)))
    @State private var searchTarget: SearchTarget?
    @State private var showPreferences = false
    @State private var detail: RideRoute?

    private enum SearchTarget: String, Identifiable {
        case origin, destination
        var id: String { rawValue }
    }

    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                header
                map
                    .frame(height: max(190, geometry.size.height * 0.36))
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        title
                        destinationFields
                        preferencesButton
                        if let message = location.message {
                            Label(message, systemImage: "location.slash")
                                .font(.caption).foregroundStyle(Theme.rust)
                        }
                        Button { model.searchRoutes() } label: {
                            HStack(spacing: 10) {
                                if model.isLoading { ProgressView().tint(.white) }
                                Text(model.isLoading ? "道を探しています" : "自転車ルートを探す")
                                if !model.isLoading { Image(systemName: "arrow.right") }
                            }
                        }
                        .buttonStyle(PrimaryButtonStyle())
                        .disabled(!model.canSearch)
                        .opacity(model.canSearch || model.isLoading ? 1 : 0.45)
                        .accessibilityIdentifier("findRoutesButton")
                        routeResults
                        Text("オンライン計画版 · Appleの自転車経路を表示\n路面・交通量の確認と、快適さによる最適化はこれから対応します。")
                            .font(.caption).foregroundStyle(.secondary)
                            .lineSpacing(4)
                    }
                    .padding(24)
                }
                .background(Theme.paper)
            }
            .background(Theme.paper)
        }
        .tint(Theme.forest)
        .preferredColorScheme(.light)
        .sheet(item: $searchTarget) { target in
            PlaceSearchView(title: target == .origin ? "出発地を探す" : "目的地を探す") {
                if target == .origin { location.cancel() }
                model.select($0, asOrigin: target == .origin)
                camera = .automatic
            }
        }
        .sheet(isPresented: $showPreferences) { preferences }
        .sheet(item: $detail) { RouteDetailView(ride: $0) }
        .onChange(of: model.selectedID) { _, _ in camera = .automatic }
        .onChange(of: model.extraMinutes) { _, _ in model.reconcileSelection() }
        .onChange(of: model.pavedOnly) { _, _ in model.reconcileSelection() }
        .onChange(of: location.place?.id) { _, _ in
            if let place = location.place {
                model.select(place, asOrigin: true)
                camera = .automatic
            }
        }
    }

    private var header: some View {
        HStack(spacing: 10) {
            Image(systemName: "bicycle").font(.title2.weight(.semibold))
            Text("CycleNavi").font(.system(.title2, design: .serif).weight(.bold))
            Spacer()
            Text("THE LONG WAY HOME")
                .font(.system(size: 9, weight: .semibold, design: .monospaced))
                .tracking(1.2)
                .accessibilityHidden(true)
        }
        .foregroundStyle(Theme.forest)
        .padding(.horizontal, 24)
        .padding(.vertical, 15)
    }

    private var map: some View {
        Map(position: $camera) {
            if let origin = model.origin {
                Marker(origin.name, systemImage: "circle.circle.fill", coordinate: origin.coordinate)
                    .tint(Theme.forest)
            }
            if let destination = model.destination {
                Marker(destination.name, systemImage: "flag.fill", coordinate: destination.coordinate)
                    .tint(Theme.rust)
            }
            if let selected = model.selected {
                MapPolyline(selected.route.polyline)
                    .stroke(Theme.forest, style: StrokeStyle(lineWidth: 6, lineCap: .round, lineJoin: .round))
            }
        }
        .mapStyle(.standard(elevation: .flat, pointsOfInterest: .excludingAll, showsTraffic: false))
        .mapControls { MapCompass(); MapScaleView() }
        .accessibilityIdentifier("routeMap")
    }

    private var title: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("RIDE YOUR WAY")
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .tracking(2).foregroundStyle(Theme.rust)
            Text("遠回りを、楽しもう。")
                .font(.system(.title2, design: .serif).weight(.semibold))
                .foregroundStyle(Theme.ink)
            Text("いつもの移動も、週末のひと走りも。")
                .font(.subheadline).foregroundStyle(.secondary)
        }
    }

    private var destinationFields: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Button { location.cancel(); searchTarget = .origin } label: {
                    fieldLabel("出発地", value: model.origin?.name ?? "出発地を選ぶ", icon: "circle.circle")
                }
                .accessibilityIdentifier("originButton")
                Button { location.request() } label: {
                    Group {
                        if location.isLocating { ProgressView() }
                        else { Image(systemName: "location.fill") }
                    }
                    .frame(width: 44, height: 44)
                }
                .disabled(location.isLocating)
                .accessibilityLabel("現在地を出発地にする")
                .accessibilityIdentifier("currentLocationButton")
            }
            Divider().padding(.leading, 36)
            HStack(spacing: 12) {
                Button { searchTarget = .destination } label: {
                    fieldLabel("目的地", value: model.destination?.name ?? "どこへ走りますか？", icon: "flag")
                }
                .accessibilityIdentifier("destinationButton")
                Button { location.cancel(); model.swap() } label: {
                    Image(systemName: "arrow.up.arrow.down").frame(width: 44, height: 44)
                }
                .accessibilityLabel("出発地と目的地を入れ替える")
            }
        }
        .padding(.horizontal, 16)
        .background(.white, in: RoundedRectangle(cornerRadius: 18))
    }

    private func fieldLabel(_ title: String, value: String, icon: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon).font(.title3).frame(width: 24)
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.caption).foregroundStyle(.secondary)
                Text(value).font(.subheadline.weight(.medium)).foregroundStyle(Theme.ink)
                    .lineLimit(2).multilineTextAlignment(.leading)
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 14)
        .contentShape(Rectangle())
    }

    private var preferencesButton: some View {
        Button { showPreferences = true } label: {
            HStack {
                Image(systemName: "slider.horizontal.3")
                Text("\(bikeLabel(model.bike)) · ＋\(Int(model.extraMinutes))分まで")
                    .font(.subheadline.weight(.medium))
                Spacer()
                Image(systemName: "chevron.right").font(.caption.weight(.bold))
            }
            .padding(.vertical, 8)
        }
        .accessibilityIdentifier("preferencesButton")
    }

    @ViewBuilder private var routeResults: some View {
        if let error = model.errorMessage {
            Label(error, systemImage: "exclamationmark.circle")
                .font(.subheadline).foregroundStyle(Theme.rust)
                .accessibilityIdentifier("routeError")
        } else if model.hasRequested && !model.isLoading {
            if model.eligibleRoutes.isEmpty {
                Label(model.pavedOnly
                    ? "路面を確認できる候補がありません。Apple経路には路面情報が含まれないため、舗装限定では表示できません。"
                    : "条件に合う候補がありません。条件を見直して再検索してください。",
                    systemImage: "map")
                    .font(.subheadline).foregroundStyle(Theme.rust)
            } else {
                VStack(alignment: .leading, spacing: 12) {
                    Text("今日のルート").font(.title3.weight(.semibold))
                    ForEach(Array(model.eligibleRoutes.enumerated()), id: \.element.id) { index, ride in
                        routeCard(ride, index: index)
                    }
                    if let selected = model.selected {
                        Button { detail = selected } label: {
                            Label("道順と音声を確認", systemImage: "list.bullet")
                                .font(.headline).frame(maxWidth: .infinity).padding(14)
                        }
                        .background(.white, in: RoundedRectangle(cornerRadius: 14))
                        .accessibilityIdentifier("routeDetailsButton")
                    }
                }
            }
        }
    }

    private func routeCard(_ ride: RideRoute, index: Int) -> some View {
        Button { model.selectedID = ride.id } label: {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text(index == 0 ? "取得候補の中で最短" : "別の道を通るルート")
                        .font(.caption.weight(.semibold))
                    Spacer()
                    Image(systemName: model.selectedID == ride.id ? "checkmark.circle.fill" : "circle")
                }
                HStack(alignment: .firstTextBaseline, spacing: 14) {
                    Text(RideFormat.duration(ride.route.expectedTravelTime)).font(.title2.weight(.bold))
                    Text(RideFormat.distance(ride.route.distance)).font(.subheadline)
                    Spacer(minLength: 0)
                }
                Text(ride.route.name).font(.subheadline).lineLimit(2)
                Text("路面・交通量は未確認" + extraTime(ride))
                    .font(.caption).foregroundStyle(.secondary)
            }
            .foregroundStyle(Theme.ink)
            .padding(17)
            .background(.white, in: RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16)
                .stroke(model.selectedID == ride.id ? Theme.forest : .clear, lineWidth: 2))
        }
        .buttonStyle(.plain)
    }

    private func extraTime(_ ride: RideRoute) -> String {
        guard let fastest = model.fastestSeconds else { return "" }
        let extra = Int(ceil(max(0, ride.route.expectedTravelTime - fastest) / 60))
        return extra > 0 ? " · 最短候補より＋\(extra)分" : ""
    }

    private var preferences: some View {
        NavigationStack {
            Form {
                Section("あなたの自転車") {
                    Picker("車種", selection: $model.bike) {
                        Text("ロード").tag(BikeKind.road)
                        Text("クロス").tag(BikeKind.cross)
                        Text("グラベル").tag(BikeKind.gravel)
                    }
                    .pickerStyle(.segmented)
                    Text("車種はこの計画での設定です。現在のApple経路は車種別の最適化に対応していません。")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Section("遠回りの許容度") {
                    HStack {
                        Text("追加時間")
                        Spacer()
                        Text("＋\(Int(model.extraMinutes))分まで").bold()
                    }
                    Slider(value: $model.extraMinutes, in: 0...60, step: 5)
                        .accessibilityLabel("遠回りの追加時間")
                        .accessibilityIdentifier("detourSlider")
                    Text("取得した自転車経路の最短候補を基準にします。走行時間は目安です。")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Section("路面") {
                    Toggle("舗装が確認できる道だけ", isOn: $model.pavedOnly)
                        .accessibilityIdentifier("pavedOnlyToggle")
                    Text("オフの場合は路面未確認の候補も含みます。オンの場合、現在のApple経路は路面未確認のため候補を表示できません。")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            .scrollContentBackground(.hidden)
            .background(Theme.paper)
            .navigationTitle("自転車と道の好み")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) {
                Button("完了") { showPreferences = false }
            } }
        }
    }

    private func bikeLabel(_ bike: BikeKind) -> String {
        switch bike {
        case .road: "ロード"
        case .cross: "クロス"
        case .gravel: "グラベル"
        }
    }
}
