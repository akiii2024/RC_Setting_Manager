# ライセンス・帰属表示の調査

調査日: 2026-10-22

## 対応状況（2026-10-22）

以下の調査時点の指摘に対し、次を実装した。

- AboutからFlutter標準ライセンス画面を開く導線を追加。
- `image` / `archive` の追加文書とApache 2.0本文を同梱・登録。解決済みバージョンと原文を照合するツールとCIチェックを追加。
- ユーザーからOpenWeatherはFreeプランとの確認を受け、通常編集・紙UI・クイック走行メモに公式ロゴ・提供元文言・HTTPSリンクを追加。Android/iOSではブラウザを起動する。
- Android release依存159配布ファイルのPOM・内蔵通知と補足本文を実際に収集し、Androidのライセンス一覧へ統合。APKリリース時の再生成も追加。
- iOSネイティブ版向けのCocoaPods通知収集ツールを追加。macOSでの生成・コンパイル・実機確認は未実施。
- ユーザー確認でランチャーアイコンは自作。サーキットデータはAIで整理した可能性があるが、元資料は未特定。[素材・データの作成経緯](ASSET_PROVENANCE.md)に確認済み事項と残件を分けて記録。

手順と残件は [NATIVE_LICENSES.md](NATIVE_LICENSES.md) を参照。以下は修正前の調査記録として残す。

### 対応後の検証

- 変更したDartファイルへ `dart format` を適用。
- `flutter analyze --no-pub`: 指摘なし。
- `flutter test --no-pub`: 全430件成功。
- Web releaseビルドと `tool/check_public_web.mjs` 成功。Web/APK両方でライセンス本文・ロゴ8ファイルを元ファイルとSHA-256照合。
- CocoaPods通知の解析・空文書拒否のNodeテスト: 2件成功。
- Android debug APK: JDK 17、実行時のみ `-Pkotlin.incremental=false` を指定してビルド成功。WindowsのC/Eドライブ間でKotlinの増分キャッシュが失敗するための回避で、プロジェクト設定は変更していない。
- APK内の公式ロゴ、フォント3種の本文、image/archiveの追加文書、Apache本文、Android native通知が元ファイルと一致することをSHA-256で照合。
- 署名済みrelease APK、iOSネイティブ版、実機ブラウザ起動は未確認。素材についてはアイコンの自作を確認済みで、サーキットデータの元資料・収集元の確認が残る。

## 調査時点の結論（修正前）

現状を「ライセンス表示は十分」とは判断できない。フォントのライセンス本文は同梱・登録済みだが、アプリ内の閲覧導線がなく、一部依存の追加ライセンスも自動収集から漏れる。公開配布に向けて、以下の優先事項を対応する必要がある。

本調査はソース、ローカル依存キャッシュ、既存ビルド成果物、公式資料の照合によるもの。実装変更、公開環境の操作、契約内容の確認は行っていない。

## 1. 優先: ライセンス一覧への導線

- `lib/pages/settings_page.dart:631` の「アプリについて」は、同ファイルの `_showAboutDialog`（1819行）を開く。
- 実体は独自の `AlertDialog` で、アプリ説明・バージョン・Privacy Policy・GitHubなどを表示する。`showLicensePage` / `LicensePage` / 標準の `showAboutDialog` は利用しておらず、ライセンス一覧への操作がない。
- `build/web/assets/NOTICES` とAndroidの `NOTICES.Z` は存在する。ただし、ファイルの同梱だけではアプリ利用者が本文を閲覧できる状態になっていない。

対応案: 設定またはAbout内に「オープンソースライセンス」を設け、Flutter標準の `showLicensePage` を開く。WebとAPKで、本文を実際に読めることを確認する。

