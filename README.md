# RC Setting Manager

競技RCツーリングカーを使う方向けの、セットアップ・走行記録・テレメトリーを管理する個人開発アプリです。車種ごとの設定値、走行時の環境や感触、ラップタイムを記録して振り返れます。

**[Web版を試す](https://akiii2024.github.io/RC_Setting_Manager/)** · [Privacy Policy](https://akiii2024.github.io/RC_Setting_Manager/privacy.html) · [不具合報告・問い合わせ](https://github.com/akiii2024/RC_Setting_Manager/issues)

現在は開発初期の公開版です。バージョンの正本は [pubspec.yaml](pubspec.yaml) です。基本データは利用中の端末・ブラウザに保存され、アカウントへのログイン、クラウド同期、デバイス間同期は現在無効です。天気・AI・OCRは、同意して利用した場合に外部サービスへ通信します。

## 現在できること

- 車種別のセッティング編集・保存・履歴比較（アプリUI／紙UI）、編集中の下書きの自動保存・復元
- 走行日時、コース、ラップタイム、環境、感触、変更点、メモの記録と統計
- マイガレージの車両・所有パーツ管理
- テレメトリーCSV／`.stg`の読み込み、グラフ、ラップ・コース推定、任意動画との同期表示
- XMLでのバックアップ・復元、部分エクスポート、テレメトリーの`.stg`エクスポート
- 位置情報を使う最寄りコース候補の検索、天気の取得（任意・同意が必要）
- セッティングのAI相談、画像からの設定値読み取り（OCR）、テレメトリーのAI走行分析（任意・同意が必要）
- ギヤレシオなどの計算ツール、ライト／ダークテーマ、日本語／英語表示

AIの提案やOCRの読み取り結果、テレメトリーからの推定は確認用の情報です。採用前に内容を確認してください。編集内容の下書きは端末内に自動保存され、再編集時に復元・破棄を選べます。保存済みセッティングへ確定するには保存操作が必要です。XMLバックアップには編集中の下書きは含まれません。

## 現在標準対応している車種

[標準車種カタログ](lib/data/built_in_car_catalog.dart)と車種別セッティング定義に、次の8車種があります。

| メーカー | 車種 |
| --- | --- |
| TAMIYA | TRF420、TRF420X、TRF421、TRF421X |
| YOKOMO | BD11、BD12、MS1.0、MS2.0 |

## 利用方法とデータの保存

1. [Web版](https://akiii2024.github.io/RC_Setting_Manager/)を開き、車種・車両を選びます。
2. セッティングを入力して保存し、走行後に走行記録を残します。
3. 履歴・統計やテレメトリー分析で比較します。AI・OCR・天気は必要なときだけ利用できます。

ブラウザが対応している場合は、メニューの「インストール」または「ホーム画面に追加」でPWAとして利用できます。基本の記録・編集はオフラインで動作する構成ですが、初回読み込み・更新・外部APIの利用にはネット接続が必要です。オフラインでの再起動可否はブラウザのキャッシュ状態に依存します。

端末内データはブラウザ・プロファイル・サイトごとに別々です。ブラウザのサイトデータ消去や端末故障に備え、XML／`.stg`でバックアップしてください。XMLにはテレメトリーの付属情報が含まれますが、波形本体や動画はXMLに含まれないため、別途`.stg`を保存してください。テレメトリーに添付した動画も`.stg`に含まれます。

個別の記録は各画面の削除操作で削除できます。端末内の全データを削除するには、ブラウザの当該サイトのデータを消去してください。PWAのアイコン削除だけではデータが残る場合があります。詳しい情報の種類・外部送信・削除方法は [Privacy Policy](web/privacy.html)を参照してください。

Android／iOS向けのソースも含まれますが、ストア配布の完了を示すものではありません。公開されている配布物は [Releases](https://github.com/akiii2024/RC_Setting_Manager/releases)で確認してください。

## AI・OCR・天気の通信

「設定 → AIプロバイダー・APIキー」でプロバイダーを選びます。

| 機能・選択 | 通信先と送信内容 |
| --- | --- |
| 標準GeminiのAI相談・OCR | Firebase Functions経由でGoogle Geminiへ、設定値、車種、関連する走行・コース・天気情報、入力メッセージ、OCR画像などを送信 |
| 個人設定のOpenAI／Anthropic | 入力したAPIキーで各社のAPIへ直接、AI相談の情報またはOCR画像・設定コンテキストを送信 |
| テレメトリーAI分析 | 選択中のAIへローカル解析した特徴量・代表波形を送信。標準GeminiはFirebase Functions経由。元CSV・動画はAIへ送信しません |
| 天気 | 取得した現在位置の緯度経度をFirebase Functions経由でOpenWeatherへ送信 |

標準Gemini・天気は、クラウド同期が無効でもFirebaseの匿名認証とApp Check（WebではreCAPTCHA v3）を使います。外部サービスの稼働状況、利用上限、サーバー設定により取得できない場合があります。各機能のデータ送信への同意は設定画面で変更できます。

個人APIキーはネイティブ版ではOSの保護されたストレージ、Web版ではタブ内メモリだけに保持します。Webでは再読み込み後に再入力が必要です。APIキーはXML／`.stg`バックアップや設定同期には含めません。入力したキーは通信時に選択先APIへ認証情報として送られます。Webで利用中のキーはブラウザ上のコードから利用できるため、利用制限を設定した専用キーを使用してください。個人キーを使うAPIの料金は各プロバイダーの条件によります。

## 開発・Webビルド

GitHub ActionsはFlutter **3.35.3**でテストとWebビルドを実行します。PRではビルドのみ、`main`へのpush時にGitHub Pagesへ配布します。

```bash
flutter pub get
flutter analyze
flutter test
node tool/firebase_csp.mjs --check
flutter build web --base-href /RC_Setting_Manager/ --dart-define=FIREBASE_APP_CHECK_WEB_KEY=YOUR_SITE_KEY --release
node tool/check_public_web.mjs build/web
```

App CheckのSite Keyは公開識別情報です。PRのビルド検証にはActionsと同じ`pull-request-build-only`を使用できますが、その値では実際の保護されたAPIを利用できません。Privacy Policyは`web/privacy.html`を正本とし、Webビルドに同梱されます。Aboutのバージョン表示は同梱した`pubspec.yaml`から取得します。

標準Gemini・OpenWeatherのサーバーAPIキーはFlutterに埋め込まず、Firebase FunctionsのSecret Managerに設定します。Functionsの既定リージョンは`asia-northeast1`です。詳しい設定は [公開用設定手順](docs/PUBLISHING_SETUP_GUIDE.md)、コードから確認したデータフローは [公開前調査記録](docs/PUBLIC_RELEASE_DATA_FLOW.md)を参照してください。

## 問い合わせ

[GitHub Issues](https://github.com/akiii2024/RC_Setting_Manager/issues)へ不具合・質問・プライバシーに関する問い合わせを投稿してください。Issuesは公開されるため、APIキー、個人情報、非公開の画像や走行データを記載しないでください。

現時点でアプリ本体のLICENSEファイルはありません。利用・改変・再配布に関するライセンス方針は作者が別途決定します。同梱フォントにはそれぞれのライセンスがあります。
