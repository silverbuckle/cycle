# CycleNavi Navigation Core Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** iPhoneナビに組み込める、遠回り・路面条件の判定と音声案内タイミングのSwift基盤を、ネットワークやXcodeなしで検証可能にする。

**Architecture:** Swift Packageとしてルート候補の判定と案内の状態機械を分離する。候補の生成、位置の道路への対応付け、音声再生は外側のアダプターが担当する。宿泊先を含む立ち寄り順序をリクエストに保持する。

**Tech Stack:** Swift 6、Swift Package Manager、Swift Testing。外部依存なし。後続のiPhoneアプリはSwiftUI / Core Location / AVFoundationを基本案とする。

**Spec:** `docs/superpowers/specs/2026-09-29-cyclenavi-design.md`

## Global Constraints

- 「ロード・クロス・グラベルに対応。日常移動、週末ライド、宿泊を伴うバイクパッキングを扱う。」
- 「iPhone先行。地図画面と音声によるナビを中心とし、画面消灯中も案内する。将来のAndroid版とサーバーを共有する。」
- 「車種だけで路面の好みを固定しない。」
- 「制約内に候補がなければ理由と緩和案を示し、勝手に制約を変更しない。」
- 「再探索は好み、立ち寄り、当日の宿泊先を引き継ぐ。」
- 「GPS精度低下時は位置の不確かさを表示し、誤った曲がり角案内を抑制する。」
- 「公開日記から現在の宿泊先を自動公開しない。」

## Review Focus

1. 負数・NaN・無限大の時間や許容度を受け取っても、候補を採用しない。Task 1/2でテスト。
2. 最速候補が通行禁止または路面条件外の場合、その時間を比較の基準に使わない。Task 2でテスト。
3. 未確認の路面を舗装路と見なさず、厳密な舗装路条件では除外する。Task 2でテスト。
4. 逸脱後も宿泊先と立ち寄り順序を保持し、残り予算を再探索のたびにリセットしない。Task 1でテスト。
5. GPS精度低下・古い位置・距離の揺れ・ルート変更で誤案内や音声連呼を起こさない。Task 3でテスト。

## 実装単位と依存関係

プロダクト全体は3サブシステムを持つため、一つの巨大な実装計画にしない。本計画は第1段階のうち、単独でテストできるナビ判断基盤を対象にする。アプリ完成とは扱わない。

| 段階 | 成果物 | 完了条件 |
| --- | --- | --- |
| 1A・本計画 | ナビ判断基盤 | Task 1–3が `swift test` で通る |
| 1B | iPhone地図・音声ナビ、経路サービス | 地点検索→候補比較→案内→逸脱再探索を実機で確認。消灯・圏外保存・再開・電池消費を検証 |
| 2 | 休憩・駐輪・宿泊・修理店・旅の探索 | 1泊2日の行程編集と日別案内、保管条件、予約先リンク、修理店の対応条件と電話確認導線がつながる |
| 3 | 記録・共有・現地情報 | 記録の公開範囲、共有ページ、区間への投稿、再確認、訂正・通報が動く |

1Bの開始条件はXcodeとiOS SDKを使えること。現環境はCommand Line Tools / Swift 6.2.4のみを確認し、`simctl` は見つからなかった。1Aはその状態でも実行できる。実機署名設定は1Bで行い、TestFlight公開は別の配布作業とする。

段階2・3は合意済みスコープとして維持する。それぞれを開始する際に、この仕様と1Bの確定インターフェースを用いて実装計画を作る。

追加要望の修理対応サイクルショップは段階2に含める。対応修理・車種・他店購入車・受付時間と営業情報を区別する。故障時の押し歩き経路は1Bの経路サービスで歩行対応を評価する項目に追加し、取得できなければ未確認とする。ショップを追加しても宿泊先を失わないこと、到着時間への影響、受付未確認や受付終了を検証する。1Aの予算・立ち寄り保持のテストはその基礎となる。

## 地図・経路の選定方針

