# arigato-nas-ops

自宅サーバー「arigato-nas」の運用自動化スクリプト集。

## マシン構成

- **arigato-nas**: Ubuntu 24.04, Intel N150, 16GB RAM
- 用途: AIチャットボット（OpenClaw）、メディア管理、各種自作アプリのホスティング
- Docker + systemd で運用、Cloudflare Tunnel で外部公開

## 収録コンテンツ

### [browser-relay](./browser-relay/)

OpenClawのブラウザリレー（Chrome拡張経由のWebページ操作）を、マシン再起動後も完全自動で復旧する仕組み。

Chrome起動 → ウィンドウ最大化 → **OpenCVテンプレートマッチングで拡張アイコンを画像認識** → xdotoolでクリック、という力技で実現。Discord Webhook通知付き。
# test
