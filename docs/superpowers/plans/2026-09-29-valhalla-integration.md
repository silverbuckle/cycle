# MapKit + Valhalla Integration Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox syntax for tracking.

**Goal:** MapKitの表示・検索を維持し、Valhallaの自転車経路を車種・好み・遠回り上限付きで表示する。

**Architecture:** MKRoute依存をプロバイダー非依存の経路モデルへ置換。ValhallaのHTTP/JSON変換と候補生成を分離し、既存の世代管理・遠回りフィルターへ接続する。Appleは比較用アダプターとして残す。

**Tech Stack:** 既存Swift 6パッケージ、SwiftUI iOS 18以上、MapKit、URLSession、XcodeGen。新しい外部ライブラリなし。

**Spec:** `docs/superpowers/specs/2026-09-29-valhalla-integration-design.md`

## Global Constraints

- MapKitの地図・地点検索を残し、Valhallaの自転車経路を表示する。
- API成功だけで走りやすさや実走ナビの完成を宣言しない。
- 悪路回避設定は舗装確認の代用にしない。
- 公開デモを製品の恒久バックエンドにしない。クラウド契約・有料利用・公開配備は今回行わない。
- 実通信の開始前に送信先を確認し、位置情報をログへ恒久保存しない。
- Appleの帰属表示を維持し、OSM由来経路にはOSM contributorsへの帰属も表示する。
- 初期実装は2地点/1 leg。中間地点・複数日旅を黙って切り捨てず対象外とする。
- 自動ナビ、オフライン、店舗/投稿、サーバー本番運用は今回の対象外。

## Review Focus

1. routeのshapeと道順indexが食い違う応答を表示しない（Task 1/2）。
2. 車種を変更した後に古い経路が戻っても採用しない（Task 4）。
3. 片方の候補生成だけ失敗した場合、不完全な比較と表示する（Task 3/4）。
4. 任意URLへの誤送信、redirectでの位置漏洩、URL内認証情報を防ぐ（Task 2/4）。
5. 通信不可・路面unknownを成功/安全/舗装済みの画面に変換しない（Task 2/4/5）。

## ファイル構造と実行環境

Core/Routingは経路値型、Core/Valhallaは要求・応答・通信・候補生成を担当。
App/PlannerはMapKit変換、画面と状態を担当。型名は既存RouteRequest（走行予算）と区別する。
各タスクでRED→最小実装→GREEN→コミット。テストは時刻sleepで同期せず、制御可能な偽応答を使う。

```sh
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
swift test
swift build -c release
xcodegen generate
xcodebuild -project CycleNavi.xcodeproj -scheme CycleNavi \
  -destination 'platform=iOS Simulator,id=89584396-A924-4661-9698-1ADD85DF3D11' \
  -derivedDataPath .build/iphone CODE_SIGNING_ALLOWED=NO test
```

既存ブランチのユーザー変更を保護し、実行前にgit statusを確認する。接続先はまだ未選定。
これは実通信の前提条件であり、単体テストやアプリ接続コード作成の前提条件ではない。

## Task 1: 共通経路モデルとpolyline6

**Files:** Create `Sources/CycleNaviCore/Routing/PlannedRoute.swift`, `Sources/CycleNaviCore/Valhalla/Polyline6.swift`; Test `Tests/CycleNaviCoreTests/PlannedRouteTests.swift`, `Tests/CycleNaviCoreTests/Polyline6Tests.swift`。

**Interfaces:** 既存Coordinate/Surfaceを使用。全型Sendable、配列を含む値型。

```swift
public enum RouteProvider: String, Sendable { case apple, valhalla }
public struct RouteInstruction: Sendable {
    public let text: String
    public let meters: Double
    public let shapeIndex: Int? // Appleで対応index不明ならnil
    public init(text: String, meters: Double, shapeIndex: Int?) throws
}
public struct PlannedRoute: Identifiable, Sendable {
    public let id: String
    public let provider: RouteProvider
    public let name: String
    public let coordinates: [Coordinate]
    public let seconds: Double
    public let meters: Double
    public let instructions: [RouteInstruction]
    public let surface: Surface
    public init(id: String, provider: RouteProvider, name: String,
                coordinates: [Coordinate], seconds: Double, meters: Double,
                instructions: [RouteInstruction], surface: Surface) throws
}
public enum Polyline6 {
    public static func decode(_ encoded: String) throws -> [Coordinate]
}
```

