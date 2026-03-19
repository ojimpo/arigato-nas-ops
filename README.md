# arigato-nas-ops

自宅サーバー「arigato-nas」の運用自動化スクリプト集。

## マシン構成

- **arigato-nas**: Ubuntu 24.04, Intel N150, 16GB RAM
- 用途: AIチャットボット（OpenClaw）、メディア管理、各種自作アプリのホスティング
- Docker + systemd で運用、Cloudflare Tunnel で外部公開

## 収録コンテンツ

### [backup](./backup/)

resticによるSSD→HDDバックアップ。日次でバックアップ＋prune、週次でリポジトリ整合性チェック。Discord通知付き。

### [browser-relay](./browser-relay/)

OpenClawのブラウザリレー（Chrome拡張経由のWebページ操作）を、マシン再起動後も完全自動で復旧する仕組み。

Chrome起動 → ウィンドウ最大化 → **OpenCVテンプレートマッチングで拡張アイコンを画像認識** → xdotoolでクリック、という力技で実現。Discord Webhook通知付き。

### [cd-rip](./cd-rip/)

CDリッピング（whipper）完了時のDiscord通知。systemdタイマーで毎分ログを監視。

### [cron](./cron/)

ユーザーcrontabのスナップショット。MeTube振り分け、Ouraバッテリーアラート、各種同期ジョブ等の定期実行スケジュール。

### [gui](./gui/)

XRDPのオン・オフ制御。ヘッドレス運用で必要なときだけGUIを起動するためのワンライナー群。

### [immich](./immich/)

Google Takeout → Immich（セルフホスト写真管理）へのインポートスクリプト。`immich-go` CLIのラッパー。

### [metube](./metube/)

MeTubeでダウンロードした動画をファイル名の品番パターンから自動分類し、Stashのカテゴリ別ディレクトリに振り分け。Stash APIでスキャン発火、Discord通知付き。

### [openclaw](./openclaw/)

OpenClaw Gateway本体のsystemdサービス、メモリリーク対策の日次再起動タイマー、ブラウザリレー用Chrome起動、Claude Code tmuxセッション管理。

### [web](./web/)

ojimpo.com（個人サイト）のPython軽量サーバー。systemdユーザーサービスとして常駐、Cloudflare Tunnel経由で外部公開。