地図の描画と経路探索を別にする。GraphHopperを最初の経路評価候補とし、自転車向けcustom modelで幹線道路や路面の扱いを検証する。SDK/APIを契約・導入した状態ではない。代替候補はValhalla。AppleにもcyclingのAPIがあるため「Appleは自転車非対応」という前提を置かない。

GraphHopperの候補採用条件は、対象地域の実走比較、除外条件の表現、階段・押し歩き・私道の扱い、案内文、属性欠損、キャッシュ条件、料金と利用枠。軟らかい優先順位を設定できることと、路面を厳密に除外できることを区別する。

基盤が受け取る候補はエンジン側で通行可否を確認したものとする。それでも通行条件や路面が不明な場合は不明として渡す。候補群から最速を選んだだけでは大域的な最短を保証しないため、UI文言は「取得した候補の中で最短」とする。真の基準経路を取得できる契約が確定した時点で表示を変更する。

1Bの地図SDKはオフライン地図の保存・ライセンス条件を確認して決定する。1Aでは選定を必要とせず、見せかけの地図や架空の実走可能コースを作らない。

公式資料（2026-09-29確認）:

- https://docs.graphhopper.com/openapi
- https://github.com/graphhopper/graphhopper/blob/master/docs/core/profiles.md
- https://valhalla.github.io/valhalla/sif/dynamic-costing/
- https://developer.apple.com/documentation/mapkit/mkdirectionstransporttype/cycling

## ファイル構成

```text
Package.swift
Sources/CycleNaviCore/Routing/RouteModels.swift
Sources/CycleNaviCore/Routing/RouteSelection.swift
Sources/CycleNaviCore/Navigation/CueScheduler.swift
Tests/CycleNaviCoreTests/RouteModelsTests.swift
Tests/CycleNaviCoreTests/RouteSelectionTests.swift
Tests/CycleNaviCoreTests/CueSchedulerTests.swift
README.md
.gitignore
```

内部の距離はm、時間は秒、座標は緯度・経度。ユーザーに表示する単位・言語はアプリ側の責任とする。

### Task 1: リクエスト、制約、再探索の予算を定義する

**Files:** Create `Package.swift`, `.gitignore`, `Sources/CycleNaviCore/Routing/RouteModels.swift`, `Tests/CycleNaviCoreTests/RouteModelsTests.swift`.

**Interfaces:** Produces `RouteRequest.rerouting(from:elapsedSeconds:) throws -> RouteRequest`。経過秒は「今回の探索以降」ではなく「ライド開始以降」。`remainingBudgetSeconds` は出発時の到着予算から減算する。

- [ ] **Step 1: パッケージとモデルの失敗テストを用意する。** `.gitignore` は `.build/`, `.swiftpm/`, `.DS_Store`。Package.swift:

```swift
// swift-tools-version: 6.0
import PackageDescription
let package = Package(
    name: "CycleNaviCore",
    products: [.library(name: "CycleNaviCore", targets: ["CycleNaviCore"])],
    targets: [.target(name: "CycleNaviCore"),
              .testTarget(name: "CycleNaviCoreTests", dependencies: ["CycleNaviCore"])]
)
```

Task 1の公開型と初期化ルール:

```swift
public enum InputError: Error { case invalidValue }
public enum BikeKind: String, Sendable { case road, cross, gravel }
public enum SurfacePolicy: Sendable { case pavedOnly, allowUnpaved }
public enum DetourLimit: Sendable {
    case extraSeconds(Double), fraction(Double)
    public func budget(baselineSeconds: Double) throws -> Double
}
public struct Coordinate: Equatable, Sendable {
    public let latitude: Double
    public let longitude: Double
    public init(latitude: Double, longitude: Double) throws
}
public struct RouteRequest: Sendable {
    public let origin: Coordinate
    public let destination: Coordinate
    public let orderedStops: [Coordinate]
    public let bike: BikeKind
    public let surface: SurfacePolicy
    public let totalBudgetSeconds: Double
    public let elapsedSeconds: Double
    public var remainingBudgetSeconds: Double { max(0, totalBudgetSeconds - elapsedSeconds) }
    public init(origin: Coordinate, destination: Coordinate,
                orderedStops: [Coordinate], bike: BikeKind, surface: SurfacePolicy,
                totalBudgetSeconds: Double, elapsedSeconds: Double = 0) throws
    public func rerouting(from: Coordinate, elapsedSeconds: Double) throws -> RouteRequest
}
```

