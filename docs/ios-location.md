# iOSの位置情報・天気取得：設定と不具合対応記録

現在地は、近くのコースの検索と天気の取得に使用します。アプリ内の「位置情報・天気サービス」の利用に同意したうえで、iOSの位置情報の許可が必要です。

## 2026-09-09：iPhoneのWeb版で取得が即座に失敗する問題

**対応結果：CSP修正後、ユーザーからiPhoneで動作したとの報告を受領しました。** 調査・修正・自動検証はWindows環境で実施しました。ネイティブiOSアプリの実機確認結果ではありません。iOSのバージョンや、Safariとホーム画面PWAの両方で確認したかは記録していません。

### 症状と切り分け

新セッティング画面で位置情報取得ボタンを押すと、一瞬処理が走った後にエラーになるという報告がありました。最初の画像では、天気カードに「天気サービスに接続できませんでした。通信状態を確認して再取得してください。」と表示されていました。

コードを追うと、この表示は緯度・経度取得後の天気サービス呼び出しで発生するものでした。設定不足・匿名認証・App Check・Functions呼び出しの例外をすべて同じ通信エラーにまとめていたため、画面だけでは原因を判別できませんでした。公開版では `debugLog` も出力されません。

そこで、例外のプラグイン名とコードを天気カードに表示する診断機能を追加しました。次の画像で `weather/unexpected-error` が確認され、通常の `FirebaseException` として扱えない例外が発生していると分かりました。このコード単独では原因は確定できないため、SDKの読み込み実装とWebのCSPを照合しました。

### 原因と解決

`firebase_core_web` 3.9.1は、インラインスクリプトでローダー関数を定義し、その関数からFirebase JavaScript SDKを動的importします。しかし `web/index.html` のCSPは、このインラインスクリプトを許可していませんでした。結果として関数が定義されず、呼び出し時に例外になります。外部配信元の `www.gstatic.com` を許可するだけでは、このローダー本文の実行許可にはなりません。

対策として、使用中のSDKが生成するローダー本文のSHA-256ハッシュをCSPに追加しました。Firebase JavaScript SDK 12.15.0の5サービス（Core・Auth・Firestore・Functions・App Check）について、Trusted Typesあり／なしの2分岐、合計10種類を許可しています。任意のスクリプトを許可する `script-src 'unsafe-inline'` は追加していません。

今回の解決につながった変更はWebのCSP修正です。調査初期に行ったネイティブiOSのPodfile設定は、Safari／PWAには適用されません。匿名認証の無効化やreCAPTCHAの設定不一致も候補として調査しましたが、今回それらが原因だったとの確認はありません。

### 実施した変更

| 対象 | 内容・目的 |
| --- | --- |
| [web/index.html](../web/index.html) | Firebaseのローダー本文だけをCSPハッシュで許可。 |
| [tool/firebase_csp.mjs](../tool/firebase_csp.mjs) | インストール済みの依存SDKからローダー本文・バージョン・登録サービスを読み取り、ハッシュを生成／照合。 |
| [.github/workflows/deploy.yml](../.github/workflows/deploy.yml) | 公開前にハッシュの整合性を確認。SDK更新で古くなったCSPを検出。 |
| [tool/firebase_csp_test.mjs](../tool/firebase_csp_test.mjs) | ブラウザで修正前後の読み込み可否と、未許可スクリプトの拒否を検証。 |
| [weather_service.dart](../lib/services/weather_service.dart)、[firebase_security_service.dart](../lib/services/firebase_security_service.dart) | 設定・認証・アクセス検証等の診断コードを保持。Webのキー不足を明示的なFirebase例外として扱う。 |
| [car_setting_page_environment.dart](../lib/pages/car_setting_page_environment.dart)、[quick_run_log_page.dart](../lib/pages/quick_run_log_page.dart) | 天気カードに原因別の説明と診断コードを表示。例外の生メッセージ・トークン・座標は表示しない。 |
| [location_service.dart](../lib/services/location_service.dart) | 同時に発生した権限要求・現在位置取得を共有し、競合を防止。完了後は破棄し再試行可能にする。ネイティブ環境では権限要求前に位置情報サービスの有効状態を確認。 |
| [ios/Podfile](../ios/Podfile) | ネイティブiOS向けに使用中のみの位置情報権限設定を追加。今回のWeb障害とは別の改善。 |

### 検証結果

- Dartの関連テスト32件が成功。対象は `location_service_test.dart`、`weather_service_test.dart`、`widget_test.dart`、`car_setting_page_refactor_test.dart`。権限・同時取得・再試行・診断表示・スマートフォン幅での表示を含みます。
- 変更したDartコードの静的解析は指摘なし。
- WindowsのヘッドレスEdgeで、修正前CSPではローダー10種類すべてが拒否され、修正後はすべて実行・動的importに成功することを確認。未許可のインラインスクリプトは両方で拒否されました。SDK応答は模擬しており、このテスト自体は本番認証・天気APIを呼びません。
- `node tool/firebase_csp.mjs --check` で10種類のハッシュの一致を確認。
- CSP修正後、ユーザーからiPhoneで動作したとの報告を受領。

### 再発防止と更新手順

Firebase関連の依存パッケージを更新したときは、プロジェクト直下で次を実行します。

```sh
flutter pub get
node tool/firebase_csp.mjs
node tool/firebase_csp.mjs --check
```

生成された `web/index.html` の差分を確認してコミットします。ローダーの構造が変わった場合は生成スクリプトがエラーになるため、SDKの実装を確認して生成処理を更新してください。CIのハッシュ照合は毎回実施されますが、Playwrightのブラウザ回帰テストはCIには組み込んでいません。実行方法は後述します。

Web公開後は新しい版を読み込んだiPhoneで再取得を確認します。再発時には天気カードのエラーコードを記録し、下表に沿って調査します。PWAの問題に対してネイティブの権限設定だけを変更しても、このCSP障害は解消しません。

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

新セッティング画面の天気取得は、現在位置取得 → 必要ならFirebase SDK・アプリ初期化 → Firebase App Check初期化 → 必要なら匿名認証 → `getCurrentWeather` Function → OpenWeatherの順です。従来の「天気サービスに接続できませんでした」は、認証や設定不足も含む共通表示で、通信障害とは限りません。修正後の天気カードには説明とエラーコードが表示されます。位置情報の拒否やタイムアウトは従来どおり別の案内です。

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
