# cron: cronジョブ一覧

arigato-nasのユーザーcrontabのスナップショット。何がどの頻度で動いているかの記録。

## 背景・動機

cronジョブは `crontab -e` で設定するが、設定内容がローカルにしか残らず、「今なにが動いているか」が把握しにくい。このリポジトリにスナップショットとして保存しておくことで、運用状況を俯瞰できるようにした。

## 登録ジョブ一覧

| スケジュール | ジョブ | 概要 |
|---|---|---|
| `*/5 * * * *` | `metube_dispatch.sh` | MeTubeダウンロード→Stash振り分け |
| `*/30 * * * *` | `metube_periodic_scan.sh` | Stash定期スキャン |
| `0 19 * * *` | `oura_battery_alert.py` | Ouraリングバッテリー残量アラート |
| `*/30 0-14,22-23 * * *` | `run_sync_katsushika.sh` | 葛飾区図書館貸出同期 |
| `*/30 * * * *` | `run_sync_filmarks_delta.sh` | Filmarks差分同期（flock排他制御） |
| `15,45 * * * *` | `run_sync_bookmeter_states.sh` | 読書メーター状態同期（flock排他制御） |

## ファイル構成

| ファイル | 役割 |
|---|---|
| `crontab.txt` | crontabのスナップショット |

## 注意点

- このファイルはあくまでスナップショットであり、`crontab -e` で直接編集した場合は手動で同期する必要がある
- systemd timerで管理しているジョブ（backup, cd-rip-notify等）はここには含まれない
