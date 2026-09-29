# CycleNavi

自転車で快適に走る道と、休憩・宿泊をつなぐiPhoneナビの開発プロジェクト。

## 現在の実装範囲

SwiftUIのiPhone試作と、外部依存のないSwiftライブラリ `CycleNaviCore` を実装しています。

- Apple地図、出発地・目的地の実検索、遠回り設定、現在地の一回取得。
- OSM/Valhalla経路の取得・比較・MapKit表示と道順の手動読み上げ。
- 車種、車道/坂の許容度、悪路回避をValhallaへ反映。推定時間の上限で候補を絞り込み。
- 2026-09-29、公開デモを一時的に使用して吉祥寺駅→立川駅、武蔵小杉駅→登戸駅の実取得・画面操作を確認。
- **本番バックエンドは未配備**。通常起動では接続先未設定と表示します。公開デモは恒久利用しません。
- Apple経路は比較用コードとして保持。今回の環境ではcycling要求にautomobileが返ったため採用していません。

ナビ判断基盤：

- 追加時間・割合で遠回り上限を計算。
- 通行不可や路面条件に合わない候補を除外した後、許容時間内の候補を抽出。
- 再探索でも目的地・立ち寄り順・車種・路面条件・出発時の時間上限を保持。
- GPS精度とデータの鮮度に応じた事前・直前案内イベント。同じ案内の繰り返しを抑制。

位置に応じた自動音声案内、逸脱再探索、バックグラウンド案内、オフライン、
独自の快適性評価、店舗・修理店・宿泊情報、アカウント・投稿は未実装です。
現段階で実走ナビとしては使えません。

## 検証

Swift 6以上で実行できます。このMacではXcodeをコマンド単位で指定します。

```sh
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
swift test
swift build -c release
```

Xcodeで `CycleNavi.xcodeproj` を開き、Scheme `CycleNavi` とiPhoneシミュレーターを選びRun。
実機の署名設定は未実施です。プロジェクト再生成は `xcodegen generate`。

```sh
xcodebuild -project CycleNavi.xcodeproj -scheme CycleNavi \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -derivedDataPath .build/iphone CODE_SIGNING_ALLOWED=NO test
```

オンライン実取得テストは別Scheme `CycleNaviLive` です。接続先未指定ではスキップし、
成功とは扱いません。通常テストの合成データは実走経路ではありません。

## Valhalla接続設定

自分が利用権限を持つHTTPSの完全な `/route` URLを、XcodeのScheme → Run → Arguments →
Environment Variablesで `CYCLENAVI_VALHALLA_ROUTE_URL` に設定してください。
値は画面の「送信先」で確認できます。Info.plistの同名キーでも設定可能です。
URLへのユーザー名・パスワード・クエリ・フラグメント埋め込みは拒否します。
位置は経路計算サーバーへ送信されるため、提供元のログ/プライバシー方針も確認してください。
認証付きの本番ゲートウェイ接続は別の運用作業です。

Liveテストは同名のXcode build settingでURLを渡します（秘密値は渡さない）。

```sh
xcodebuild -project CycleNavi.xcodeproj -scheme CycleNaviLive \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -derivedDataPath .build/iphone CODE_SIGNING_ALLOWED=NO \
  CYCLENAVI_VALHALLA_ROUTE_URL=https://your-routing-server.example/route test
```

OSM経路の路面は現段階ではunknownです。「舗装が確認できる道だけ」をオンにすると全候補が除外されます。
悪路回避はその車種での計算上の好みであり、路面確認や安全保証ではありません。
基準候補と好みの候補が同じ線なら1件にまとめます。候補の一部取得失敗も明示します。

## 接続時の契約

- 時間は秒、距離はm、座標は緯度・経度。表示の単位と言語はアプリ側で変換します。
- `selectRoutes` は提供された候補を絞る関数です。快適さの順位付けや経路生成は行いません。
  最短の基準も「取得した有効候補の中で最短」であり、大域的な最短経路の保証ではありません。
- 経路提供元は通行可否を確認し、不明な場合も `accessAllowed: false` とします。
  一部に未確認の路面を含む候補は `.unknown`。舗装路限定では除外されます。
  未舗装許容で残った `.unknown` は画面上でも未確認と表示する必要があります。
- 再探索時は `RouteRequest.remainingBudgetSeconds` を `selectRoutes` に渡してください。
  経過時間はライド開始からの累積時間で、再探索ごとにリセットしません。
  立ち寄り済み地点の管理・取り除きは今後の旅程側が担います。
- 案内側は地図上の進行状況から対象の曲がり角と道路沿いの残距離を決めます。
  `routeID` は再探索ごとに更新し、遅延して届く古いルートの位置処理結果は渡す前に破棄します。
  `turnID` は交差点のIDではなく、周回でも重複しない案内順序のIDです。
- `CueScheduler` の200m/30mという距離、精度30m以内・鮮度10秒以内という閾値は
  実走検証前の初期値です。イベント発行と音声の再生成功は別で、割り込み等は音声側で扱います。

## 開発段階

1. ナビ判断基盤（本ライブラリ）。
2. 経路サービスとiPhone地図・音声ナビへの接続。
3. カフェ・駐輪・修理対応店・宿泊先と、日別行程。
4. ライド記録・共有・現地メモ・再確認の循環。

## 設計資料

- [プロダクト仕様](docs/superpowers/specs/2026-09-29-cyclenavi-design.md)
- [ナビ基盤の実装計画](docs/superpowers/plans/2026-09-29-navigation-core.md)
- [Xcodeのセットアップ記録](docs/xcode-setup.md)
- [Valhalla接続の検証記録](docs/implementation/valhalla-integration-result.md)