上記の宣言は実装すべきインターフェースであり、そのまま本体なしでコンパイルするファイルではない。以下のテストを先に追加する。

```swift
import Testing
@testable import CycleNaviCore

@Test func detourBudget() throws {
    #expect(try DetourLimit.fraction(0.2).budget(baselineSeconds: 1000) == 1200)
    #expect(try DetourLimit.extraSeconds(600).budget(baselineSeconds: 1000) == 1600)
    for bad in [-1.0, .nan, .infinity] {
        #expect(throws: InputError.self) {
            try DetourLimit.extraSeconds(bad).budget(baselineSeconds: 1000)
        }
        #expect(throws: InputError.self) {
            try DetourLimit.fraction(bad).budget(baselineSeconds: 1000)
        }
        #expect(throws: InputError.self) {
            try DetourLimit.fraction(0).budget(baselineSeconds: bad)
        }
    }
}

@Test func reroutePreservesStopsAndOriginalBudget() throws {
    let start = try Coordinate(latitude: 35, longitude: 139)
    let hotel = try Coordinate(latitude: 35.1, longitude: 139.1)
    let request = try RouteRequest(origin: start, destination: hotel,
        orderedStops: [start, hotel], bike: .road, surface: .pavedOnly,
        totalBudgetSeconds: 1200)
    let first = try request.rerouting(from: hotel, elapsedSeconds: 300)
    let second = try first.rerouting(from: start, elapsedSeconds: 500)
    #expect(second.remainingBudgetSeconds == 700)
    #expect(second.orderedStops == [start, hotel])
    #expect(second.destination == hotel)
    #expect(second.bike == .road)
    #expect(second.surface == .pavedOnly)
    #expect(throws: InputError.self) {
        try second.rerouting(from: start, elapsedSeconds: 400)
    }
    #expect(try second.rerouting(from: start, elapsedSeconds: 1300).remainingBudgetSeconds == 0)
}

@Test func coordinatesAreValidated() {
    for (lat, lon) in [(91.0, 0.0), (0, 181), (Double.nan, 0)] {
        #expect(throws: InputError.self) { try Coordinate(latitude: lat, longitude: lon) }
    }
}
```

- [ ] **Step 2: `swift test --filter RouteModelsTests` を実行し、未実装の型による失敗を確認。** ターゲットが空である場合はまず空の `RouteModels.swift` を作成する。
- [ ] **Step 3: インターフェースの本体を実装する。** すべての数値に `isFinite` を適用。緯度は−90…90、経度は−180…180。予算・経過時間・許容度は0以上。計算結果も有限であること。再探索は経過時間の後退を拒否する。

```swift
// DetourLimit.budget の本体
guard baselineSeconds.isFinite, baselineSeconds >= 0 else { throw InputError.invalidValue }
let amount: Double
switch self {
case .extraSeconds(let value): amount = value
case .fraction(let value): amount = value
}
guard amount.isFinite, amount >= 0 else { throw InputError.invalidValue }
let result: Double
switch self {
case .extraSeconds: result = baselineSeconds + amount
case .fraction: result = baselineSeconds * (1 + amount)
}
guard result.isFinite else { throw InputError.invalidValue }
return result
```