- [ ] RED：2点の独立した既知ベクトル、負の差分、切れたペア、過長varint、ASCII範囲外、加算overflow、緯度範囲外をテストする。
```swift
@Test func decodesMicrodegrees() throws {
    #expect(try Polyline6.decode("??AA") == [
        Coordinate(latitude: 0, longitude: 0),
        Coordinate(latitude: 0.000001, longitude: 0.000001)
    ])
}
@Test func rejectsTruncatedPair() {
    #expect(throws: InputError.self) { try Polyline6.decode("?") }
}
```
- [ ] `swift test --filter Polyline6Tests`で未実装による失敗を記録する。
- [ ] 5bit continuation/zigzag差分をInt64で復号。加算/shiftはoverflowを検査。座標は1e6で割る。最大100000点、入力最大2MB。不正はInputError.invalidValue。
```swift
let delta = (value & 1) == 1 ? ~(value >> 1) : (value >> 1)
let (next, overflow) = accumulated.addingReportingOverflow(delta)
guard !overflow else { throw InputError.invalidValue }
```
- [ ] モデルは非空ID、2点以上、距離/時間が有限かつ正、道順距離は有限かつ非負、非nil indexは座標配列内を強制する。各境界の失敗テストを追加。
- [ ] 全coreテストGREENを確認し、上記4ファイルをコミット。

## Task 2: Valhallaの要求・応答とHTTP境界

**Files:** Create `Sources/CycleNaviCore/Valhalla/ValhallaRequest.swift`, `ValhallaResponse.swift`, `ValhallaClient.swift`, `RoutingEndpoint.swift`（いずれも同ディレクトリ）。Test `Tests/CycleNaviCoreTests/ValhallaClientTests.swift`, `ValhallaResponseTests.swift`, `RoutingEndpointTests.swift`。

**Interfaces:**
```swift
public struct CyclingPreferences: Equatable, Sendable {
    public let useRoads: Double
    public let useHills: Double
    public let avoidBadSurfaces: Double
    public init(useRoads: Double = 0.25, useHills: Double = 0.25,
                avoidBadSurfaces: Double = 0.75) throws // 各0...1、finite
}
public enum CandidateIntent: String, Sendable { case baseline, preferred }
public struct CyclingQuery: Sendable {
    public let origin: Coordinate
    public let destination: Coordinate
    public let bike: BikeKind
    public let preferences: CyclingPreferences
    public init(origin: Coordinate, destination: Coordinate, bike: BikeKind,
                preferences: CyclingPreferences)
}
public enum RoutingFailure: Error, Equatable, Sendable {
    case unconfigured, invalidEndpoint, invalidResponse, noRoute, rateLimited
    case http(Int), network, timeout
}
public struct RoutingEndpoint: Sendable {
    public let routeURL: URL
    public init(_ raw: String) throws
}
public protocol RouteHTTPTransport: Sendable {
    func post(url: URL, body: Data) async throws -> (Data, Int)
}
public struct ValhallaRequest: Encodable, Sendable {
    public init(query: CyclingQuery, intent: CandidateIntent)
}
public enum ValhallaResponse {
    public static func decode(_ data: Data, name: String) throws -> PlannedRoute
}
public struct ValhallaClient: Sendable {
    public init(endpoint: RoutingEndpoint, transport: any RouteHTTPTransport)
    public func route(_ query: CyclingQuery, intent: CandidateIntent) async throws -> PlannedRoute
}
```

- [ ] RED：JSONEncoder→JSONSerializationで`costing=bicycle`、road→road/cross→hybrid/gravel→cross、言語ja-JP、units=kilometersを検証。speedは車種別25/18/20km/hで固定し、同一比較中は変えない。
- [ ] baselineはuse_roads=0.5、preferredは利用者指定値。use_hills/avoid_bad_surfacesは両方とも指定値。他cost/penaltyは双方同じ。alternates=0とし2要求だけで開始。
```json
{"locations":[{"lat":35.7,"lon":139.5},{"lat":35.71,"lon":139.51}],"costing":"bicycle","costing_options":{"bicycle":{"bicycle_type":"cross","cycling_speed":20,"use_roads":0.25,"use_hills":0.25,"avoid_bad_surfaces":0.75}},"units":"kilometers","language":"ja-JP","alternates":0}
```
- [ ] RED：以下の合成fixtureで1250m/600秒/unknownを確認。実在ルートとは表示・記録しない。
```swift
let fixture = Data(#"{"trip":{"status":0,"units":"kilometers","language":"ja-JP","summary":{"length":1.25,"time":600},"legs":[{"shape":"??AA","summary":{"length":1.25,"time":600},"maneuvers":[{"instruction":"直進します","length":1.25,"begin_shape_index":0,"end_shape_index":1,"travel_mode":"bicycle"}]}]}}"#.utf8)
let route = try ValhallaResponse.decode(fixture, name: "検証用")
#expect(route.meters == 1250)
#expect(route.seconds == 600)
#expect(route.surface == .unknown)
```
- [ ] 同fixtureをJSONSerializationで変形：status非0、空legs、2legs、units不明、maneuver index逆転/範囲外、travel_mode=drive、shape破損をそれぞれ拒否。bicycle/pedestrian（押し歩き案内）以外を拒否し、欠落modeも未確認として拒否する。
- [ ] RED：偽transportが200/400/429/500/タイムアウト/キャンセル/不正JSONを返すケース。HTTPエラー本文を利用者向け文言やログへ流さない。cancelはCancellationErrorのまま伝搬。
- [ ] URLは完全なHTTPS `/route` URL、host必須、userinfo/query/fragment禁止。空文字unconfigured。URLSession ephemeral、POST application/json、timeout30秒、cacheなし、redirectは拒否。URLSession実装名は`URLSessionRouteTransport`。URLProtocolを使いrequest bodyとredirect拒否を検証する。
- [ ] 実装：trip summaryは有限・正、1legを要求し道順index全検査、km→m。shapeはTask1、surface常にunknown。時間比較は`summary.time`のみ（探索のcostではない）。UUID文字列IDを生成。
- [ ] 全coreテストGREEN、release build、上記ファイルをコミット。

