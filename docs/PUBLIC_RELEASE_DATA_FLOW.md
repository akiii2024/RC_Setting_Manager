# 公開前整備のコード調査記録

確認日：2026-10-06。対象：今回のブランチの実装。サーバーの配布状態・Console設定や第三者サービスでの保持期間は、このコード調査だけでは確定できません。

## 公開版のモード

- `lib/app/app_bootstrap.dart` は `preferredOnline: false`、`onlineCapabilityEnabled: false` で起動。
- `lib/pages/login_page.dart` は `_isOfflineOnlyMode() => true`。`lib/pages/settings_page.dart` のオンライン機能表示も無効。
- `lib/providers/settings_provider.dart` のFirestore同期とテレメトリーStorage同期はオンライン状態でのみ起動。
- 天気・AI・OCRのFunctions利用はオンライン同期モードとは独立。`firebase_functions_service.dart` → `firebase_security_service.dart` が匿名認証とApp Checkを準備する。
- 天気サービスには任意座標を受け取るメソッドがあるが、現在の公開画面（`car_setting_page_environment.dart`、`quick_run_log_page.dart`）は現在位置で照会する。手動選択したコースの座標による天気取得は、提供中の機能として説明しない。

## 保存・通信の根拠

以下のパスは `lib/` からの相対パスです。

| 対象 | 端末内保存・処理 | 外部通信 | 主な根拠 |
| --- | --- | --- | --- |
| 車両、保存設定、走行記録、所有パーツ、表示・言語・エディタ設定 | SharedPreferencesの`settings_state_v2`。旧キーは移行読み込み用に残る | 通常の公開版では同期なし | `repositories/settings_local_repository.dart`、`models/settings_snapshot_v2.dart`、`providers/settings_provider.dart` |
| テーマ・チュートリアル・同意・AIプロバイダーとモデル | SharedPreferences | 値自体の自動送信は確認されない | `providers/theme_provider.dart`、`repositories/tutorial_preferences_repository.dart`、`services/api_consent_service.dart`、`services/ai_configuration_service.dart` |
| コース | 同梱JSON、カスタムコースはSharedPreferences `custom_tracks` | 最寄り候補の距離計算は端末内 | `services/track_location_service.dart`、`data/track_locations.json` |
| 位置・天気 | geolocatorの単発取得。照会座標・時刻・天気はSharedPreferences `weather_cache_current_v1` | `getCurrentWeather` → OpenWeatherへ座標送信 | `services/location_service.dart`、`services/weather_service.dart`、`functions/index.js` |
| 画像・OCR | image_pickerでカメラ／画像選択。処理中メモリ、採用値は設定として保存 | 標準Geminiは`extractSettingSheet`経由。OpenAI／Anthropicは直接API。画像、車種・項目カタログ等を送信 | `services/ocr_service.dart`、`pages/ocr_import_page.dart`、`services/ai_provider_client.dart` |
| AI相談 | 会話はサービスインスタンス内メモリ。採用して保存した提案は設定データ | 標準Geminiは`generateSettingAdvice`経由。OpenAI／Anthropicは直接API。車種・設定・関連走行メモ・コース・天気・入力メッセージ等 | `services/ai_advisor_service.dart`、`services/ai_advisor_context_builder.dart` |
| 個人APIキー | ネイティブはflutter_secure_storage、Webはstatic Mapでタブ内メモリ。通常バックアップ・設定同期から分離 | 使用するプロバイダーへの認証情報。Functionsへ個人キーを転送しない | `services/ai_configuration_service.dart`、`services/ai_provider_client.dart` |
| テレメトリー・任意動画・同期ジョブ | Hive `telemetry_sessions_v1`、`telemetry_videos_v1`、`telemetry_sync_jobs_v1`。CSV解析・コース推定は端末内 | 現在Storage同期は無効。実装上の同期は動画を除いた最大20 MiBのanalysis.stg | `services/telemetry_repository.dart`、`services/telemetry_analysis_service.dart`、`services/telemetry_sync_service.dart` |
| テレメトリーAI分析 | ローカル特徴量と間引いた代表波形を作成、結果をセッションへ保存 | `generateTelemetryAnalysis`または個人キーのAPI。元CSV・動画を送信しない | `services/telemetry_feature_service.dart`、`services/telemetry_ai_analysis_service.dart`、`pages/telemetry_analysis_page.dart` |
| XML／.stg／コースJSON | 選択ファイルの読み込み・書き出し。XMLはテレメトリー付属情報のみ。.stgは添付動画も含む | OS・ブラウザの共有先をユーザーが選ぶ場合、共有先へ渡る | `services/xml_service.dart`、`services/xml_data_codec.dart`、`services/file_service.dart`、`services/telemetry_file_service.dart`、`services/telemetry_session_codec.dart` |