根拠: [Flutter LicenseRegistry](https://api.flutter.dev/flutter/foundation/LicenseRegistry-class.html)、[Flutter FAQ](https://docs.flutter.dev/resources/faq)。Flutterの収集機構と閲覧UIは別の役割である。

## 2. 優先: image / archive の追加ライセンス

`pubspec.lock` で解決された `image 4.12.0` と `archive 4.5.2` を、ローカルPubキャッシュで確認した。

| パッケージ | 主ライセンス以外の文書 | 含まれる第三者コードの例 |
| --- | --- | --- |
| image | `LICENSE-other.md` | JPEG / jpgjs、WebP / libwebp、TIFF / Apache Batik、OpenEXR、PVRTCなど |
| archive | `LICENSE-other.md` | imayaのzlib、JCraftのJZLib、bzip2、Bouncy Castleなど |

- 両パッケージのルート `LICENSE` はMIT。追加文書には別の著作権表示・ライセンス条件があるため、MIT本文だけで全部をカバーしたとは判断できない。
- 使用中のFlutter SDKの `packages/flutter_tools/lib/src/license_collector.dart:51` は、各パッケージの `NOTICES`、なければ `LICENSE` を読む。`LICENSE-other.md` はこの経路では収集しない。
- 両パッケージにルート `NOTICES` はなく、パッケージのpubspecと本プロジェクトにも追加文書をライセンス収集に渡す設定は見つからなかった。
- 既存のWeb `NOTICES` では `notmasteryet`、`imaya`、`JCraft`、`Julian R Seward`、`Apache Batik` の文字列が見つからなかった。

対応案: 解決済みバージョンに対応する追加文書を、著作権表示・条件を保持してアプリへ同梱し、`LicenseRegistry` などを通して閲覧可能にする。依存更新時には追加文書も再照合する。実際の配布範囲に含まれる第三者コードの精査が済むまでは、文書全体を保持する方針が取りこぼしを減らせる。

参考: [image 4.12.0](https://pub.dev/packages/image/versions/4.12.0)、[archive 4.5.2](https://pub.dev/packages/archive/versions/4.5.2)、[Apache License 2.0 第4条](https://www.apache.org/licenses/LICENSE-2.0)。Apache対象物では本文や、該当するNOTICEの保持も確認する必要がある。

## 3. 優先: OpenWeatherの帰属表示

- `functions/index.js:17` はOpenWeatherのCurrent Weather APIを利用する。
- `lib/pages/car_setting_page_normal_editor.dart:495` 付近の天気カードと `lib/pages/quick_run_log_page.dart:766` 付近の天気表示に、提供元の文言・リンク・ロゴはない。
- 同意説明とPrivacy PolicyにはOpenWeatherへの送信説明があるが、天気データの提供元表示とは役割が異なる。
- [OpenWeather公式FAQのLicense節](https://openweathermap.org/faq)では、Free〜Professionalのプランで帰属表示を必須とし、必要な場合は見える場所に「Weather data provided by OpenWeather」、公式サイトへのリンク、OpenWeatherロゴを置くよう案内している。

対応案: 利用中の契約プランと適用ライセンスを確認し、対象なら天気表示付近に公式指定の帰属表示を追加する。契約プラン・個別免除の有無はリポジトリから確認できないため、現時点では条件付きの指摘とする。

## 4. 確認済み: フォント3種類

- `pubspec.yaml:51` 以降でフォント本体とOFL本文を同梱している。
- `lib/main.dart:11` で登録処理を呼び、`LicenseRegistry` に以下を登録している。
  - Noto Sans JP: `assets/fonts/OFL.txt`
  - Inter: `assets/google_fonts/Inter-OFL.txt`
  - Space Grotesk: `assets/google_fonts/SpaceGrotesk-OFL.txt`
- 各文書には著作権表示とSIL Open Font License本文がある。

この範囲は既に整備されている。1の閲覧導線を追加した際に、3種類とも一覧・詳細に出ることを確認する。

根拠: [SIL Open Font License公式本文](https://openfontlicense.org/open-font-license-official-text/)、特に同梱時の著作権表示・本文保持を定める条件2。

## 5. 追加確認: native SDK、MPL、素材、自作コード

- **native SDK**: Firebase等のDartパッケージのライセンスだけで、Gradle / CocoaPodsが取得するSDK全体をカバーするとは限らない。配布対象の依存一覧と各SDKのLICENSE / NOTICEを突き合わせ、Android・iOSそれぞれの集約文書と閲覧方法を確認する必要がある。
  - 既存APKには `META-INF/NOTICE.md` やAndroidX annotationのLICENSEなど一部の文書があるが、全依存との照合は未完了。
  - `ios/Podfile.lock` にFirebase、gRPC、BoringSSL、ML Kit等がある。ただしロックファイルは本文を提供するものではなく、現行Dart依存との整合性も含め、次回iOSビルド時の再確認が必要。
  - Androidの依存グラフ取得はGradleのダウンロード時のネットワーク権限エラーで完了しなかった。
- **Linux向けMPL**: 解決済み依存の `dbus 0.7.15`、`geoclue 0.1.1`、`gsettings 0.2.8` はMPL-2.0。`geolocator_linux 0.2.4` の依存として確認した。Linux版で対象コードを配布する場合は、ライセンス表示に加えて対象ソースの入手方法等を確認する。依存一覧やNOTICESに名前があるだけで、Web・Androidにもそのコードが組み込まれているとは判断しない。MPLだからアプリ全体のソース公開が必要、という結論にもならない。[Mozilla公式FAQ](https://www.mozilla.org/en-US/MPL/2.0/FAQ/)
- **アイコン・データ**: `assets/launcher_icon/` の画像と `lib/data/track_locations.json` の出典・権利情報はリポジトリ内で確認できなかった。自作か、利用条件のある素材・データかを記録する。出典記録がないことだけで無断利用とは判断しない。
- **メーカーPDF**: ローカルの `setting_sheet_pdf/` にメーカー資料があるが、Git追跡対象ではなく、pubspecの同梱対象でもない。今回確認した構成ではアプリ同梱と判断していない。今後配布に含める場合は個別に権利確認する。
- **アプリ自体のLICENSE**: ルートに自作コードの利用許諾を示す `LICENSE` はない。第三者OSSの表示義務とは別の論点であり、MIT等を独断で追加しない。ソースの再利用を許諾する方針か、権利を留保する方針かを決めて明記する。

## 検証範囲と残件

- 現行ソース、`pubspec.yaml` / `pubspec.lock` / `.dart_tool/package_config.json`、Pubキャッシュのライセンス文書、Flutterの収集実装、既存成果物を読み取り確認した。
- `build/web/assets/NOTICES` は2026-10-18、ローカルdebug APKは2026-09-22の成果物で、2026-10-19更新の `pubspec.lock` より古い。これらの存在・検索結果を現行リリースの完全性の証明には使えない。
- 最新のrelease APK / Webの再ビルド、アプリ実機でのライセンス閲覧、native依存の全件照合、公開済み配布物の照合、サービスの契約確認は未実施。
- アプリコードは変更していない。調査文書のみのため、`flutter analyze` / `flutter test` は実行していない。

推奨する順序は、ライセンス画面の追加、追加文書の同梱、OpenWeatherの帰属対応、native依存の照合、最新配布物での閲覧・同梱確認である。
