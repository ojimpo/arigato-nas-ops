---
name: cd-rip-whipper
description: Reliable CD ripping workflow using background processes with immediate response pattern.
---

# CD Rip Skill

## Architecture

Uses background `nohup` processes for ripping. Main agent responds immediately and monitors completion.

## Commands

### Main Agent Commands

- **Metadata:** `python3 /home/kouki/clawd/skills/cd-rip-whipper/scripts/cd_meta.py --device /dev/sr0`（`/dev/sr1`, `/dev/sr2` も同様）
- **Spawn Rip:** `nohup /home/kouki/clawd/skills/cd-rip-whipper/scripts/run_full_rip.sh /dev/sr0 > /tmp/rip_sr0.log 2>&1 &`（`sr1/sr2` も同様）
- **Eject:** `bash /home/kouki/clawd/skills/cd-rip-whipper/scripts/eject_cd.sh /dev/sr0`（`sr1/sr2` も同様）

## Chat Style

- **IMPORTANT**: Respond to user messages immediately. Do NOT wait for long operations (ripping, finalization, tag normalization) to complete before replying.
- For time-consuming operations, say: 「バックグラウンドで実行中。完了時に報告する。」and check status later.
- After final notification, ask to eject. Eject only on user confirmation.
- Tone: **素子** style (calm, concise).

## Multi-Disc Handling (at start)

- First run metadata (`cd_meta.py`) and check:
  - `disc_hint_detected`
  - `suggested_total_discs` (MusicBrainz title/artist search)
- If multi-disc hint is detected, propose an explicit count **before ripping**:
  - `このアルバムは {N}枚組っぽいです。{N}枚で進めてOK？`
- If suggestion is missing, fallback question:
  - `このアルバムは全何枚組？（例: 2枚）`
- Ask this only when multi-disc is detected.
- Save confirmed total disc count and use it for `TOTALDISCS` tagging.
- Treat MusicBrainz release ID as a strong key: only attach when high-confidence; otherwise keep canonical text metadata only.

## Multi-Disc Normalization

For albums like "Album Name CD1" / "Album Name CD2":
- Unify ALBUM tag to base name
- Set DISCNUMBER and TOTALDISCS tags
- Prefer user-confirmed total discs when available; otherwise infer carefully.
- Use LLM judgment for ambiguous cases rather than rigid pattern matching.

## Artifact Handling Policy (zip keep)

- Do not leave `.toc/.cue/.m3u/.log` alongside album playback files when they cause Plex split/mis-detect.
- Preserve them by archiving into zip under album subfolder: `<Album>/_ripmeta/`.
- Script:
  - `python3 /home/kouki/clawd/skills/cd-rip-whipper/scripts/archive_artifacts.py "<album_dir>"`
- After zip success, originals are removed.
- Then run Plex refresh (+ empty trash when needed).

## Kashidashi Matching Env Toggles

Used in `finalize_rip.py` for troubleshooting the automatic `ripped_at` update:

| Env Var | Default | Description |
|---|---|---|
| `KASHIDASHI_MATCH_V2` | `0` | `1` enables V2 matching: stronger normalization (katakana→hiragana), matches against `metadata_album`/`metadata_artist`, ambiguity guard skips tied top scores, PATCHes `metadata_artist`/`metadata_album` alongside `ripped_at`. |
| `KASHIDASHI_DRY_RUN` | `0` | `1` logs the would-be PATCH payload without sending it. Useful for verifying match correctness. |
| `KASHIDASHI_BASE_URL` | `http://localhost:18080` | Kashidashi API base URL. |

Observability logs are written to stderr (visible in rip.log) with `[kashidashi]` prefix.
