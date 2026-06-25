# 公開に必要な外部設定手順

更新日: 2026-06-25

コード側のセキュリティ修正後に必要な Firebase、Google Cloud、GitHub、ストア側の作業です。App Check の切替でサービスを止めないため、原則として以下の順番で実施してください。

## 1. 公開用アプリ識別子を決める

現在の Android application ID と iOS Bundle ID は `com.example...` のままです。公開前に、所有しているドメインを逆順にした永続的な ID を決めてください。

例:

- Android: `jp.example.rcsettingmanager`
- iOS: `jp.example.rcSettingManager`

一度ストア公開した ID は変更できません。

変更対象:

- `android/app/build.gradle` の `namespace` と `applicationId`
- `android/app/src/main/kotlin/.../MainActivity.kt` の package と配置先
- `ios/Runner.xcodeproj/project.pbxproj` の `PRODUCT_BUNDLE_IDENTIFIER`
- Firebase Console の Android / iOS アプリ登録

変更後、FlutterFire CLI で設定を再生成します。

```bash
dart pub global activate flutterfire_cli
flutterfire configure --project=rc-setting-manager
```

生成された `google-services.json` と `GoogleService-Info.plist` は、このリポジトリの方針では Git にコミットしません。CI でモバイルビルドする場合は、暗号化した CI Secret から配置してください。

## 2. Firebase Authentication を有効化する

Firebase Console の `Authentication` > `Sign-in method` で以下を有効にします。

- Anonymous
- Email/Password（アカウント機能を公開する場合）

Functions は認証済みリクエストのみ受け付けます。未ログイン状態の AI・天気機能は、アプリ側で匿名認証を自動実行します。

## 3. Firebase App Check を登録する

Firebase Console の `App Check` で各アプリを登録します。

### Web

1. Web アプリに reCAPTCHA v3 または reCAPTCHA Enterprise を登録します。
2. GitHub Pages の公開ドメインを許可ドメインへ追加します。
3. Site Key を GitHub リポジトリの `Settings` > `Secrets and variables` > `Actions` > `Variables` に登録します。

変数名:

```text
FIREBASE_APP_CHECK_WEB_KEY
```

Site Key は公開情報です。Secret ではなく Repository Variable として登録します。

### Android

1. 公開用 application ID の Android アプリを Firebase に登録します。
2. Play Console と Firebase App Check で Play Integrity を有効化します。
3. 公開署名鍵と upload key の SHA-256 を Firebase の Android アプリ設定へ登録します。

### iOS

1. 公開用 Bundle ID の iOS アプリを Firebase に登録します。
2. App Attest を有効化します。
3. App Attest 非対応端末向けに DeviceCheck も利用できる状態にします。

### デバッグ端末

Debug build は App Check Debug Provider を使用します。初回起動時に出力される debug token を Firebase Console の App Check 管理画面へ登録してください。

## 4. Functions Secret を登録する

Firebase CLI で本番 API キーを Secret Manager に登録します。

```bash
firebase functions:secrets:set GEMINI_API_KEY
firebase functions:secrets:set OPENWEATHER_API_KEY
```

Gemini / OpenWeather のキーを `.env`、Flutter の asset、GitHub Actions の Web build に渡さないでください。

## 5. Firestore Rules を先に配布する

```bash
firebase deploy --only firestore:rules
```

`users/{uid}` と `guest_users/{uid}` は本人だけが読み書きできます。それ以外のクライアントアクセスは拒否されます。

Functions のレート制限用コレクション `_function_rate_limits` は Admin SDK だけが利用します。

Firestore の TTL 設定で、次を登録してください。

- Collection group: `_function_rate_limits`
- Timestamp field: `expiresAt`

TTL は必須のセキュリティ機能ではありませんが、期限切れレート制限ドキュメントを自動削除するため推奨します。

## 6. Web を先に再配布する

GitHub Repository Variable の登録後、`main` への push または Actions の再実行で Web を配布します。

新しい Web build が App Check token と Firebase Auth token を付けて callable Functions を呼べることを確認してください。

## 7. 保護済み Functions を配布する

```bash
firebase deploy --only functions
```

配布後に AI、OCR、現在地の天気取得を実機で確認します。

現在の制限:

- Gemini: 1ユーザーあたり10分で10回
- 天気: 1ユーザーあたり10分で60回
- OpenWeather 設定確認: 1ユーザーあたり1時間で2回
- Gemini 画像: 1枚8 MiB、合計10 MiBまで
- Gemini テキスト: 合計50,000文字まで

## 8. 旧公開 HTTP Functions を削除する

新しい callable Functions の動作確認後、旧エンドポイントを明示的に削除します。

```bash
firebase functions:delete generateGeminiContentPublic \
  getCurrentWeatherPublic \
  validateOpenWeatherApiKeyPublic \
  --region asia-northeast1 \
  --force
```

削除後、次の URL が利用できないことを確認してください。

```text
https://asia-northeast1-rc-setting-manager.cloudfunctions.net/generateGeminiContentPublic
https://asia-northeast1-rc-setting-manager.cloudfunctions.net/getCurrentWeatherPublic
https://asia-northeast1-rc-setting-manager.cloudfunctions.net/validateOpenWeatherApiKeyPublic
```

## 9. Firebase クライアント API キーを制限する

Google Cloud Console の `APIs & Services` > `Credentials` で、FlutterFire が生成した各クライアントキーを用途別に制限します。

- Web: GitHub Pages の本番 URLを HTTP referrer に指定
- Android: application ID と公開署名 SHA-1 / SHA-256 を指定
- iOS: Bundle ID を指定

必要な Firebase API 以外は API restrictions で無効化してください。

Firebase Auth の `Authorized domains` も、実際に使う本番ドメインだけに整理します。

## 10. Android の公開署名を設定する

upload key を安全な場所で作成します。

```bash
keytool -genkeypair -v \
  -keystore rc-setting-manager-upload.jks \
  -keyalg RSA -keysize 2048 -validity 10000 \
  -alias upload
```

`android/key.properties.example` を参考に、コミット対象外の `android/key.properties` を作成します。

```properties
storePassword=実際のパスワード
keyPassword=実際のパスワード
keyAlias=upload
storeFile=../keystores/rc-setting-manager-upload.jks
```

鍵、パスワード、`key.properties` は Git にコミットしないでください。Play App Signing を有効化し、upload key と app signing key の証明書を別々に保管します。

## 11. iOS を macOS で検証する

```bash
flutter clean
flutter pub get
cd ios
pod install --repo-update
cd ..
flutter build ipa --release
```

Xcode で Signing & Capabilities、Bundle ID、Team、App Attest capability、利用目的文言を確認します。

## 12. ストア申告とプライバシーポリシー

少なくとも以下をプライバシーポリシーとストア申告へ反映してください。

- 位置情報を天気・近隣コース取得に利用すること
- OCR 画像と入力したセット情報を Gemini API へ送信すること
- Firebase Authentication と Firestore を利用すること
- 匿名アカウントでも Firebase UID が発行されること
- データ削除、アカウント削除、問い合わせ方法

Gemini と OpenWeather の利用規約、データ保持条件、商用利用条件も公開前に確認してください。
