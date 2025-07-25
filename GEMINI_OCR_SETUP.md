# Gemini OCR機能セットアップガイド

## 概要

このプロジェクトではGoogle Gemini AIを使用したOCR（光学文字認識）機能を実装しています。
従来のML Kitテキスト認識に代わり、より高精度で日本語と英語の両方に対応した画像からの文字認識が可能です。

## 実装済み機能

### 1. Gemini Pro Visionによる高精度OCR
- **モデル**: `gemini-1.5-flash`
- **対応言語**: 日本語・英語
- **対応形式**: JPEG画像
- **プラットフォーム**: Web、Android、iOS、Windows、macOS、Linux

### 2. 改良されたテキスト抽出機能
- **パターンマッチング**: 3種類の異なるパターンでセッティング値を抽出
  - `ラベル: 値` 形式
  - `ラベル 値` 形式（スペース区切り）
  - 表形式データ（タブ区切り）
- **ラベル正規化**: 大文字小文字、スペースを無視した柔軟なマッチング
- **略語対応**: よく使われる略語（F Camber、R Camber等）にも対応
- **単位処理**: mm、°、#、T、g等の単位を自動除去

### 3. Web環境対応
- Webブラウザでも画像アップロードによるOCR機能が利用可能
- ただし、カメラ機能は環境により制限される場合があります

## セットアップ手順

### 1. Gemini APIキーの取得

1. [Google AI Studio](https://makersuite.google.com/app/apikey)にアクセス
2. Googleアカウントでログイン
3. 「Create API Key」をクリック
4. 新しいAPIキーを生成してコピー

### 2. 環境変数の設定

プロジェクトルートの`.env`ファイルを編集：

```env
# Gemini API
GEMINI_API_KEY=ここにあなたのAPIキーを入力
```

**重要**: `.env`ファイルはGitにコミットしないでください（.gitignoreに含まれています）

### 3. 依存関係の確認

以下のパッケージが自動的に追加されています：

```yaml
dependencies:
  google_generative_ai: ^0.2.2
  flutter_dotenv: ^5.1.0
  image_picker: ^1.0.7
```

## 使用方法

### OCRサービスの利用

```dart
// OCRサービスのインスタンス化
final OCRService _ocrService = OCRService();

// 画像からテキストを認識
final recognizedText = await _ocrService.recognizeTextFromImage(imageFile);

// セッティング値の抽出
final extractedSettings = _ocrService.extractSettingsFromText(
  recognizedText!,
  carDefinition.availableSettings,
);
```

### 対応する画像形式

- **カメラ撮影**: アプリ内カメラ機能
- **ギャラリー選択**: 端末の画像ライブラリから選択
- **対応形式**: JPEG、PNG
- **推奨解像度**: 最大1920x1920ピクセル（自動リサイズ）

## 機能改善点

### 従来のML Kit比較

| 項目 | ML Kit | Gemini AI |
|------|--------|-----------|
| 日本語認識精度 | △ | ◎ |
| 英語認識精度 | ○ | ◎ |
| 複雑なレイアウト | △ | ○ |
| Web対応 | × | ○ |
| 設定不要 | ○ | △ (APIキー必要) |
| オフライン動作 | ○ | × |

### 追加された抽出パターン

1. **改良されたラベルマッチング**
   - 大文字小文字を無視
   - スペースの有無を無視
   - 部分マッチング対応

2. **略語マッピング**
   ```
   F Camber → frontCamberAngle
   R Camber → rearCamberAngle
   F Height → frontGroundClearance
   R Height → rearGroundClearance
   ```

3. **表形式データ対応**
   - タブ区切りのデータ
   - 複数スペースで区切られたデータ

## トラブルシューティング

### よくある問題

1. **「GEMINI_API_KEY が環境変数に設定されていません」エラー**
   - `.env`ファイルにAPIキーが正しく設定されているか確認
   - ファイル名が`.env`（ドット付き）になっているか確認

2. **OCR精度が低い場合**
   - 画像の明度・コントラストを調整
   - 文字がはっきり見える角度で撮影
   - 影や反射を避ける

3. **Web環境でカメラが動作しない**
   - HTTPS環境で実行しているか確認
   - ブラウザの権限設定を確認
   - ギャラリーからの画像選択を利用

### デバッグ情報

OCRサービスは詳細なログを出力します：

```
Gemini OCR エラー: [エラー内容]
エラータイプ: [エラーの種類]
スタックトレース: [詳細情報]
```

## API使用量とコスト

- Gemini 1.5 Flashは効率的なモデルです
- 画像処理には少量のトークンを消費
- 詳細な料金は[Google AI Pricing](https://ai.google.dev/pricing)を確認

## セキュリティ注意事項

- APIキーは絶対に公開リポジトリにコミットしない
- 本番環境では環境変数やシークレット管理サービスを使用
- 送信される画像データはGoogle AIサービスで処理されることを理解する

## サポート対象プラットフォーム

- ✅ Android
- ✅ iOS  
- ✅ Web
- ✅ Windows
- ✅ macOS
- ✅ Linux

すべてのプラットフォームで統一されたOCR機能が利用可能です。 