## Task 3: 候補生成と部分失敗

**Files:** Create `Sources/CycleNaviCore/Valhalla/CyclingRoutePlanner.swift`; Test `Tests/CycleNaviCoreTests/CyclingRoutePlannerTests.swift`。

**Interfaces:**
```swift
public struct RouteBatch: Sendable {
    public let routes: [PlannedRoute]
    public let incomplete: Bool
    public init(routes: [PlannedRoute], incomplete: Bool)
}
public protocol CyclingRouteProviding: Sendable {
    func routes(for query: CyclingQuery) async throws -> RouteBatch
}
public struct CyclingRoutePlanner: CyclingRouteProviding {
    public init(fetch: @escaping @Sendable (CyclingQuery, CandidateIntent) async throws -> PlannedRoute)
    public func routes(for query: CyclingQuery) async throws -> RouteBatch
}
```

- [ ] RED：fetch closureへ2つのintentが渡ること、両成功、同一座標列、片失敗、両失敗、途中cancelを検証。テスト内のactorにintent履歴を保存し、未定義のmock helperに依存しない。
```swift
let planner = CyclingRoutePlanner { _, _ in throw RoutingFailure.rateLimited }
#expect(throws: RoutingFailure.rateLimited) { try await planner.routes(for: query) }
```
`query`はTask2の公開initializerでテスト内作成。PlannedRouteの合成値もTask1 initializerで直接作る。
- [ ] RED実行後、baseline→preferredの順に逐次取得。自動retryなし。CancellationErrorは即中止。1件失敗時は成功分＋incomplete=true。両失敗時は最初の型付きエラーを返す。
- [ ] 完全に同じ座標列だけ重複除去し、異なる座標列を雑な距離閾値で削除しない。ラベルは「基準候補」「車道回避設定の候補」。速さのラベルはフィルター後に別計算する。
- [ ] 全coreテストGREEN、コミット。

## Task 4: iPhone画面と既存Appleアダプターを接続

**Files:** Create `App/Planner/RouteMapGeometry.swift`, `App/Planner/RoutingConfiguration.swift`, `AppTests/PlannerModelTests.swift`, `AppTests/RouteMapGeometryTests.swift`。Modify `App/Planner/AppleRouteService.swift`, `PlannerModel.swift`, `PlannerView.swift`, `RouteDetailView.swift`, `App/CycleNaviApp.swift`, `AppUITests/PlannerUITests.swift`, `project.yml`。

**Interfaces:**
```swift
// アプリ側。既存Place/MKLocalSearchを維持。
extension PlannedRoute { var mapPolyline: MKPolyline { get } }
// PlannerModelはproviderを注入。未設定用providerはunconfiguredを投げる。
@MainActor init(provider: any CyclingRouteProviding)
// RoutingConfiguration: 認証情報でないURLだけを保持。
struct RoutingConfiguration {
    let endpoint: RoutingEndpoint?
    init(rawEndpoint: String) throws
}
```
`CYCLENAVI_VALHALLA_ROUTE_URL`を起動環境またはInfo.plist開発設定から読み、画面に送信先hostを表示。未設定では経路ボタンを無効にし、「経路サービス未設定」を表示。秘密のAPIキーはアプリへ埋め込まない。

