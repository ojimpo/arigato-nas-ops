# openclaw: OpenClaw Gateway運用とClaude Code環境

OpenClaw Gatewayのsystemdサービス定義、メモリリーク対策の日次再起動、ブラウザリレー用のChrome起動、Claude Codeのtmuxセッション管理をまとめたもの。

## 背景・動機

OpenClawはarigato-nas上で常駐稼働するAIチャットボット基盤で、このサーバーの中核サービス。長時間稼働するとメモリリークでOOMに陥る問題があったため、cgroup制限と日次再起動で対処。また、ブラウザリレーを使うWeb操作タスク用のワークフローと、Claude Codeのセッション管理も整備した。

## やったこと

- **Gateway サービス**: systemdユーザーサービスとして常駐起動。cgroup経由で `MemoryMax=3G` / `MemoryHigh=2G` を設定し、OOM時は `KillMode=control-group` で確実に子プロセスごと停止
- **日次再起動タイマー**: 毎日 19:00 UTC（JST 04:00）に自動再起動してメモリを解放
- **ブラウザリレー用Chrome**: 専用プロファイルでChromeを起動するラッパー（通常のブラウジングと競合しない）
- **Webタスク制御**: RDP起動→Chrome起動→リレーONの手順をガイドする `webtask-on` / `webtask-off`
- **Claude Code セッション**: tmuxセッションでClaude Codeを管理（通常モード / Remote Controlモード対応）

## 仕組みの説明

```
systemd (user)
  ├─ openclaw-gateway.service        … Gateway常駐（MemoryMax=3G）
  ├─ openclaw-gateway-restart.timer  … 毎日19:00 UTCに発火
  └─ openclaw-gateway-restart.service … Gatewayをrestart

Webタスクのワークフロー:
  webtask-on → gui-on → XRDP起動 → 手順表示
    └─ relay-chrome → 専用プロファイルでChrome起動 → リレーON
  webtask-off → gui-off → XRDP停止

Claude Code:
  claude-session [start|remote|attach|list|kill]
    └─ tmux セッション "claude" を管理
    └─ remote モード: --dangerously-skip-permissions で起動
```

## ファイル構成

| ファイル | 役割 |
|---|---|
| `openclaw-gateway.service` | Gateway本体のsystemdサービス定義（cgroup制限付き） |
| `openclaw-gateway-restart.service` | Gatewayを再起動するoneshotサービス |
| `openclaw-gateway-restart.timer` | 日次再起動タイマー（19:00 UTC = JST 04:00） |
| `relay-chrome` | ブラウザリレー専用プロファイルでChromeを起動するラッパー |
| `webtask-on` | XRDP起動 + Webタスク開始手順を表示 |
| `webtask-off` | Webタスク終了 + XRDP停止 |
| `claude-session` | Claude Code用tmuxセッション管理（start/remote/attach/list/kill） |

## 注意点

- Gateway のNode.jsバイナリパスは `~/.local/bin/node` にハードコードされている
- `relay-chrome` は `~/.config/google-chrome-openclaw-relay` に専用プロファイルを作る。通常のChromeプロファイルとは別管理
- `claude-session remote` は `--dangerously-skip-permissions` フラグ付きで起動するため、信頼できるネットワーク内でのみ使用すること
