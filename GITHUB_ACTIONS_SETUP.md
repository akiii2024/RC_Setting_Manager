# GitHub Actions セットアップガイド

このプロジェクトでは、GitHub Actionsを使用して自動的にAPKをビルドし、リリースします。

## 概要

このプロジェクトには2つのGitHub Actionsワークフローが含まれています：

1. **build-release.yml** - メインブランチへのプッシュとタグ作成時に本番用APKをビルド
2. **build-dev.yml** - プルリクエスト時に開発用APKをビルド

## セットアップ手順

### 1. GitHubシークレットの設定

リポジトリの設定で以下のシークレットを追加する必要があります：

1. GitHubリポジトリのページに移動
2. Settings → Secrets and variables → Actions を選択
3. "New repository secret" をクリック
4. 以下のシークレットを追加：

#### GOOGLE_SERVICES_JSON

Firebaseの設定ファイル（google-services.json）の内容をBase64エンコードして設定します。

```bash
# ローカルで実行（MacOS/Linux）
base64 -i android/app/google-services.json | pbcopy

# Windows PowerShellの場合
[Convert]::ToBase64String([IO.File]::ReadAllBytes("android/app/google-services.json")) | Set-Clipboard
```

コピーされた内容を `GOOGLE_SERVICES_JSON` という名前でシークレットに追加します。

### 2. リリースの作成方法

#### 自動リリース

タグを作成すると自動的にリリースが作成されます：

```bash
# バージョンタグを作成
git tag v1.0.0
git push origin v1.0.0
```

#### 手動ビルド

開発ビルドは以下の方法で手動実行できます：

1. GitHubリポジトリのActionsタブに移動
2. "Build Development APK" ワークフローを選択
3. "Run workflow" をクリック

## ワークフローの詳細

### build-release.yml

- **トリガー**: 
  - mainブランチへのプッシュ
  - `v*` パターンのタグ作成時
- **動作**:
  - リリース用APKをビルド
  - タグ作成時は自動的にGitHub Releaseを作成
  - APKファイルをリリースアセットとして添付

### build-dev.yml

- **トリガー**:
  - プルリクエストの作成/更新
  - 手動実行（workflow_dispatch）
- **動作**:
  - デバッグ用APKをビルド
  - アーティファクトとしてAPKを保存
  - プルリクエストにコメントを追加

## トラブルシューティング

### ビルドエラーが発生する場合

1. **Flutter バージョンの確認**
   - ワークフローファイルのFlutterバージョンがプロジェクトと一致しているか確認
   - 必要に応じて `.github/workflows/*.yml` のFlutterバージョンを更新

2. **google-services.json エラー**
   - シークレットが正しく設定されているか確認
   - Base64エンコードが正しく行われているか確認

3. **Java バージョンエラー**
   - Android Gradle Pluginのバージョンに応じてJavaバージョンを調整

### リリースが作成されない場合

- タグが `v` で始まっているか確認（例: v1.0.0）
- GitHub Actionsの実行ログを確認

## セキュリティに関する注意事項

- `google-services.json` ファイルは公開リポジトリにコミットしないでください
- シークレットは定期的に更新することを推奨します
- 開発用ビルドでは `google-services.json.example` を使用しています 