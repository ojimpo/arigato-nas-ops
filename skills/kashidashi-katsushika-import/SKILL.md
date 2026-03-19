---
name: kashidashi-katsushika-import
description: Import currently-borrowed items (books/CDs/DVDs) from Katsushika City Library pages into a kashidashi API instance. Use when user asks to fetch current loans from the library website, dedupe against GET /api/items, enrich missing metadata (image/ISBN/TMDb), and register new entries via POST /api/items.
---

# Kashidashi Katsushika Import

Execute this workflow to collect current loan items from the 葛飾区立図書館 site and register only new records into kashidashi.

## Workflow

1. Confirm API endpoint and schema.
2. Log in to library site and extract current loan rows.
3. Normalize item type and date fields.
4. Enrich each new item (image URL, book ISBN, dvd TMDb ID).
5. Import with dedupe using bundled script.
6. Report counts and inserted list.

## 1) Confirm API endpoint and schema

Use base URL (typically `http://localhost:18080`).

- Read API docs at `/openapi.json` or `/docs`.
- Confirm `ItemType` supports: `cd`, `book`, `dvd`, `other`.
- Use `library = 葛飾区立中央図書館` unless explicitly overridden.

## 2) Get credentials and log in

Use skill `op-service-account-browser-login` to fetch username/password from 1Password service account. Do not expose credentials in chat.

Then automate browser login to the Katsushika library My Page and open the current-loans list.

## 3) Extract and normalize items

For each row, extract:
- `title`
- `artist` or `author`
- `borrowed_date` (`YYYY-MM-DD`)
- `due_date` (`YYYY-MM-DD`)
- raw material label (for type mapping)

Type mapping:
- CD-like label -> `cd`
- Book-like label -> `book`
- DVD-like label -> `dvd`
- uncertain -> `other` and append original label into `notes`

Save extracted entries as JSON array for import script.

## 4) Enrich metadata

Read `references/enrichment-playbook.md` and add when available:
- `image_url` (all types)
- `isbn` (book)
- `tmdb_id` (dvd)
- `metadata_artist` / `metadata_album` (cd, from CDDB/whipper metadata)
- `musicbrainz_release_id` (cd, **only when high-confidence match**)

If unresolved, omit the field (do not block import).

### CD metadata policy (important)
- Treat `musicbrainz_release_id` as a strong external key (for Last.fm/other service reconciliation).
- Therefore, set it only when confidence is high (e.g., artist+album normalized match, disc count consistency, and no close conflicting candidates).
- If ambiguous, do **not** set MBID; keep only `metadata_artist` / `metadata_album`.

## 5) Dedupe + import

Run:

```bash
python3 scripts/import_items.py \
  --base-url http://localhost:18080 \
  --input /tmp/katsushika_loans.json
```

Behavior:
- Fetch existing items via `GET /api/items`
- Deduplicate by `(title, artist/author, borrowed_date)`
- Insert only new rows via `POST /api/items`
- Print JSON summary (`fetched`, `inserted`, `skipped`, `errors`)

Use `--dry-run` for validation before writing.

## 6) Report format

Report in Japanese:
- 取得件数
- 新規登録件数
- スキップ件数（既存）
- エラー件数（あれば）
- 新規登録一覧（type / title / person / borrowed / due）

## Resources

- `scripts/import_items.py`: deterministic dedupe/import runner for kashidashi API.
- `references/enrichment-playbook.md`: search heuristics for image, ISBN, TMDb.