- [ ] **Step 4: `swift test --filter RouteModelsTests` が通ることを確認。** 予算と経過時間へのNaN入力、加算オーバーフローも上のテストに追加して確認する。
- [ ] **Step 5: 変更をコミットする。** 現ディレクトリに `.git` はないため、実行時に親の `git rev-parse --show-toplevel` を確認。既存管理外ならこのプロジェクトで `git init`。タスクで作った4ファイルのみをaddし、`feat: define route constraints and reroute budget` としてコミットする。リモートへのpushは行わない。

### Task 2: 条件に合うルート候補を抽出する

**Files:** Create `Sources/CycleNaviCore/Routing/RouteSelection.swift`, `Tests/CycleNaviCoreTests/RouteSelectionTests.swift`.

**Interfaces:** Consumes `SurfacePolicy`, `DetourLimit`, `InputError`。Produces `selectRoutes(_:surface:detour:remainingBudgetSeconds:) throws -> RouteSelection`。再探索ではTask 1の `remainingBudgetSeconds` を必ず渡し、元の予算と新しい候補に基づく上限の小さい方を使う。

- [ ] **Step 1: 以下の失敗テストを作成。** 候補の評価値や路面は提供元で正規化済みという境界とする。

```swift
import Testing
@testable import CycleNaviCore

@Test func excludesForbiddenAndUnknownBeforeBaseline() throws {
    let candidates = [
        RouteCandidate(id: "closed", seconds: 100, accessAllowed: false, surface: .paved),
        RouteCandidate(id: "unknown", seconds: 200, accessAllowed: true, surface: .unknown),
        RouteCandidate(id: "road", seconds: 1000, accessAllowed: true, surface: .paved),
        RouteCandidate(id: "quiet", seconds: 1200, accessAllowed: true, surface: .paved),
        RouteCandidate(id: "long", seconds: 1201, accessAllowed: true, surface: .paved)
    ]
    let result = try selectRoutes(candidates, surface: .pavedOnly, detour: .fraction(0.2))
    #expect(result.baselineSeconds == 1000)
    #expect(result.candidates.map(\.id) == ["road", "quiet"])
    #expect(try selectRoutes(candidates, surface: .pavedOnly,
        detour: .fraction(0.2), remainingBudgetSeconds: 900).candidates.isEmpty)
}

@Test func noCandidateIsExplicit() throws {
    let result = try selectRoutes([], surface: .pavedOnly, detour: .fraction(0.2))
    #expect(result.baselineSeconds == nil)
    #expect(result.candidates.isEmpty)
}

@Test func invalidDurationIsNeverRecommended() throws {
    for bad in [-1.0, .nan, .infinity] {
        let result = try selectRoutes([
            RouteCandidate(id: "bad", seconds: bad, accessAllowed: true, surface: .paved)
        ], surface: .pavedOnly, detour: .fraction(0.2))
        #expect(result.candidates.isEmpty)
    }
}
```

- [ ] **Step 2: `swift test --filter RouteSelectionTests` で未実装による失敗を確認。**
- [ ] **Step 3: 以下を実装。** 候補の順位付けはこの関数の責任に含めず、入力順を保つ。実装者は公開memberwise initializerを `RouteCandidate` に追加する。

```swift
public enum Surface: Sendable { case paved, unpaved, unknown }
public struct RouteCandidate: Sendable {
    public let id: String
    public let seconds: Double
    public let accessAllowed: Bool
    public let surface: Surface
    public init(id: String, seconds: Double, accessAllowed: Bool, surface: Surface) {
        self.id = id; self.seconds = seconds
        self.accessAllowed = accessAllowed; self.surface = surface
    }
}
public struct RouteSelection: Sendable {
    public let baselineSeconds: Double?
    public let candidates: [RouteCandidate]
}
public func selectRoutes(_ candidates: [RouteCandidate], surface: SurfacePolicy,
                         detour: DetourLimit, remainingBudgetSeconds: Double? = nil)
    throws -> RouteSelection {
    _ = try detour.budget(baselineSeconds: 0)
    if let remainingBudgetSeconds {
        guard remainingBudgetSeconds.isFinite, remainingBudgetSeconds >= 0
        else { throw InputError.invalidValue }
    }
    let eligible = candidates.filter {
        $0.accessAllowed && $0.seconds.isFinite && $0.seconds >= 0 &&
        (surface == .allowUnpaved || $0.surface == .paved)
    }
    guard let baseline = eligible.map(\.seconds).min() else {
        return RouteSelection(baselineSeconds: nil, candidates: [])
    }
    let limit = min(try detour.budget(baselineSeconds: baseline),
                    remainingBudgetSeconds ?? .infinity)
    return RouteSelection(baselineSeconds: baseline,
                          candidates: eligible.filter { $0.seconds <= limit })
}
```

