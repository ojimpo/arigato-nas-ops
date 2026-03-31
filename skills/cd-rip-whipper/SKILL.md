---
name: openclaw-cd-rip
description: CD ripping with multi-source metadata resolution, automatic sanitization, and LLM-assisted correction for unresolved issues.
---

# OpenClaw CD Rip

## Commands

### Rip (background — primary command)
```
nohup python3 /home/kouki/dev/openclaw-cd-rip/scripts/run_rip.py /dev/sr0 > /tmp/rip_sr0.log 2>&1 &
```
`sr1`, `sr2` も同様。ドライブ間は完全独立で並行実行可能。

### Disc Info (debug用 — 通常は run_rip.py が内部で実行)
```
python3 /home/kouki/dev/openclaw-cd-rip/scripts/cd_info.py --device /dev/sr0
```

### Progress
```
python3 /home/kouki/dev/openclaw-cd-rip/scripts/progress.py
```

### Eject
```
python3 /home/kouki/dev/openclaw-cd-rip/scripts/eject.py /dev/sr0
```

## 基本動作 — 「入れたら即開始、問題時だけ報告」

1. ユーザーが「CD入れた」と言ったら、**確認なしで即座に** run_rip.py をバックグラウンド実行
2. 「了解、取り込み開始する」とだけ返答
3. 完了を検知したら結果を報告:
   - 正常完了 → 「{album} 完了。イジェクトする？」
   - 問題あり → issues に応じて対処（後述）

## イジェクト

- **自動イジェクトしない** — ユーザーが明示した場合のみ
- 完了報告時に「イジェクトする？」と聞く
- 複数枚組のとき: 完了報告 → ユーザー確認 → イジェクト → 次ディスク挿入待ち

## マルチディスク

- run_rip.py がメタデータから枚数を自動推定（MusicBrainz medium-count）
- 推定できない場合のみ「何枚組？」と確認
- 確認済みの枚数は環境変数で渡す:
  ```
  OPENCLAW_TOTAL_DISCS=3 OPENCLAW_DISC_NUMBER=2 nohup python3 .../run_rip.py /dev/sr0 ...
  ```

## 複数ドライブ同時リッピング

- /dev/sr0, sr1, sr2 の3ドライブに対応
- 各ドライブは完全独立。同時に3枚リッピング可能
- ユーザーが「sr0とsr1に入れた」→ 両方同時に run_rip.py を起動

## 問題発生時のみ介入

リッピング完了 JSON を確認。`issues[]` と `needs_review` をチェック。

### issues[] がある場合

| issue | 対応 |
|---|---|
| `mojibake` | Web 検索でアルバム名・曲名の正式名を取得。metaflac で修正。Plex リフレッシュ。 |
| `no_track_titles` | Web 検索で公式トラックリスト取得。metaflac で修正。Plex リフレッシュ。 |
| `artist_variant` | カタカナアーティストを英語に統一すべきか判断し修正。 |

### needs_review = true の場合（confidence < 50）

- Web 検索でアルバム情報を特定
- metaflac でタグ修正
- 修正内容をユーザーに報告

### issues が空 & needs_review = false の場合

そのまま完了報告。余計な報告はしない。

## メタデータ修正のヒント

metaflac でのタグ修正は Python バッチスクリプトで行う（シェルのクォーティング問題回避）。例:

```python
import subprocess
tracks = {
    "01": {"ARTIST": "...", "TITLE": "..."},
    # ...
}
for num, tags in tracks.items():
    cmd = ["metaflac", "--remove-all-tags"]
    for k, v in tags.items():
        cmd.append(f"--set-tag={k}={v}")
    cmd.append(f"/mnt/media/music/Artist/Album/{num} Artist - Title.flac")
    subprocess.check_call(cmd)
```

修正後は必ず Plex リフレッシュ:
```
curl -s "http://localhost:32400/library/sections/2/refresh?X-Plex-Token=$(docker exec plex sh -lc 'grep -o "PlexOnlineToken=\"[^\"]*\"" "/config/Library/Application Support/Plex Media Server/Preferences.xml" | head -n1 | cut -d\" -f2')"
```

## 環境変数リファレンス

### ヒント（メタデータ解決の補助）
| Env Var | 説明 |
|---|---|
| `CD_RIP_HINT_CATALOG` | カタログ番号（例: VICP-64336） |
| `CD_RIP_HINT_JAN` | JANコード |
| `CD_RIP_HINT_TITLE` | アルバム名ヒント |
| `CD_RIP_HINT_ARTIST` | アーティストヒント |

### 強制上書き
| Env Var | 説明 |
|---|---|
| `CD_RIP_FORCE_ARTIST` | アーティストを強制指定 |
| `CD_RIP_FORCE_ALBUM` | アルバム名を強制指定 |
| `CD_RIP_FORCE_TITLES` | トラック名を JSON 配列で強制指定 |
| `CD_RIP_FORCE_ITEM_ID` | kashidashi アイテム ID を強制指定 |

### マルチディスク
| Env Var | 説明 |
|---|---|
| `OPENCLAW_TOTAL_DISCS` | 全ディスク枚数 |
| `OPENCLAW_DISC_NUMBER` | 現在のディスク番号 |

### ポリシー
| Env Var | Default | 説明 |
|---|---|---|
| `OPENCLAW_DRY_RUN` | `0` | `1` で全副作用を無効化 |
| `OPENCLAW_TRACK_TIMEOUT` | `600` | トラックごとのリッピングタイムアウト（秒） |

### 外部連携
| Env Var | Default | 説明 |
|---|---|---|
| `KASHIDASHI_BASE_URL` | `http://localhost:18080` | kashidashi API |
| `DISCOGS_TOKEN` | (なし) | Discogs API トークン |
| `CD_RIP_DISCORD_WEBHOOK_URL` | (なし) | Discord webhook |

## Chat Style

- 素子 style（calm, concise）
- バックグラウンド処理は即座に応答、完了時に報告
- 余計な説明はしない
