# RC Setting Manager

ラジコンのセッティングをスマホアプリで記録することを目的としたものです。

## 機能

- RCカーのセッティング情報の記録・管理
- 複数の車種に対応
- ダークモード対応
- 日本語・英語対応
- **Firebase認証とクラウド同期機能**
- デバイス間でのデータ同期

## Firebase セットアップ

このアプリはFirebaseを使用してユーザー認証とデータの同期を行います。以下の手順でFirebaseプロジェクトを設定してください。

### 1. Firebaseプロジェクトの作成

1. [Firebase Console](https://console.firebase.google.com/)にアクセス
2. 「プロジェクトを追加」をクリック
3. プロジェクト名を入力（例：rc-setting-manager）
4. Google Analyticsの設定（オプション）
5. プロジェクトを作成

### 2. 認証の設定

1. Firebase Consoleで「Authentication」を選択
2. 「始める」をクリック
3. 「Sign-in method」タブで「メール/パスワード」を有効にする

### 3. Firestoreの設定

1. Firebase Consoleで「Firestore Database」を選択
2. 「データベースの作成」をクリック
3. セキュリティルールで「テストモードで開始」を選択（後で本番用ルールに変更）
4. ロケーションを選択（asia-northeast1推奨）

### 4. Android設定

1. Firebase Consoleでプロジェクトの設定を開く
2. 「アプリを追加」→「Android」を選択
3. パッケージ名：`com.example.settingsheet_manager`
4. `google-services.json`をダウンロード
5. `android/app/google-services.json`に配置

### 5. iOS設定

1. Firebase Consoleでプロジェクトの設定を開く
2. 「アプリを追加」→「iOS」を選択
3. バンドルID：`com.example.settingssheetManager`
4. `GoogleService-Info.plist`をダウンロード
5. `ios/Runner/GoogleService-Info.plist`に配置

### 6. セキュリティルール（本番環境用）

Firestoreのセキュリティルールを以下のように設定してください：

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // ユーザーは自分のデータのみアクセス可能
    match /users/{userId}/{document=**} {
      allow read, write: if request.auth != null && request.auth.uid == userId;
    }
  }
}
```

## インストール

1. リポジトリをクローン
```bash
git clone <repository-url>
cd settingsheet_manager
```

2. 依存関係をインストール
```bash
flutter pub get
```

3. Firebase設定ファイルを配置
   - `android/app/google-services.json`
   - `ios/Runner/GoogleService-Info.plist`

4. アプリを実行
```bash
flutter run
```

## 使用方法

### オフラインモード
- アプリをインストール後、すぐにローカルでセッティングデータを管理できます
- データはデバイスのローカルストレージに保存されます

### オンラインモード
1. 設定画面で「サインイン / サインアップ」を選択
2. メールアドレスとパスワードでアカウントを作成またはサインイン
3. 「オンライン同期」をオンにする
4. データが自動的にクラウドに同期されます

### データ同期
- オンラインモードでは、設定の変更が自動的にFirestoreに保存されます
- 「今すぐ同期」で手動同期も可能
- 「クラウドから読み込み」で他のデバイスのデータを取得

## GitHub Actions

このプロジェクトはGitHub Actionsを使用して自動ビルド・リリースを行います。詳細は[GITHUB_ACTIONS_SETUP.md](GITHUB_ACTIONS_SETUP.md)を参照してください。

### 主な機能
- コミット時の自動APKビルド
- タグ作成時の自動リリース作成
- プルリクエスト時の開発ビルド

## 注意事項

- Firebase設定ファイルが正しく配置されていない場合、アプリがクラッシュする可能性があります
- 初回起動時はオフラインモードで動作し、ログイン後にオンライン機能が利用可能になります
- セキュリティルールは本番環境では必ず適切に設定してください