未舗装許容の場合も `unknown` は後続UIで「路面未確認」と表示する。`paved` は区間全体の舗装確認を意味し、一部不明なら候補全体を `unknown` とする。これはプロトタイプ用の厳しい判定で、1Bの区間モデルで詳細化する。

- [ ] **Step 4: `swift test --filter RouteSelectionTests` を実行。** 未舗装許容時の未舗装候補、ゼロ許容、同率最短、空候補への不正許容値も具体例としてテストを追加する。
- [ ] **Step 5: 上記2ファイルのみコミット。** メッセージ `feat: enforce route surface and detour constraints`。

### Task 3: 位置サンプルから案内イベントを一度ずつ発行する

**Files:** Create `Sources/CycleNaviCore/Navigation/CueScheduler.swift`, `Tests/CycleNaviCoreTests/CueSchedulerTests.swift`, `README.md`.

**Interfaces:** Produces `CueScheduler.next(routeID:turnID:meters:accuracyMeters:sampleAgeSeconds:) -> Cue?`。`meters` は道路に対応付けた次の曲がり角までの残り距離であり、曲がり角への直線距離ではない。アプリ側で対象turnとrouteを確定して渡す。ルート変更ごとに `routeID` を新規発行する。端末時刻の変化を避けるためageは単調時間差で渡す。

- [ ] **Step 1: 次のテストを追加する。**

```swift
import Testing
@testable import CycleNaviCore

@Test func poorLocationDoesNotConsumeCue() {
    var scheduler = CueScheduler()
    #expect(scheduler.next(routeID: "r", turnID: "t", meters: 180,
                          accuracyMeters: 100, sampleAgeSeconds: 0) == nil)
    #expect(scheduler.next(routeID: "r", turnID: "t", meters: 180,
                          accuracyMeters: 5, sampleAgeSeconds: 20) == nil)
    #expect(scheduler.next(routeID: "r", turnID: "t", meters: 180,
                          accuracyMeters: 5, sampleAgeSeconds: 0) == .advance)
}

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

@Test func invalidSamplesAreSuppressed() {
    for bad in [-1.0, .nan, .infinity] {
        var scheduler = CueScheduler()
        #expect(scheduler.next(routeID: "r", turnID: "t", meters: bad,
                              accuracyMeters: 5, sampleAgeSeconds: 0) == nil)
        #expect(scheduler.next(routeID: "r", turnID: "t", meters: 20,
                              accuracyMeters: bad, sampleAgeSeconds: 0) == nil)
        #expect(scheduler.next(routeID: "r", turnID: "t", meters: 20,
                              accuracyMeters: 5, sampleAgeSeconds: bad) == nil)
    }
}
```

- [ ] **Step 2: `swift test --filter CueSchedulerTests` で未実装による失敗を確認。**
- [ ] **Step 3: 以下の状態機械を実装する。** 200m・30m・精度30m・鮮度10秒は初期の検証値。実走時に速度や近接交差点の影響を測り調整する。安全性が検証された閾値とは表示しない。

