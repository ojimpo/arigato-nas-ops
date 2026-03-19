# Enrichment Playbook (image / ISBN / TMDb)

## CD canonical metadata (for matching reliability)
- Primary goal: improve cross-service matching quality (e.g., Last.fm) beyond raw library labels.
- Fill `metadata_artist` and `metadata_album` from CDDB/whipper metadata when available.
- `musicbrainz_release_id` is optional but high-value; add it only on high-confidence matches.

### High-confidence checklist for `musicbrainz_release_id`
- Normalized artist and album are consistent with candidate release title/artist.
- Disc count / disc position does not conflict with observed media.
- No near-duplicate competing candidates with similar score.
- If any doubt remains, leave `musicbrainz_release_id` empty.

## Image URL (all types)
- Search query:
  - book: `<title> <author> 書影`
  - cd: `<title> <artist> ジャケット`
  - dvd: `<title> 作品 ポスター`
- Prefer stable sources: publisher, retailer product pages, TMDb, Google Books.
- Save direct image URL when possible (`.jpg/.png/webp`).
- If no reliable image found, omit `image_url`.

## ISBN (book)
- Query pattern: `<title> <author> ISBN`
- Cross-check at least 2 sources when title is common.
- Normalize to digits/X without hyphens before storing if multiple formats appear.

## TMDb ID (dvd)
- Query pattern: `<title> site:themoviedb.org`
- Extract numeric ID from URL like `https://www.themoviedb.org/movie/12345-...`.
- If ambiguous remakes exist, use year from detail page and compare with library listing notes.

## Type mapping hints from library labels
- Contains `ＣＤ` / `CD` / `録音` -> `cd`
- Contains `図書` / `本` / `一般書` / `文庫` -> `book`
- Contains `ＤＶＤ` / `DVD` / `映像` -> `dvd`
- Otherwise -> `other` and preserve raw label in `notes`
