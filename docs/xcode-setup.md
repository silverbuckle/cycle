# Xcodeセットアップ状況

確認日: 2026-09-29

## 最新の結果: シミュレーター開発準備完了

- Xcode 26.6（17F113）の初回設定が完了。`xcodebuild -checkFirstLaunchStatus` はexit 0。
- iOS 26.5 SDKとiOS Simulator SDKを確認。
- iOS 26.5ランタイム（23F77）を確認。
- iPhone 17 Pro（89584396-A924-4661-9698-1ADD85DF3D11）を起動し、`simctl bootstatus -b` がFinished / exit 0。
- SwiftUI、MapKit、CoreLocation、AVFoundationをimportする最小コードをiOS Simulator向けにtypecheckし、exit 0。アプリ本体や実機ナビの検証ではない。
- システム共通の `xcode-select` はCommand Line Toolsのまま。プロジェクトのビルドでは `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer` を指定して確認済みのXcodeを使う。システム全体の切り替えは実施していない。
- ランタイム導入後、シミュレーター初回起動前の空き容量は約18GiB。
- 実機への署名・配置、GPS・バックグラウンド音声はアプリ作成後の別検証。

以下はセットアップ時点の履歴。以前の「未導入」「停止」は上記の検証により解決済み。

## 確認済み

- Mac: Apple Silicon、macOS 26.2（25C56）。
- 空き容量: 約39GiB（41.5GB）。大容量のXcode展開とiOSランタイム追加前に再確認する。
- Command Line Tools: `/Library/Developer/CommandLineTools`。
- Swift: 6.2.4。
- Xcode本体: `/Applications/Xcode.app` に展開済み。26.6（17F113）を `xcodebuild -version` で確認。`codesign --verify --deep --strict` 成功。
- iOSシミュレーター: 未導入。Xcode初回設定待ち。
- Appleの対応表で、macOS 26.2に対応するXcode 26.6を選定。Xcode 27はmacOS 26.6以降が必要。

## 現在の停止箇所

最新状況: ユーザーがダウンロードした `/Users/songline/Downloads/Xcode_26.6_Apple_silicon.xip` を展開し、Xcode本体の配置と署名確認を完了した。展開後の空き容量は約32GiB。本体のディスク使用量は約3.8GiB。

`DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -runFirstLaunch` はライセンス未同意で終了（exit 77）。`sudo -n true` でも管理者パスワードが必要と判明。XcodeをGUIで起動した。ユーザーがライセンス内容の確認と同意、要求された管理者認証を完了すると初期設定とiOSランタイム導入を再開できる。システムのxcode-selectはまだCommand Line Toolsを指している。

## 取得時の経緯（解決済み）

Xcodes CLI 2.1.0の公式ビルド済み配布で版一覧とXcode 26.6（17F113）の存在を確認。`xcodes install 26.6 --no-superuser` はApple ID入力を要求したため中断した。Xcode本体のダウンロードは始まっていない。

Apple公式ダウンロードページを既定ブラウザーで開いた。ユーザーがApple Accountにサインインし、Xcode 26.6のApple Silicon用ファイルをダウンロードする必要がある。資格情報はチャットへ送らず、Appleの画面で入力する。

https://developer.apple.com/download/all/?q=Xcode%2026.6

追記: ユーザーの画面では上記の検索リンクから対象版を見つけられなかった。Xcode Releasesの配布一覧からApple配布先を取得し、Safariで次の直接リンクを開いた。未認証のHTTP確認はAppleのunauthorizedページへ転送されたため、認証済みSafariでの取得成否は未確認。

https://download.developer.apple.com/Developer_Tools/Xcode_26.6/Xcode_26.6_Apple_silicon.xip

Apple公式のResourcesページも旧版の配布先として `https://developer.apple.com/download/all/` を案内している。有料Developer Program加入は不要と明記されている。

## 再開時の手順

1. ダウンロードファイルの実在、名前、容量と空き容量を確認。
2. Apple配布の署名付きXIPを展開し、アプリの署名を検証してApplicationsへ設置。
3. Xcodeを起動し、ライセンスと初回コンポーネントの設定を完了する。管理者認証が必要ならMac上で本人が操作。
4. 開発ツールの対象をそのXcodeに設定する。パスは実際の配置先を確認してから指定。
5. iOSシミュレーターを1種類追加し、起動とiOS SDKでのビルドを確認。
6. 実機開発時にXcodeのApple Account、署名チーム、iPhoneのDeveloper Modeと端末の信頼を設定。

検証コマンド:

```sh
xcode-select -p
xcodebuild -version
xcodebuild -showsdks
xcrun simctl list runtimes
```

## セットアップ中の変更

- Homebrewに `xcodesorg/made` tapを追加。xcodesのビルドはxcbuildがないため失敗し、Homebrew版はインストールされていない。
- 代替の公式ビルド済みCLIは `/tmp/cyclenavi-xcode-setup.wRub30/unpacked/xcodes` に一時保存。codesign検証は成功。CLIのバージョン表示・一覧取得は実行できた。spctlのappとしての評価は「does not seem to be an app」となったため、公証済みの判定が取れたとは扱わない。
- Xcodeライセンス同意、OS更新、開発ツールの切り替えは未実施。

## 公式資料

- https://developer.apple.com/xcode/system-requirements
- https://developer.apple.com/xcode/resources/
- https://github.com/XcodesOrg/xcodes
