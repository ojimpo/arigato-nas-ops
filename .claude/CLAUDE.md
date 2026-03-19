# arigato-nas-ops

## 重要: このリポジトリはpublicで自動sync

このリポジトリは **GitHub public リポジトリ** であり、ファイルの変更は `ops-auto-sync` サービスにより **即座に自動commit・pushされる**。

### 秘密情報の取り扱い

- APIトークン、パスワード、Webhook URL 等の秘密情報を **絶対にファイルに直接書かないこと**
- 秘密情報は `EnvironmentFile` や `.env` ファイルで外部から注入する
- `.env` ファイルは `.gitignore` で除外済み
- `env.example` にキー名だけ記載し、値は入れない

### ファイル構成

- `~/bin/` のスクリプトはこのリポジトリへのシンボリックリンク
- systemdサービス定義のうち、秘密情報を含むもの（`openclaw-browser-autostart.service` 等）は `~/.config/systemd/user/` に実体があり、このリポジトリにはサニタイズ版を置いている
