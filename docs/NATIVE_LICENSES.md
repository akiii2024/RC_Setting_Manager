# Native依存のライセンス収集

## Android

`tool/native_licenses.gradle` は `releaseRuntimeClasspath` の外部Maven依存を解決し、POMと配布AAR/JAR内の `LICENSE` / `NOTICE` / `COPYING` を `build/native-licenses/artifacts.json` へ保存する。アプリのreleaseビルドや署名は実行しない。

`tool/native_licenses.mjs` はこの入力から以下を生成する。

- `assets/licenses/android_native.txt`: 依存名・バージョン、POMのライセンス宣言・URL、内蔵本文、Apache 2.0および補足ライセンスの原文
- `assets/licenses/android_native_sources.json`: 各配布ファイルの対応、宣言ライセンス、内蔵本文のSHA-256

Androidでは「設定 → アプリについて → オープンソースライセンス」の **Android native SDKs** に本文を表示する。FlutterエンジンのライセンスはFlutterが同梱する `NOTICES` を参照する。

### 再生成

JDK 17などプロジェクトが対応するJavaと、依存ダウンロード用のネットワーク接続が必要。システム設定の変更は不要。

```powershell
flutter pub get
cd android
.\gradlew.bat :app:collectNativeLicenses --init-script ../tool/native_licenses.gradle --console=plain
cd ..
node tool/native_licenses.mjs
```

GitHub ActionsのAndroidリリースでも、同じ収集・生成をテストとAPKビルドの前に実行する。ライセンス情報のない依存や、未対応のライセンス名、固定した補足本文と対象バージョンの不一致がある場合は生成を失敗させる。依存更新時には生成差分とライセンス条件をレビューする。

通常の `:app:dependencies --configuration releaseRuntimeClasspath` は、既存の署名チェックが引数の `releaseRuntimeClasspath` にも反応する。専用の `collectNativeLicenses` タスクはこの問題を避け、署名チェック自体は変更しない。

### 確認した範囲と限界

2026-10-22に現行依存を実際に解決し、重複を除く159配布ファイルを生成対象とした。Firebase、Google Play Services、AndroidX、Media3、Tink等を含む。

- Firebase Auth 24.2.0、Firestore 26.6.0、Storage 22.0.2
- Google Play Services Location 21.2.0
- AndroidX Core 1.18.0、Media3 1.9.2、DataStore 1.1.7
- Tink Android 1.9.0

POMで本文を親から継承する依存は親POMも取得する。追加本文は上流の公式リポジトリから取得し、取得元を同梱文書に残す。全依存をApacheと推測する方式にはしていない。SDK利用規約の宣言はOSSライセンスと区別して名称・参照先を保持する。

ただし、POMとバイナリ内の文書が、各上流ソースの全NOTICEを網羅していることまで証明する仕組みではない。配布元がバイナリに含めない追加NOTICEや、将来のライセンス変更は個別レビューが必要。署名済みrelease APKの実機確認も別途行う。

補助ツール `tool/native_licenses_android.ps1` はAPKに実際に入った文書を抽出する。依存一覧を収集する主経路の代わりにはならない。

```powershell
.\tool\native_licenses_android.ps1 -ApkPath build\app\outputs\apk\release\app-release.apk -OutputPath build\native-licenses\apk-notices.txt
```

## iOSネイティブ版

現在のREADME上のiOS公開方式はPWA。iOSネイティブ版を配布する前に、macOSでPodの実体と通知文書を確認する。

```sh
flutter pub get
cd ios
pod install --deployment
cd ..
node tool/native_licenses_ios.mjs
flutter build ipa
```

`tool/native_licenses_ios.mjs` はCocoaPods生成の `Pods-Runner-acknowledgements.plist` から本文を保持し、`Podfile.lock` とともに `assets/licenses/ios_native.txt` を生成する。このファイルを生成してからビルドすると、iOS/macOSのライセンス一覧に **Apple native SDKs** が現れる。存在しないファイルを無条件に読み込むことはしない。

- 現在の `ios/Podfile.lock` は古いFirebase 11.15.0やML Kit等を含むため、現行Flutter依存との整合性を確認する。`pod install --deployment` が失敗した場合は原因と依存差分を確認してlockを更新し、再収集する。
- 各Podspecのlicense指定と、実体の `LICENSE*` / `NOTICE*` / `COPYING*` を照合し、CocoaPodsのacknowledgementsにない追加文書を保持する。
- IPAに本文が同梱され、アプリから閲覧でき、OpenWeatherのリンクがブラウザで開くことを実機確認する。
- このWindows環境ではPod取得・iOSビルド・Swiftのコンパイルは未実施。iOSネイティブ版まで対応確認済みとは扱わない。

## その他の権利情報

- Linux版の `dbus` / `geoclue` / `gsettings` はMPL-2.0。Linux版を配布する場合には対象コードの提供方法を確認する。
- ユーザー確認でランチャーアイコンは自作。サーキットデータは「AIにまとめてもらったはず」との説明を受けたが、元資料・収集元は未特定。[素材・データの作成経緯](ASSET_PROVENANCE.md)に記録する。
- アプリ自体にMIT等のライセンスを付ける判断は、第三者の通知義務とは別である。