```swift
public enum Cue: Equatable, Sendable { case advance, immediate }
public struct CueScheduler: Sendable {
    private var currentRoute: String?
    private var advanced: Set<String> = []
    private var immediate: Set<String> = []
    public init() {}
    public mutating func next(routeID: String, turnID: String, meters: Double,
                              accuracyMeters: Double, sampleAgeSeconds: Double) -> Cue? {
        guard !routeID.isEmpty, !turnID.isEmpty,
              meters.isFinite, meters >= 0,
              accuracyMeters.isFinite, accuracyMeters >= 0, accuracyMeters <= 30,
              sampleAgeSeconds.isFinite, sampleAgeSeconds >= 0, sampleAgeSeconds <= 10
        else { return nil }
        if currentRoute != routeID {
            currentRoute = routeID
            advanced.removeAll(); immediate.removeAll()
        }
        guard !immediate.contains(turnID) else { return nil }
        if meters <= 30 {
            immediate.insert(turnID); advanced.insert(turnID)
            return .immediate
        }
        if meters <= 200 && !advanced.contains(turnID) {
            advanced.insert(turnID)
            return .advance
        }
        return nil
    }
}
```

非同期で遅れて到着した旧ルートのサンプルは、呼び出し元で現行routeIDと照合して破棄する。この型は呼び出し元から渡されたIDを現在のルートと解釈する。音声の完了・割り込み・再開は1Bで扱い、イベント発行と音声再生成功を混同しない。

- [ ] **Step 4: 全体を `swift test` で検証。** 200m超で発行しない、200m→30mで順番に発行、turnIDが違えば次の案内が発行されることもテストする。
- [ ] **Step 5: READMEに実行方法と現在の範囲を記載。** 次の内容を含める。

```markdown
# CycleNavi

自転車で快適に走る道と、休憩・宿泊をつなぐiPhoneナビの開発プロジェクト。

## 現在の実装範囲

Swift製のルート条件判定と案内イベントの基盤。地図表示、GPS取得、音声再生、
実道路の経路探索、店舗情報、アカウント、投稿はまだ提供していません。

## 検証

Swift 6以上で `swift test` を実行します。基盤のテストにXcodeは不要です。
iPhoneアプリのビルドと実機検証にはXcodeとiOS SDKが必要です。

## 設計資料

- docs/superpowers/specs/2026-09-29-cyclenavi-design.md
- docs/superpowers/plans/2026-09-29-navigation-core.md
```

- [ ] **Step 6: `swift build -c release` と `git diff --check` を実行。** エラーなしを確認してタスクの3ファイルを `feat: schedule navigation cues without repeats` としてコミット。

## 完了判定と次の作業

1Aは全テストとrelease buildが成功し、制約・再探索予算・案内イベントの範囲をREADMEに明記した状態で完了とする。GPSナビが使えるという説明はしない。

1Bではまず、Xcodeの確認、経路提供元の少数ケース比較、地図SDKのオフライン条件を解決する。以後にiPhoneの画面設計と実装計画を具体化する。BIKEPACKING.comに着想を得た旅の画面とYAMAPに着想を得た投稿循環は段階2・3で実装し、日常ナビと同じデータを使う。

## セルフレビュー

- 本計画で実装: 仕様3の一部（除外・遠回り・再探索制約・低精度抑制）、仕様8の分離可能な基盤。
- 1Bへ割当: 地点検索、ルート生成・評価理由、地図・GPS・音声・オフライン・権限・電池検証、タイヤ幅等のプロフィール詳細、周回探索。
- 段階2へ割当: 仕様4・5のスポット、修理対応店と受付条件・連絡・寄り道、日別旅程、写真・紹介画面、チェックイン時間。
- 段階3へ割当: 仕様6の記録・共有・現地メモ・再確認・公開範囲・運営機能。
- 仕様7の収益・店舗・地域連携は利用検証後。現時点では有料サービスへの登録や契約は行わない。
- 型とテストで使用する名称は各タスクに定義済み。外部APIの資格情報は1Aで不要。

## 実行方法

推奨はNative: このセッションで順番に実装する。3タスクが同じ型を共有するため、逐次実装で統合を確認しやすい。代替はSubagent-driven: タスクごとに担当とレビュアーを分ける。計画レビュー後に選択する。
