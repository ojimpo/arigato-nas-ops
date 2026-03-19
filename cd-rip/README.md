# cd-rip: CDリッピング完了通知

CDリッピング（whipper）のログを監視し、完了をDiscord Webhookで通知するsystemdタイマー。

## 背景・動機

arigato-nasに接続したCDドライブでwhipperを使ってCDをリッピングしているが、リッピングは数分〜十数分かかる。完了したかどうかをいちいちターミナルで確認するのが面倒なので、Discord通知で「終わったよ」を受け取れるようにした。

## やったこと

- systemdタイマーで毎分ログファイルをチェックし、新しいリッピング完了を検知したらDiscord Webhookで通知する

## 仕組みの説明

```
systemd (user)
  ├─ cd-rip-notify.timer    … 毎分発火
  └─ cd-rip-notify.service  … Python通知スクリプトを実行
       └─ notify_from_logs.py（clawd/skills/cd-rip-whipper/scripts/ にある）
```

通知スクリプト本体はこのリポジトリではなく `clawd` 側に配置されている。ここにはsystemdユニットファイルのみ収録。

## ファイル構成

| ファイル | 役割 |
|---|---|
| `cd-rip-notify.service` | 通知スクリプトを実行するoneshotサービス |
| `cd-rip-notify.timer` | 毎分発火するタイマー |

## セットアップ

### 環境変数ファイル

```bash
# ~/.config/cd-rip-notify.env
DISCORD_WEBHOOK_URL=https://discord.com/api/webhooks/...
```

## 注意点

- 通知スクリプト本体（`notify_from_logs.py`）は `~/clawd/skills/cd-rip-whipper/scripts/` に配置されている
- タイマーは `Persistent=false` なので、サービスが停止中に溜まった分はまとめて通知されない
