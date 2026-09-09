# iOSの位置情報取得

現在地は、近くのコースの検索と天気の取得に使用します。アプリ内の「位置情報・天気サービス」の利用に同意したうえで、iOSの位置情報の許可が必要です。

## ネイティブアプリのビルド

`ios/Runner/Info.plist` の `NSLocationWhenInUseUsageDescription` に利用目的を設定しています。`ios/Podfile` では geolocator_apple に `BYPASS_PERMISSION_LOCATION_ALWAYS=1` を設定し、使用中のみの位置情報取得に限定しています。バックグラウンド位置情報は使用しません。

Macで変更を反映する際は、プロジェクト直下で `flutter pub get`、続いて `ios` ディレクトリで `pod install` を実行し、アプリを再ビルドしてください。

## 実機での確認

1. iPhoneの「設定」→「プライバシーとセキュリティ」→「位置情報サービス」を有効にします。
2. アプリで位置情報・天気サービスに同意し、コースの現在地検索を実行します。初回のOSダイアログで「Appの使用中は許可」を選びます。
3. 登録コースの範囲内でコース名が取得されることを確認します。範囲外ではコースが見つからなくても位置情報取得自体は成功し得ます。天気の取得には通信と天気サービスの設定も必要です。
4. 天気の取得中にコース検索を実行し、権限要求の競合で失敗しないことを確認します。
5. 位置情報を拒否した場合と端末の位置情報サービスを無効にした場合に、対応する案内が出ることを確認します。設定から許可・有効化して再取得できることも確認します。

シミュレータでは位置を指定して確認してください。Dartの自動テストはOSとの通信を模擬しており、実際の許可ダイアログやGPS取得の確認には実機が必要です。

## Safari / ホーム画面のPWA

HTTPSで開き、サイトの位置情報利用を許可してください。ネイティブアプリのPodfile設定はPWAには適用されません。同時に発生した位置情報取得はPWAでも共有されます。

### Macなしで天気取得エラーを調べる

新セッティング画面の天気取得は、現在位置取得 → Firebase App Check初期化 → 必要なら匿名認証 → `getCurrentWeather` Function → OpenWeatherの順です。従来の「天気サービスに接続できませんでした」は、認証や設定不足も含む共通表示で、通信障害とは限りません。今回の変更をWebへ公開すると、天気カードに説明とエラーコードが表示されます。位置情報の拒否やタイムアウトは従来どおり別の案内です。

| コード | 確認する内容 |
| --- | --- |
| `firebase_app_check/missing-site-key` | Webビルドに `FIREBASE_APP_CHECK_WEB_KEY` が渡っているか。GitHub Actionsでは同名のRepository Variableを使用します。 |
| `firebase_auth/operation-not-allowed` | Firebase Authenticationのログイン方法でAnonymousが有効か。 |
| `firebase_app_check/…` | Firebase App CheckのWeb登録、reCAPTCHAの設定、検証リクエストの失敗状況。現コードは `ReCaptchaV3Provider` 固定なので、Enterprise専用キーをそのまま渡しても対応しません。 |
| `cloud_functions/unauthenticated` | 認証トークンまたはApp Checkの検証。これだけではどちらの拒否か確定できないため、Firebaseのメトリクス・Functionsログで照合します。 |
| `cloud_functions/failed-precondition` | サーバー設定。本コードではOpenWeatherのSecret不足でも返します。 |
| `cloud_functions/not-found` | `asia-northeast1` に `getCurrentWeather` がデプロイされているか。Web公開のワークフローはFunctionsをデプロイしません。 |
| `cloud_functions/resource-exhausted` | 利用回数・クォータ制限。 |
| その他 | 表示されたコードと発生時刻を記録し、Functionsログ等で照合します。`internal` だけで通信障害・OpenWeather障害とは断定できません。 |

Firebase ConsoleとGitHubの設定確認はWindowsのブラウザでも行えます。App Checkの保護を無効化して回避する必要はありません。公開済みのPWAが古い場合は、新版への更新後に確認してください。

### `weather/unexpected-error` とFirebase SDKの読み込み

`firebase_core_web` 3.9.1は、FirebaseのJavaScript SDKを動的importするため、インラインのローダースクリプトを挿入します。従来の `web/index.html` のCSPはこのスクリプトを許可しておらず、ローダー関数が定義されないまま呼び出されます。通常のFirebaseExceptionではない例外になるため、`weather/unexpected-error` の原因になります。iOS固有の問題とは限りません。

修正では、現在の依存SDKが挿入する本文のSHA-256ハッシュのみを `script-src` に追加しています。Trusted Typesを使う分岐と、Safari等で使う分岐の両方が対象です。任意のインラインJavaScriptは許可しません。[CSPのハッシュによる許可について](https://developer.mozilla.org/en-US/docs/Web/HTTP/Reference/Headers/Content-Security-Policy/script-src)

依存パッケージ更新後は、`flutter pub get` に続けて `node tool/firebase_csp.mjs` を実行し、差分を確認してください。CIは `node tool/firebase_csp.mjs --check` でSDKとCSPの不一致を検出します。

ブラウザ回帰テストは `node tool/firebase_csp_test.mjs` です。PlaywrightとChromiumが必要です。既存のPlaywrightは `PLAYWRIGHT_MODULE_PATH`、Edgeは `PLAYWRIGHT_CHANNEL=msedge` で指定できます。外部SDKの応答はテスト用に模擬し、修正前の拒否・修正後のローダー実行と動的import成功・未許可スクリプトの拒否を検証します。実際の認証・天気APIの成功を検証するテストではありません。
