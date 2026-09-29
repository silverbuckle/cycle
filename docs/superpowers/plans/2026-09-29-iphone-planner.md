# iPhone Online Planner Implementation Plan

> **For agentic workers:** Use superpowers:executing-plans for inline implementation and a fresh final review.

**Goal:** iPhoneシミュレーターで起動でき、実際の地点検索・自転車経路比較・現在地表示・案内文の読み上げを試せるアプリを作る。

**Architecture:** 既存CycleNaviCoreをローカルパッケージとして参照するSwiftUIアプリ。Apple MapKitの検索と自転車経路をアダプターとして分離。検索・経路の非同期結果は世代番号で古いものを破棄する。

**Tech Stack:** iOS 18以上、SwiftUI、MapKit、CoreLocation、AVFoundation、XcodeGen。新規の有料契約・APIキーは不要。

**Spec:** `docs/superpowers/specs/2026-09-29-cyclenavi-design.md`

## 今回の範囲と継続する要件

ユーザーの「進めてください」は前ターンで示した経路サービスとiPhone画面の接続を進める指示として扱う。新しい製品の方向性を追加しない。これはstage 1Bを構成するオンライン計画画面の実装単位。

- 日常移動の出発地・目的地を名称で検索、候補を選択。
- 自転車経路をMapKitから取得し、実距離・推定時間・追加時間を比較して地図に表示。
- 遠回り上限は追加分で指定。舗装限定の場合、路面未確認のApple候補を推奨経路にしない。
- 車種を選べるが、現段階のApple経路は車種別最適化を保証しない。その旨を設定欄に表示する。
- 位置情報は利用者が現在地ボタンを押したときに許可を要求。拒否時も地点検索で計画できる。
- 案内一覧から手動で各案内を読み上げる。自動の曲がり角判定・バックグラウンド案内・逸脱再探索は今回の完了条件に含めず、実装済みと表示しない。
- 通信できない、候補なし、路面条件で全除外、遠回り上限変更、検索取消を明示。
- BIKEPACKING.comから着想を得た生成り・濃緑の静かな表現。地図上のApple帰属表記を隠さない。
- 旅行・休憩・修理スポット・記録・投稿・オフラインは元仕様を維持し、未実装のボタンを並べない。

## 接続先の判断

ローカルSDKのMKDirectionsTypes.hでcycling（iOS 14以上）を確認した。まずAppleの経路をオンラインで使い、GraphHopper等を入れ替え可能な場所に閉じ込める。交通量・路面が取れない候補を「快適」「舗装確認済み」と表示しない。自転車経路が返らない地域では徒歩や自動車経路へ自動フォールバックしない。

MapLibreはオフラインパックに対応するが地図配信元の許諾が別途必要。OSM標準タイルはオフライン先読みが禁止されているため採用しない。今回はApple地図のオンライン利用のみとし、オフライン可能と表示しない。

Sources: https://docs.graphhopper.com/openapi 、 https://maplibre.org/maplibre-native/ios/latest/documentation/maplibre/mlnofflinepack/ 、 https://operations.osmfoundation.org/policies/tiles/

## Task 1: 非同期更新と候補の接続

Files: `Sources/CycleNaviCore/Planning/RequestGeneration.swift`, `Tests/CycleNaviCoreTests/RequestGenerationTests.swift`。

Interface: `RequestGeneration.begin() -> UUID`, `accepts(_ token: UUID) -> Bool`, `cancel()`。

- [ ] 検索A→検索B→Aの遅延到着、cancel後の結果、最初の有効要求をテストする。
- [ ] 未実装で失敗を確認し、UUIDトークンで現在の要求のみ受理する処理を実装。
- [ ] 全テストを実行。

## Task 2: 起動可能なiPhoneアプリと検索・経路比較

Files: `project.yml`, `CycleNavi.xcodeproj/`, `App/CycleNaviApp.swift`, `App/Planner/AppleRouteService.swift`, `App/Planner/PlannerModel.swift`, `App/Planner/PlannerView.swift`, `App/Planner/PlaceSearchView.swift`, `App/Design/Theme.swift`。

Interfaces: `AppleRouteService.search(_ query: String) async throws -> [Place]`、`routes(from: Place, to: Place) async throws -> [RideRoute]`。PlaceはUUID、名称、補助住所、座標。RideRouteはUUIDとMKRoute。

- [ ] XcodeGenでiOSアプリターゲットを作成。ローカルCycleNaviCoreを参照し、Simulatorでは署名不要でビルド可能にする。
- [ ] 検索UIを実装。検索要求ごとにtokenを作り、新しい検索・取消時は古い結果を破棄。
- [ ] MKDirectionsに `.cycling` と `requestsAlternateRoutes = true` を指定。地図と候補一覧を同じselectedRouteで同期。
- [ ] 既存selectRoutesへ自転車候補を接続。Appleが自転車として返したものだけを採用し、surfaceはunknown。未確認路面を明示する。
- [ ] 設定変更時は既存候補を再選別。全除外なら古い選択を解除し、理由を表示する。
- [ ] 実際の検索と経路の取得をシミュレーターから検証。サービスエラーを空配列や架空ルートに置換しない。

## Task 3: 現在地と音声、UI検証

Files: `App/Navigation/LocationService.swift`, `App/Navigation/SpeechService.swift`, `App/Planner/RouteDetailView.swift`, `AppUITests/PlannerUITests.swift`。

- [ ] 位置情報の利用目的をInfo.plistに設定。ユーザー操作でwhen-in-use権限を要求、位置が古い・精度不明なら採用しない。
- [ ] 音声はAVSpeechSynthesizerを保持して日本語で読み上げる。前の発話は停止してから切り替え、閉じる際も停止する。
- [ ] 案内一覧の読み上げと、音声の停止をユーザーが操作できるようにする。「自動ナビは未接続」と画面に明記。
- [ ] UIテストで起動、検索画面、車種選択、遠回り設定を検証。ネットワーク依存テストは任意の別テストとして扱う。
- [ ] iPhoneシミュレーターでビルド・起動・画面を確認し、既存Swiftテストも実行する。

## Review Focus

古い検索・経路結果の混入、路面未確認を舗装扱いしないこと、地域非対応を自動車経路で埋めないこと、位置情報拒否でも手入力できること、読み上げ中に画面を閉じる場合、Apple地図の帰属表記とDynamic Type。

## 完了条件

アプリがシミュレーターで起動し、UIの検証が通る。オンライン実取得の結果は成功・失敗をそのまま記録する。音声読み上げと自動ナビを区別し、今回未実装の要求をREADMEに残す。実機のGPS・消灯中案内の品質はシミュレーター成功で代用しない。
