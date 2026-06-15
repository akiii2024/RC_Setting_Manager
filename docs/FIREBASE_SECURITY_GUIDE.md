# Firebase セキュリティ設定ガイド

> 現在、Gemini API key と OpenWeather API key は Firebase Functions の Secret Manager で管理します。Flutter の `--dart-define` や GitHub Actions secrets でアプリへ埋め込まないでください。

## 🔒 現在のセキュリティ状況

### ⚠️ 注意事項
- Gemini API key と OpenWeather API key は Firebase Functions secrets で管理します
- Firebase クライアント SDK の API key はアプリ設定として残ります
- Firebase クライアント API key は Google Cloud / Firebase Console で利用制限を設定してください

## 🛡️ セキュリティ強化手順

### 1. GitHub Secretsの設定

GitHubリポジトリの「Settings」→「Secrets and variables」→「Actions」で以下を設定：

```
FIREBASE_WEB_API_KEY=AIzaSyDKIP88kAdkXBcWde69ofYkH3DGOQouwIE
FIREBASE_PROJECT_ID=rc-setting-manager
FIREBASE_MESSAGING_SENDER_ID=375147888843
OPENWEATHER_API_KEY=your_openweather_api_key
```

### 2. Firebase Consoleでの設定

#### A. Authentication設定
1. Firebase Console → Authentication → Sign-in method
2. 「メール/パスワード」を有効化
3. 「承認済みドメイン」に以下を追加：
   - `localhost`
   - `your-username.github.io`
   - カスタムドメインがある場合は追加

#### B. Firestoreセキュリティルール
```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // ユーザーは自分のデータのみアクセス可能
    match /users/{userId}/{document=**} {
      allow read, write: if request.auth != null && request.auth.uid == userId;
    }
    
    // 公開データ（読み取り専用）
    match /public/{document=**} {
      allow read: if true;
      allow write: if false;
    }
  }
}
```

#### C. Storageセキュリティルール（必要に応じて）
```javascript
rules_version = '2';
service firebase.storage {
  match /b/{bucket}/o {
    match /users/{userId}/{allPaths=**} {
      allow read, write: if request.auth != null && request.auth.uid == userId;
    }
  }
}
```

### 3. APIキーの制限設定

#### A. Google Cloud Consoleでの設定
1. [Google Cloud Console](https://console.cloud.google.com/)にアクセス
2. プロジェクト「rc-setting-manager」を選択
3. 「APIとサービス」→「認証情報」
4. 各APIキーをクリックして制限を設定：

**Web APIキー制限例：**
- アプリケーションの制限：HTTPリファラー
- 許可されたリファラー：
  - `localhost:8080/*`
  - `your-username.github.io/*`
  - `your-custom-domain.com/*`

**Android APIキー制限例：**
- アプリケーションの制限：Androidアプリ
- パッケージ名：`com.example.settingsheet_manager`
- SHA-1証明書フィンガープリント：開発用とリリース用を追加

**iOS APIキー制限例：**
- アプリケーションの制限：iOSアプリ
- バンドルID：`com.example.settingsheetManager`

### 4. 環境変数を使用した実装

#### A. pubspec.yamlに依存関係を追加
```yaml
dependencies:
  flutter_dotenv: ^5.1.0
```

#### B. 環境変数から読み込む実装例
```dart
import 'package:flutter_dotenv/flutter_dotenv.dart';

class FirebaseConfig {
  static String get webApiKey => dotenv.env['FIREBASE_WEB_API_KEY'] ?? '';
  static String get projectId => dotenv.env['FIREBASE_PROJECT_ID'] ?? '';
  static String get messagingSenderId => dotenv.env['FIREBASE_MESSAGING_SENDER_ID'] ?? '';
}
```

### 5. 本番環境での推奨事項

1. **APIキーのローテーション**: 定期的にAPIキーを更新
2. **監視の設定**: Firebase Consoleで異常なアクセスを監視
3. **バックアップ**: 重要なデータのバックアップを設定
4. **ログ監視**: Cloud Loggingでアクセスログを監視

## 🚨 緊急時の対応

### APIキーが漏洩した場合
1. 即座にGoogle Cloud ConsoleでAPIキーを無効化
2. 新しいAPIキーを生成
3. GitHub Secretsを更新
4. アプリを再デプロイ

### 不正アクセスが発生した場合
1. Firebase Consoleでアクセスログを確認
2. 影響を受けたデータを特定
3. 必要に応じてデータを復元
4. セキュリティルールを見直し

## 📞 サポート

セキュリティに関する質問や問題が発生した場合は、以下に連絡してください：
- Firebase Support: https://firebase.google.com/support
- Google Cloud Support: https://cloud.google.com/support 
