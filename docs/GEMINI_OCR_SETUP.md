# 構造化OCRセットアップガイド

## 概要

OCRはセッティングシート画像を全文テキストへ変換せず、選択中の車種定義を使って設定候補を1回で構造化抽出します。TRF421、TRF420、TRF420Xには専用レイアウトプロファイルがあり、文字や数値に加えて、X印、黒丸、選択枠、グリッド位置を読み取ります。その他の車種には汎用プロファイルを使用します。

標準GeminiではFirebase callable Function `extractSettingSheet`を使用します。ユーザーが個人設定したOpenAI、Anthropic、Geminiでは、各プロバイダーの構造化生成APIへアプリから直接画像を送ります。

## Firebase Functionsの設定

Gemini APIキーはFlutterアプリへ埋め込まず、Firebase FunctionsのSecret Managerへ保存します。

```bash
firebase functions:secrets:set GEMINI_API_KEY
firebase deploy --only functions
```

`extractSettingSheet`にはAuthentication、App Check、既存のGeminiレート制限が適用されます。リージョンは既定で`asia-northeast1`です。変更する場合はFlutterビルド時に`--dart-define=FIREBASE_FUNCTIONS_REGION=your-region`を指定してください。

## OCRServiceの利用

```dart
final result = await OCRService().extractSettingsFromImage(
  imageFile,
  carId: car.id,
  carName: car.name,
  settingDefinitions: carDefinition.availableSettings,
);

final imported = result.selectedSettings(selectedKeys);
```

`OcrExtractionResult`には検出車種、検証済み／選択不可の候補、警告、車種不一致状態が含まれます。高・中確信度の有効候補は初期選択され、低確信度候補は確認画面に未選択で表示されます。

## 画像条件

- 形式: JPEG、PNG、WebP
- 上限: 1枚8 MiB
- 画像選択時の最大辺: 4096px
- JPEG品質: 90

画像のMIMEタイプは拡張子ではなくバイトシグネチャで判定します。影、反射、強い傾き、極端なトリミングは認識精度を下げるため避けてください。

## 安全性と検証

- 画像内の文章はすべて信頼しないデータとして扱い、命令として実行しません。
- 空欄や未選択の印刷済み選択肢を既定値で補いません。
- 応答キーを選択中車種のカタログへ限定し、数値範囲、step、選択肢、文字長、グリッド範囲を端末側でも再検証します。
- 明確な車種不一致では取り込みを停止します。車種を検出できない場合は警告付きで候補確認を続けます。
- JSON不正や空応答などのプロトコル異常だけ1回再試行します。低確信度は再試行理由にしません。

## トラブルシューティング

1. `GEMINI_API_KEY`未設定エラー
   - `firebase functions:secrets:set GEMINI_API_KEY`を実行し、Functionsを再デプロイします。
2. 標準Geminiで呼び出せない
   - Firebase Authenticationへのログイン状態とApp Check設定を確認します。
3. 候補が少ない
   - 画像の向き、ピント、照明を確認し、シート全体が4096px以内で読める画像を選び直します。
4. 候補が選択不可
   - 確認画面の理由を確認します。範囲外、未知キー、競合値、グリッド範囲外は自動取り込みされません。

原画像や氏名・サーキット名をテストfixtureへ保存しないでください。回帰テストには匿名化した構造化応答とモック画像だけを使用します。
