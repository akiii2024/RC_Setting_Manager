# 公開前セキュリティ監査

更新日: 2026-07-17

## 判定

コード側で対応できる主要な公開前セキュリティ対策と検証は完了しています。

ただし、署名鍵、Firebase / Google Cloud Console、ストア申告はリポジトリ外の作業です。後述の「公開を止める外部作業」が終わるまでは、ストア版や本番 Functions を公開しないでください。具体的な順序は [PUBLISHING_SETUP_GUIDE.md](./PUBLISHING_SETUP_GUIDE.md) に記載しています。

## 今回の対応

### 秘密情報とAPI

- `.env`、モバイル Firebase 設定ファイル、署名鍵、`key.properties` が Git 管理外であることを確認
- Firebase クライアント API キーとサーバー秘密情報の違いをドキュメントで明確化
- Gemini Functions の API キーを URL query ではなく `x-goog-api-key` ヘッダーで送信
- AIプロバイダーの入力を、プロンプト50,000文字、system 20,000文字、schema 100,000文字、出力8,192 token、画像10 MiBに制限
- XMLインポートを5 MiBに制限し、巨大入力をパース前に拒否
- release UI で内部例外内容を表示しないよう変更

### Firebase

- callable Functions は Authentication、App Check、レート制限、入力検証、timeout、最大インスタンス数を使用
- Firestore Rules を owner-only に加えて、許可するパス、フィールド、型、件数、文字数まで制限
- 不明なクライアントパスは全面拒否し、Functions内部コレクションは Admin SDK 専用
- Firestore Rules を公式エミュレータでコンパイル確認

### Android / Apple

- Androidのアプリバックアップと平文HTTPを明示的に禁止
- Androidの信頼アンカーをsystem CAに限定する Network Security Config を追加
- release署名がない場合は、Gradle設定段階でリリース成果物の生成を拒否
- 依存関係が要求する Android Gradle Plugin 8.9.1へ更新
- iOS / macOSでATSの任意HTTP通信を禁止
- macOSのcamera、位置情報、ユーザー選択ファイル、Keychain access groupを最小権限で設定
- 現在の公開版から `/login` の直接ルートを外し、未完成のオンラインアカウント機能を公開しない構成に変更

### Web / CI

- JavaScriptをインライン実行せず、CSPでscript、connect、frame、worker等の接続先を制限
- NginxにCSP、Permissions-Policy、Referrer-Policy、HSTS、nosniff、clickjacking対策を追加
- 非ハッシュJSを1年間immutable cacheする設定をやめ、更新が反映されるよう修正
- GitHub Actionsの書込権限をdeploy jobだけに限定
- 使用するGitHub Actionsを検証済みcommit SHAへ固定
- Dependabotでpub、npm、GitHub Actionsを毎週確認

### 依存関係

- `flutter pub upgrade` で互換範囲内のロック依存57件を更新
- Cloud Functions本番依存の `npm audit --omit=dev` は既知脆弱性0件
- major updateは一括適用せず、Dependabot PRごとにテストして更新する方針

## 検証結果

| 検証 | 結果 |
|---|---|
| `flutter analyze` | 問題0件 |
| `flutter test` | 86件すべて成功 |
| Functions ESLint | 成功 |
| Functions tests | 5件すべて成功 |
| `npm audit --omit=dev` | 既知脆弱性0件 |
| Firestore Rules emulator compile | 成功 |
| Web release build | 成功 |
| CSP下のheadless Chrome起動 | 初回描画成功、ブラウザsecurity errorなし |
| Android debug APK build | 成功 |
| XML / JSON / YAML構文 | 成功 |
| `git diff --check` | 問題なし |

Web buildは現在JavaScript rendererを使用します。Wasm dry runでは `flutter_secure_storage_web` と旧JS interop依存が非対応と報告されますが、現在配布するJavaScript buildの失敗ではありません。

Android release buildは、公開用 `android/key.properties` がない現状では意図的に失敗します。実際のupload key設定後に、release AABを改めてビルド・署名検証してください。

## 公開を止める外部作業

- [ ] Android upload keyを安全な場所で作成し、Play App Signingを有効化する
- [ ] `android/key.properties` をGit管理外で設定し、release AABをビルドする
- [ ] macOS上のXcodeでiOS / macOS署名、entitlements、実機権限ダイアログを確認する
- [ ] `com.aki.rcsettings` を最終application ID / Bundle IDとして使用できることを確認する
- [ ] Firebase AuthenticationのAnonymousだけを有効化する
- [ ] Web / Android / iOSのApp Checkを登録し、正規token確認後にConsole側 enforcementを有効化する
- [ ] Functions Secretを登録し、Firestore Rules、Functionsの順に配布する
- [ ] `_function_rate_limits.expiresAt` のFirestore TTLを設定する
- [ ] 旧public HTTP Functionsが残っている場合は削除する
- [ ] Firebaseクライアントキーのreferrer / package+SHA / Bundle ID制限を設定する
- [ ] Firebase AuthのAuthorized domainsを本番ドメインだけに整理する
- [ ] Cloud Billing予算通知、API quota、Functions / App Check監視を設定する
- [ ] プライバシーポリシー、問い合わせ窓口、データ削除方法を公開し、各ストアのデータ申告を完了する
- [ ] 公開バージョンを決め、現在の `0.0.1+1` を必要に応じて更新する

Email/Passwordやクラウド同期を将来公開する場合は、アプリ内アカウント削除、関連Firestoreデータの再帰削除、再認証、外部Web削除導線を追加してから再監査してください。
