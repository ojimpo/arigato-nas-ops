# backup: resticによるSSD→HDDバックアップとヘルスチェック

NVMe SSD上の重要データ（/home, /etc, /var/lib）を内蔵HDD上のresticリポジトリにバックアップする仕組み。

## 背景・動機

arigato-nasはNVMe 512GBをメインストレージとして使っているが、SSD単体では障害時にデータが飛ぶ。内蔵HDD（4TB）にresticでバックアップを取り、Discord通知で成功・失敗を把握できるようにした。

加えて、resticリポジトリ自体の整合性も週次でチェックし、「バックアップが壊れていて復元できない」事態を防ぐ。

## やったこと

- **日次バックアップ**: SSD上の `/home`, `/etc`, `/var/lib` をresticでHDDにバックアップし、古いスナップショットを自動でprune
- **ジョブランナー**: バックアップの実行をラップし、ログ記録・Discord通知（成功時はスナップショットID・サイズのサマリー付き）を行う
- **週次ヘルスチェック**: resticリポジトリの整合性チェック（`--read-data-subset=2.5%` でデータの一部を毎週読み出して検証）

## 仕組みの説明

```
cron (日次)
  └─ backup-job-runner.sh
       ├─ backup-ssd-to-hdd1.sh を実行（restic backup + forget --prune）
       ├─ ログを /var/log/backup-jobs/ に保存
       └─ Discord Webhook で結果通知（成功サマリー or 失敗エラー）

cron (週次)
  └─ restic-weekly-check.sh
       ├─ restic check --read-data-subset=2.5%
       └─ Discord Webhook で結果通知
```

### 保持ポリシー

- 日次: 14世代
- 週次: 8世代
- 月次: 12世代

## ファイル構成

| ファイル | 役割 |
|---|---|
| `backup-job-runner.sh` | バックアップ実行のラッパー。ログ保存・Discord通知・エラーハンドリング |
| `backup-ssd-to-hdd1.sh` | restic backup + forget --prune の実体。対象: /home, /etc, /var/lib |
| `restic-weekly-check.sh` | resticリポジトリの整合性チェック（週次）。Discord通知付き |

## セットアップ

### 前提

- restic がインストール済み（`~/.local/bin/restic`）
- resticリポジトリが初期化済み（`/mnt/media/.system-backups/arigato-nas/restic`）
- パスフレーズファイル: `~/.config/restic/arigato-nas-passphrase`
- 除外リスト: `~/.config/restic/arigato-nas-excludes.txt`

### Discord通知

```bash
# /etc/backup-discord-webhook.env
DISCORD_WEBHOOK_URL=https://discord.com/api/webhooks/...
```

## 注意点

- `backup-ssd-to-hdd1.sh` は `--one-file-system` 付きなので、マウントポイントを跨がない（HDD上のメディアファイル等は対象外）
- ジョブランナーはroot権限（sudo cron）で実行する想定
- ヘルスチェックは毎週データの2.5%を読み出すため、全データの検証には約40週かかる
