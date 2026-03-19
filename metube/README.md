# metube: MeTubeダウンロード→Stash自動振り分けパイプライン

MeTubeでダウンロードした動画を、ファイル名から品番を解析してStashのカテゴリ別ディレクトリに自動振り分けする。

## 背景・動機

MeTubeでダウンロードした動画ファイルはすべて1つのフォルダに溜まる。それをStash（メディア管理ツール）に取り込むには、品番ベースでディレクトリ分類してからスキャンする必要がある。手動でやると地味に面倒なので、ファイル名のパターンマッチで自動振り分け→Stash APIでスキャン発火まで全自動にした。

## やったこと

- **品番解析エンジン**: ファイル名からFC2-PPV、JAV品番（ABC-123形式）、無修正系（1Pondo/Caribbeancom/Heyzo等）を正規表現で判別
- **自動振り分け**: 解析結果に基づいて `FC2/`, `JAV/`, `Uncensored/`, `Unsorted/` に自動移動
- **Stash API連動**: 振り分け後、移動先パスを指定してStashのメタデータスキャンをGraphQL APIで発火（30分クールダウン付き）
- **Discord通知**: 振り分け結果をDiscord Webhookで通知（ファイル名はスポイラータグで隠蔽）
- **定期スキャン**: dispatch とは別に、30分ごとにStashの定期スキャンも実行

## 仕組みの説明

```
cron (5分ごと)
  └─ metube_dispatch.sh
       ├─ /mnt/media/downloads/metube/stash/ の動画ファイルを検出
       ├─ ファイル名から品番を解析 → リネーム
       ├─ カテゴリ判定 → /mnt/media/stash/{FC2,JAV,Uncensored,Unsorted}/ に移動
       ├─ Stash GraphQL API で metadataScan を発火
       └─ Discord Webhook で結果通知

cron (30分ごと)
  └─ metube_periodic_scan.sh
       └─ Stash GraphQL API で定期スキャンを発火

手動実行
  └─ metube_add_stash.sh <URL>
       └─ MeTube API に stash フォルダ指定でダウンロード追加
```

### 品番解析ルール

| パターン | 分類先 | 例 |
|---|---|---|
| `FC2-PPV-*` / `fc2 ppv *` | `FC2/` | FC2-PPV-4825382 |
| `1Pondo-` / `Caribbeancom-` / `Heyzo-` 等 | `Uncensored/` | 1Pondo-010124_001 |
| `ABC-123` 形式 | `JAV/` | SOE-396 |
| 上記以外 | `Unsorted/` | — |

## ファイル構成

| ファイル | 役割 |
|---|---|
| `metube_dispatch.sh` | メイン振り分けスクリプト。品番解析・ファイル移動・Stashスキャン・Discord通知 |
| `metube_add_stash.sh` | MeTube APIにダウンロードリクエストを投げるCLIツール |
| `metube_periodic_scan.sh` | Stashの定期スキャンのみ実行（振り分けなし） |

## セットアップ

### 環境変数ファイル

```bash
# ~/.config/discord-metube-dispatch.env
DISCORD_WEBHOOK_URL=https://discord.com/api/webhooks/...

# ~/.config/stash.env
STASH_URL=http://localhost:9999/graphql
STASH_APIKEY=your-stash-api-key
STASH_SCAN_PATH=/data/videos
```

## 注意点

- `.part`, `.tmp`, `.crdownload` などダウンロード中のファイルはスキップされる
- Stashスキャンには30分のクールダウンがあり、連続実行を抑制する
- Discord通知のファイル名はスポイラータグ `||名前||` で囲まれる
- Stashコンテナ内のパス（`/data/videos/...`）とホスト側のパス（`/mnt/media/stash/...`）が異なる点に注意