- [ ] RED：providerをactor＋継続で制御し、出発地変更/車種変更/坂や道路好み変更/取消後の旧結果を拒否することをテスト。時間上限変更ではprovider再要求なし。片失敗warningと未設定表示も検証。
- [ ] RED：MapKit変換後の点数と座標が元モデルと一致すること。Apple変換はcyclingのみ、未知surfaceを維持。Apple道順はshapeIndex=nilで変換し自動ナビに流用しない。
- [ ] PlannerModel.routesを[PlannedRoute]、selectedIDをString?、detailをPlannedRoute?へ置換。queryは検索開始時点のsnapshot。既存selectRoutesにはproviderのbicycle経路としてaccessAllowed=trueを渡す（現地確認済みではないことを表示）。全unknownなので舗装限定は全除外。
```swift
let candidates = routes.map {
    RouteCandidate(id: $0.id, seconds: $0.seconds, accessAllowed: true, surface: $0.surface)
}
```
- [ ] route.name/distance/expectedTravelTime/stepsを共通モデルへ移行。地図選択と道順は同じID/モデルを使う。手動音声停止・閉じる際停止を維持。
- [ ] 設定sheetに道路混在/坂/悪路回避の0...1設定を追加。車種変更はinvalidate、上限変更はreconcile。Apple車種未対応の旧説明をValhalla設定の説明へ置換。
- [ ] 地図のApple表記を隠さず、OSM経路には`© OpenStreetMap contributors`リンク（https://www.openstreetmap.org/copyright）。交通量/路面未確認、部分失敗、舗装全除外、サービス未設定を区別する。
- [ ] DEBUGの`--ui-test-route-fixture`起動時のみ固定providerを注入。合成経路であることを画面に表示。通常起動/Releaseはfixtureを使わない。UIテストで経路線選択→道順→読上げ→停止→閉じる、車種変更後の候補消去を検証。
- [ ] xcodegen generate、通常scheme tests/core tests/release buildを実行。シミュレーター画像で帰属・長文・大きい文字を確認。Task4ファイルと生成projectをコミット。

## Task 5: 実通信検証と結果記録

**Files:** Modify `AppLiveTests/LiveMapUITests.swift`, `README.md`; Create `docs/implementation/valhalla-integration-result.md`。

- [ ] live schemeだけが実通信する構成を維持。起動環境のURLを`app.launchEnvironment`へ明示的に渡す。未設定はXCTSkipで「未検証」と記録し、成功件数へ混ぜない。
```swift
guard let endpoint = ProcessInfo.processInfo.environment["CYCLENAVI_VALHALLA_ROUTE_URL"] else {
    throw XCTSkip("Valhalla接続先未設定：実通信は未検証")
}
app.launchEnvironment["CYCLENAVI_VALHALLA_ROUTE_URL"] = endpoint
```
- [ ] 接続先の所有者/利用条件/レート制限を確認・記録してから実通信。候補生成は2要求なので、接続先の要求間隔制限に合わせてtransportを調整してから実行する。必要な契約や権限がなければ依頼し、勝手に公開デモを常用しない。開発者が許可したHTTPS接続先でのみ次を実行。
```sh
xcodebuild -project CycleNavi.xcodeproj -scheme CycleNaviLive \
  -destination 'platform=iOS Simulator,id=89584396-A924-4661-9698-1ADD85DF3D11' \
  -derivedDataPath .build/iphone CODE_SIGNING_ALLOWED=NO test
```
- [ ] 吉祥寺駅→立川駅、武蔵小杉駅→登戸駅の手入力で比較。応答形状/距離/時間/道順と設定の差を確認。同じ経路でも誤差を作って違いを演出しない。個人の現在地は送らない。
- [ ] READMEへ設定方法・未実装範囲、結果記録へcore/app/UI/liveそれぞれの実行結果を記載。live失敗ならそのまま記録し「動作確認済み」にしない。
- [ ] 全変更のdiff check、テスト再実行、別担当の最終レビューを実行方法に応じて受ける。重要指摘を修正・再検証。コミットして、何が動き何が未確認かをユーザーへ返す。

## 計画セルフレビュー

仕様の表示/検索維持・Apple比較・手動音声＝Task4、車種/候補/上限＝Task2〜4、
未知情報・取消・失敗＝全タスク、接続/運用境界・帰属＝Task2/4/5。
全Review Focusにテストを割当済み。新規契約/本番配備は含まない。
接続先未選定という外部条件は残る。実通信まで完了したと宣言するにはTask5の成功が必要。

参考（2026-09-29確認）：https://valhalla.github.io/valhalla/api/route/api-reference/
