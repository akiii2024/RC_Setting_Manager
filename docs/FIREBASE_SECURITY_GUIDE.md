# Firebase セキュリティ設定ガイド

更新日: 2026-07-17

## 秘密情報の扱い

- Firebase クライアント SDK の API キーはアプリ識別情報であり、生成済みの `firebase_options.dart` に含まれます。データ保護は API キーの秘匿ではなく、Authentication、App Check、Firestore Rules、API キー制限で行います。
- アプリ運営者の Gemini / OpenWeather API キーは Firebase Functions の Secret Manager だけに保存します。Flutter の `--dart-define`、asset、`.env`、GitHub Actions の Web ビルドへ渡してはいけません。
- ユーザーが設定する OpenAI / Anthropic / Gemini API キーは、モバイル・デスクトップでは OS の資格情報ストアに保存します。Web では永続保存せず、ページを閉じるまでのメモリにだけ保持します。
- `google-services.json`、`GoogleService-Info.plist`、署名鍵、`key.properties` は現在のリポジトリ方針では Git 管理外です。

Functions の Secret は Firebase CLI で登録します。

```bash
firebase functions:secrets:set GEMINI_API_KEY
firebase functions:secrets:set OPENWEATHER_API_KEY
```

## 必須の Firebase 設定

### Authentication

天気などの callable Functions は認証済みリクエストだけを受け付けます。現在の公開版では Firebase Console で次を有効にしてください。

- Anonymous

Email/Password とクラウド同期は、アカウント削除と関連データ削除を含むアカウント管理機能を完成させるまで有効にしません。

`Authorized domains` は、localhost と実際の本番ドメインだけに整理します。

### App Check

各プラットフォームを Firebase Console の App Check に登録します。

- Web: reCAPTCHA v3 または reCAPTCHA Enterprise
- Android: Play Integrity。Play App Signing と upload key の SHA-256 を登録
- iOS: App Attest。必要に応じて DeviceCheck fallback

Web の Site Key は秘密情報ではありません。GitHub Repository Variable `FIREBASE_APP_CHECK_WEB_KEY` に登録します。

登録直後はメトリクスを確認し、正規クライアントが token を送れていることを確認してから Firebase Console 側の enforcement を有効にします。Functions コード側は `enforceAppCheck: true` です。

### Firestore Rules

リポジトリの [firestore.rules](../firestore.rules) は、次の方針です。

- `users/{uid}` と `guest_users/{uid}` は本人だけがアクセス可能
- アプリが使用する既知のドキュメント／サブコレクションだけ書き込み可能
- 保存設定と走行ログはフィールド、型、件数、文字数を検証
- その他のクライアントアクセスは全面拒否
- Functions の `_function_rate_limits` は Admin SDK だけが利用

Rules は Functions より先に配布します。

```bash
firebase deploy --only firestore:rules
```

期限切れレート制限データの削除用に、Firestore TTL を設定します。

- Collection group: `_function_rate_limits`
- Timestamp field: `expiresAt`

## Google Cloud の API キー制限

FlutterFire が生成したクライアントキーは、プラットフォームごとに分けて制限します。

- Web: 本番 URL の HTTP referrer
- Android: `com.aki.rcsettings` と公開署名の SHA-1 / SHA-256
- iOS: `com.aki.rcsettings` の Bundle ID

API restrictions では、実際に利用する Firebase API だけを許可してください。制限内容を変更した後は、認証、Firestore、App Check、Functions 呼び出しを各実機で再確認します。

## 監視とインシデント対応

- Google Cloud Billing の予算通知と quota を設定する
- Functions のエラー率、呼出回数、インスタンス数を監視する
- App Check の無効 token、Authentication の異常な登録数、Firestore の拒否数を確認する
- API キー漏えい時は、対象キーを無効化・再発行し、Secret Manager またはユーザー設定を更新する
- 不正アクセス時はログの保存、影響範囲の特定、Rules／認証 token の失効、ユーザー通知を順に行う

## 配布前チェック

```bash
flutter analyze
flutter test
flutter build web --release --base-href "/RC_Setting_Manager/" \
  --dart-define=FIREBASE_APP_CHECK_WEB_KEY=<site-key>
cd functions
npm test
npm run lint
npm audit --omit=dev
```

Firebase Console、Google Cloud、署名、ストア申告を含む全手順は [PUBLISHING_SETUP_GUIDE.md](./PUBLISHING_SETUP_GUIDE.md) を参照してください。
