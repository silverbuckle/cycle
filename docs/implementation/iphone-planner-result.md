# iPhoneオンライン計画画面 — 2026-09-29

実装：SwiftUI / MapKitの地図・地点検索・候補接続、遠回り追加時間設定、路面不明表示、
舗装限定時の除外、要求世代管理、操作時のみ現在地許可、道順手動読み上げ。
OSM・快適性スコア・車種別探索・自動音声ナビは未接続。

## 検証と制約

- Swift Testing: 26テスト / 4 suites成功。release build成功。
- 最終CycleNavi scheme: 位置取消回帰テスト2件＋基本UIテスト1件成功。
- iPhone 17 Pro / iOS 26.5シミュレーターでビルドと起動、検索・設定画面を検証。
- 吉祥寺駅と立川駅の実検索は成功。
- 実経路テストは失敗。要求type=8（cycling）に対して返却3件すべてtype=1（automobile）。
  返却距離17111m / 18005m / 18910m。自転車候補としては採用せず、画面に取得不可を表示。
  SDKにcyclingが存在することだけではこの環境の正常動作を保証できなかった。
  Apple全域の非対応とは断定しない。フィルターは緩めない。
- 音声再生コードはビルド確認のみ。実経路が得られていないため実経路に基づく再生確認は未了。
- 通常のCycleNavi schemeはローカル単体/UI検証。CycleNaviLiveは明示実行する別テスト。

診断証跡（ローカル・git対象外）：
`.build/iphone/Logs/Test/Test-CycleNavi-2026.09.29_14-31-55-+0900.xcresult`、
`.build/live-diagnostics/`。画面：`.build/iphone-live.png`。

## レビュー反映

別担当の読み取り専用レビューで、現在地の後着による手動出発地の上書きと、
liveテストが通常schemeに混入する問題を確認。手動選択/入替時の現在地取得取消と
未要求コールバックの拒否、live専用target/scheme分離を実施。取消後の位置/エラーを検証する回帰テストを追加。

## 次の接続

地図と経路エンジンを分離し、OSMベースの経路を接続する。
GraphHopper等の路面・通行条件を使う。APIキー/契約やサーバー配備は未実施。
OSMデータに交通量・安全性・路面状態の網羅性は期待せず、不明を保持する。
標準OSMタイルのオフライン大量取得は行わない。

参考：[GraphHopper公式](https://docs.graphhopper.com/openapi)、
[カスタムモデル](https://github.com/graphhopper/graphhopper/blob/master/docs/core/custom-models.md)、
[OSMタイルポリシー](https://operations.osmfoundation.org/policies/tiles/)。