## Firebaseの区別

- 現在の標準API経路：Firebase Core、Authenticationの匿名認証、App Check（WebはreCAPTCHA v3）、Callable Functions。
- Functions側のFirestore：`_function_rate_limits`にUIDに基づく識別子・利用数・期間・`expiresAt`を保存。TTLの有効化はConsole側の設定であり、コードから削除実行を保証できない。
- Functionsの運用ログ：処理時間、モデル、phase、エラー状態など。画像や会話を専用コレクションへ永続保存するコードは確認されない。サービス側のログ保持期間は未確認。
- 現在無効：Email/Password認証、ユーザー用Firestoreのデータ同期、Firebase Storageテレメトリー同期。実装・ルールは残している。
- GeminiのAI相談／構造化OCRは選択プロバイダーがGeminiならFunctions経由。テレメトリーAIはGeminiの個人キーが保存されている場合に直接APIを使う。現行設定UIはGemini個人キーの入力・削除を表示しないため、旧キーが残る場合の経路としてPrivacy Policyに記載。
- Firebase Analytics／Crashlyticsの依存・初期化は確認されない。google_fontsのフォントは同梱アセットも確認。

## 削除・互換性の注意

保存設定・走行記録には個別削除がある。テレメトリー画面の関連解除はHiveのセッション・動画を削除する。走行記録の削除だけではテレメトリー本体の削除を保証しない。APIキー削除は現行UIではOpenAI／Anthropicが対象。全SharedPreferences・旧キー・Hive・キャッシュを一括消去するアプリ内導線はないため、ブラウザのサイトデータ／OSのアプリデータ消去を案内する。資格情報ストアや書き出し済みファイル、送信済み情報は別途削除・失効が必要な場合がある。

データ形式、migration、ルール、API通信、デモモードの動作は変更しない。

## セキュリティ調査の範囲

- Git管理対象にはFirebaseのWeb設定識別情報があるが、AI秘密キー・サービスアカウント・署名鍵の混入は今回の調査では確認していない。Firebase Web API keyを秘密鍵流出とは扱わない。
- Firestore／Storageルールは所有者条件と既定拒否を確認した。エミュレータや本番権限を含む詳細監査は今回の範囲外。
- `utils/app_logger.dart` のログはdebugのみ。デバッグログには位置座標や認証情報の識別子が含まれる箇所があるため、公開Issueへ無加工で貼らない。
- GitHub APIではPagesがworkflow配布で既存の公開URLを持ち、Repository Variable `FIREBASE_APP_CHECK_WEB_KEY` が存在することを確認。今回のPRは本番Firebase設定を変更せず、外部APIの実通信検証も行わない。
- 過去の `PUBLICATION_AUDIT.md` は当時の検証結果。今回の変更に対する検証結果はPR本文に記録する。
- push時の通知を受けGitHub Dependabotのopenアラートを追加確認した。`functions/package-lock.json`のruntime依存に4件（high 1、medium 2、low 1）がある。対象は`@grpc/grpc-js`と`qs`。highの[アラート #9](https://github.com/akiii2024/RC_Setting_Manager/security/dependabot/9)は、特定のgRPCサーバー認証構成における`getAuthContext`の証明書判定が対象。このアプリのFunctionsコードには同APIによるサーバー認証処理は見つからないが、依存・配布環境を含めた悪用成立条件は未監査。依存更新と詳細評価は今回の説明整備の範囲外として残す。過去の「既知脆弱性0件」を現在の保証に使わない。

## 公開文書の正本

[Privacy Policy](../web/privacy.html)は静的HTMLとしてFlutter Webビルドへ含める。説明の重複による不一致を避けるため、別の全文Markdown版は作らない。READMEとAboutから公開URLへアクセスできる。LICENSEの追加・オンライン再有効化・デモの正式提供・セキュリティ詳細監査は今回の範囲外。
