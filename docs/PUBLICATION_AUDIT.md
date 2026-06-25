# 公開前監査メモ

作成日: 2026-06-22

## 対応状況

2026-06-25 にコード側の主要問題を修正しました。Firebase Console、Google Cloud Console、GitHub、Play Console、App Store Connect で必要な作業は [PUBLISHING_SETUP_GUIDE.md](./PUBLISHING_SETUP_GUIDE.md) に分離しています。

コード側で対応済み:

- 公開 HTTP Functions の定義と Web 側フォールバックを削除
- callable Functions に Auth、App Check、入力上限、レート制限、最大インスタンス数を追加
- Firestore Rules を追加し `firebase.json` の配布対象に設定
- GitHub Actions から Gemini / OpenWeather secret の `.env` 書き出しを削除
- iOS `Info.plist` の XML と権限説明を修正
- Android release build の debug 署名利用を廃止
- 未使用 ML Kit 依存を削除
- release でアプリログを出さない共通 logger に移行
- 独自 `web/sw.js` を削除し、Web manifest の文字化けを修正
- Functions 依存関係を更新し、`npm audit --omit=dev` の脆弱性を解消

外部作業が必要:

- 公開用 application ID / Bundle ID の確定
- Android upload key と Play App Signing の設定
- Firebase Auth、App Check、Functions Secret、Firestore TTL の設定
- 旧 public Functions の削除
- Firebase クライアント API key のプラットフォーム制限
- iOS release build とストア申告

このメモは、RC Setting Manager を公開する前に確認した API、Firebase、ビルド設定、権限、ログ、依存関係まわりの調査結果です。

## 結論

このまま公開するのはまだ推奨しません。

Gemini / OpenWeather の実 API キーを Flutter アプリへ直接埋め込まない構成になっている点は良い状態です。一方で、公開 Cloud Functions が保護不足で、誰でも API コストを発生させられる可能性があります。また Android release build と iOS の `Info.plist` に公開前ブロッカーがあります。

## 良い点

- `.env` は `.gitignore` 対象で、Git 管理にも入っていません。
- `google-services.json` / `GoogleService-Info.plist` の実ファイルは管理対象になく、example のみです。
- Gemini / OpenWeather の実キーは Flutter アプリや `build/web` には見つかりませんでした。
- Gemini / OpenWeather は Firebase Functions の Secret Manager 経由に寄せられています。
- Web release build は成功しました。

## 公開前ブロッカー

### 1. Cloud Functions が実質誰でも呼べる

対象:

- `functions/index.js`
- `lib/services/firebase_functions_service.dart`

`functions/index.js` の `onPublicCallable` で `cors: true`、`invoker: "public"` が設定され、`generateGeminiContentPublic` / `getCurrentWeatherPublic` / `validateOpenWeatherApiKeyPublic` が公開されています。

Web クライアント側も `lib/services/firebase_functions_service.dart` で Web の場合 public HTTP Functions に切り替えています。

リスク:

- 第三者が Gemini API を叩き続けて課金を発生させられる。
- OpenWeather API の quota を消費される。
- CORS が全許可のため、別サイトからも呼び出しやすい。
- Gemini 入力のサイズ制限が弱く、base64 画像などでコスト増や DoS に近い負荷を作れる。

推奨対応:

- Firebase App Check を有効化し、Functions 側で enforcement する。
- 可能なら Firebase Auth 必須にする。
- ユーザー単位/IP単位のレート制限を入れる。
- `contents` の件数、文字数、画像サイズ、mime type を制限する。
- Gemini だけでも public endpoint をやめ、Callable Functions + App Check に寄せる。

### 2. Android release build が失敗する

実行結果:

```bash
flutter build apk --release
```

結果: 失敗

主因:

R8 が `google_mlkit_text_recognition` の script-specific TextRecognizer クラスを見つけられません。

例:

- `com.google.mlkit.vision.text.japanese.JapaneseTextRecognizerOptions`
- `com.google.mlkit.vision.text.chinese.ChineseTextRecognizerOptions`
- `com.google.mlkit.vision.text.korean.KoreanTextRecognizerOptions`
- `com.google.mlkit.vision.text.devanagari.DevanagariTextRecognizerOptions`

推奨対応:

- `google_mlkit_text_recognition` の日本語など script-specific 依存関係を Android 側に追加する。
- 使わない script を無効化できる構成なら無効化する。
- 必要に応じて `missing_rules.txt` の内容を ProGuard rules に反映する。ただし `-dontwarn` だけで実行時問題が消えるとは限らないため、依存関係追加を優先する。

### 3. iOS の `Info.plist` が XML として壊れている

対象:

- `ios/Runner/Info.plist`

問題:

`NSCameraUsageDescription`、`NSPhotoLibraryUsageDescription`、`NSLocation...UsageDescription` の `string` タグが `</string>` ではなく文字列内に `/string>` として入っており、XML パースに失敗します。文言も mojibake しています。

推奨対応:

- 権限説明を正しい日本語に直す。
- XML としてパースできることを確認する。
- App Store 審査向けに、何のためにカメラ/写真/位置情報を使うかを明確に書く。

### 4. Android release signing が debug のまま

対象:

- `android/app/build.gradle`

問題:

`release` build type が `signingConfigs.debug` を使っています。

推奨対応:

- 公開用 keystore を作成する。
- `key.properties` は Git 管理外にする。
- release 用 signing config を設定する。

### 5. パッケージ ID / Bundle ID が `com.example...`

対象:

- `android/app/build.gradle`
- `ios/Runner.xcodeproj/project.pbxproj`
- `lib/firebase_options.dart`

問題:

Android は `com.example.settingsheet_manager`、iOS は `com.example.settingsheetManager` になっています。

推奨対応:

- 公開用の固有 ID に変更する。
- Firebase の Android/iOS アプリ設定も新 ID に合わせて再作成または更新する。
- Google Cloud の API key 制限も新 ID / SHA / Bundle ID に合わせる。

## API / セキュリティ上の問題

### Firebase API key は公開成果物に入る

`build/web/main.dart.js` に Firebase Web API key は入っていました。

これは Firebase クライアント SDK では公開前提の情報ですが、制限なしで放置してよいものではありません。

推奨対応:

- Google Cloud Console で HTTP referrer 制限を設定する。
- Android key は package name + SHA-1/SHA-256 で制限する。
- iOS key は Bundle ID で制限する。
- Firebase Auth の承認済みドメインを公開ドメインのみに絞る。
- Firestore Rules / App Check で実データを守る。

### Firestore Rules が repo から確認・deploy できない

問題:

`firebase.json` に Firestore rules の deploy 設定がありません。docs には rules 例がありますが、実運用ルールとして repo 管理されていません。

また、実装では `guest_users/{uid}/data/...` を使いますが、docs の rules 例は `users/{userId}` 中心です。

推奨対応:

- `firestore.rules` を repo に追加する。
- `firebase.json` に rules 設定を追加する。
- `users/{uid}` と `guest_users/{uid}` の owner-only rules を明示する。
- 可能なら rules test を追加する。

### GitHub Actions が不要な秘密情報を `.env` に書いている

対象:

- `.github/workflows/deploy.yml`

問題:

Web build 前に `.env` へ `OPENWEATHER_API_KEY` と `GEMINI_API_KEY` を書いています。現状では `pubspec.yaml` の assets に `.env` がないため配布物には入っていませんでしたが、将来 `.env` を asset 登録すると漏えいします。

推奨対応:

- Web build workflow から Gemini / OpenWeather の secret 書き込みを削除する。
- Firebase client config を使う場合も、必要な `--dart-define` だけに限定する。
- 第三者 API キーは Functions secrets のみに置く。

## ログ / プライバシー

`flutter analyze` で production `print` が多数検出されました。

特に注意が必要なログ:

- `lib/services/weather_service.dart`: 緯度経度をログ出力
- `lib/services/auth_service.dart`: メールアドレス、UID、Auth エラー詳細をログ出力
- `lib/pages/ocr_import_page.dart`: 画像サイズ、OCR マッピング結果をログ出力
- `lib/main.dart`: Flutter error stack trace、Firebase project/app 情報、current user UID をログ出力

推奨対応:

- 公開版では `kDebugMode` でログをガードする。
- メール、UID、位置情報、OCR結果などの個人情報に近い情報は release で出さない。
- ユーザーに表示するエラー文も内部例外をそのまま出さない。

## 依存関係 / テスト

### `flutter analyze`

結果:

- 221 issues
- 多くは `avoid_print` と deprecated API

主な内容:

- production `print`
- `withOpacity` deprecated
- `DropdownButtonFormField.value` deprecated
- `Radio.groupValue` / `onChanged` deprecated

### `flutter test`

結果:

- 2 件失敗

失敗箇所:

- `test/car_test.dart:222`
- `test/settings_provider_test.dart:241`

公開前に、期待値と実装のどちらが正しいか確認して修正が必要です。

### `npm audit --omit=dev`

結果:

- moderate 8 件
- `uuid` 起点で `firebase-admin` / Google Cloud 系 transitive dependency に影響

推奨対応:

```bash
cd functions
npm audit fix
```

修正後に Functions の lint と deploy dry-run 相当を確認してください。

### `flutter pub outdated`

Firebase 系、`share_plus`、`geolocator`、`google_fonts`、`flutter_lints` など多数が古いです。

公開前に全 major update を無理に入れる必要はありませんが、以下は優先確認対象です。

- Firebase packages
- `share_plus`
- `geolocator`
- `permission_handler`
- `image_picker`
- `google_mlkit_text_recognition`

## Web / PWA

Web release build は成功しました。

生成物の確認結果:

- `build/web/.env` は存在しません。
- Gemini / OpenWeather のキーは見つかりません。
- Firebase Web API key と Functions URL は `main.dart.js` に含まれます。

注意:

- `web/sw.js` に `throw error;` がありますが、そのスコープに `error` が定義されていません。Flutter 標準の `flutter_service_worker.js` と併用される構成にも見えるため、PWA の実動作確認が必要です。
- `manifest.json` などにも mojibake が残っています。

## 公開前の推奨対応順

1. Functions を public 無制限から、Auth/App Check/レート制限/入力サイズ制限ありに変更する。
2. Android release build の R8 / ML Kit 問題を修正する。
3. iOS `Info.plist` と権限説明の mojibake/XML破損を修正する。
4. Android/iOS の package ID / bundle ID、release signing、version を公開用に設定する。
5. Firestore rules を repo 管理し、`users` / `guest_users` の owner-only rules を deploy 対象にする。
6. production ログを削減する。
7. `flutter test` の失敗 2 件を直す。
8. Functions の `npm audit` と Flutter 依存関係の更新方針を決める。
9. README/docs/manifest/UI 文言の mojibake を直す。

## 実行した主な確認コマンド

```bash
git status --short
rg --files
rg -n "AIza|api[_-]?key|OPENWEATHER|GEMINI|Secret|token|password|private_key" -S .
flutter analyze
flutter test
flutter pub outdated
flutter build web --release --base-href "/RC_Setting_Manager/"
flutter build apk --release
npm audit --omit=dev
```

## 補足

Android の `INTERNET` 権限は `android/app/src/main/AndroidManifest.xml` には直接ありませんが、release の merged manifest には依存プラグイン経由で入っていました。そのため、通信権限そのものは今回の主問題ではありません。
