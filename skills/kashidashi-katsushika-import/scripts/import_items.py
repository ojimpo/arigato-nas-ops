#!/usr/bin/env python3
"""Import library-loan items into kashidashi API with dedupe.

Input JSON format (array):
[
  {
    "type": "cd|book|dvd|other",
    "title": "...",
    "artist": "...",          # for cd
    "author": "...",          # for book
    "borrowed_date": "YYYY-MM-DD",
    "due_date": "YYYY-MM-DD",
    "library": "葛飾区立中央図書館",   # optional
    "image_url": "https://...",       # optional
    "isbn": "...",                    # optional (book)
    "tmdb_id": "...",                 # optional (dvd)
    "notes": "..."                    # optional
  }
]
"""

from __future__ import annotations

import argparse
import json
import sys
from dataclasses import dataclass
from pathlib import Path
from typing import Any

import requests


ALLOWED_TYPES = {"cd", "book", "dvd", "other"}


@dataclass(frozen=True)
class DedupKey:
    title: str
    person: str
    borrowed_date: str


def normalize_text(value: str | None) -> str:
    if not value:
        return ""
    return " ".join(value.strip().split()).lower()


def to_key(item: dict[str, Any]) -> DedupKey:
    person = item.get("artist") or item.get("author") or ""
    return DedupKey(
        title=normalize_text(item.get("title")),
        person=normalize_text(person),
        borrowed_date=str(item.get("borrowed_date") or "").strip(),
    )


def validate_item(raw: dict[str, Any]) -> dict[str, Any]:
    item = dict(raw)

    if item.get("type") not in ALLOWED_TYPES:
        raise ValueError(f"invalid type: {item.get('type')}")

    for required in ("title", "borrowed_date", "due_date"):
        if not item.get(required):
            raise ValueError(f"missing required field: {required}")

    item.setdefault("library", "葛飾区立中央図書館")

    # Keep only fields accepted by ItemCreate
    allowed = {
        "type",
        "title",
        "artist",
        "author",
        "library",
        "borrowed_date",
        "due_date",
        "image_url",
        "musicbrainz_release_id",
        "isbn",
        "tmdb_id",
        "metadata_artist",
        "metadata_album",
        "notes",
    }
    return {k: v for k, v in item.items() if k in allowed and v is not None}


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--base-url", required=True, help="e.g. http://localhost:18080")
    parser.add_argument("--input", required=True, help="Path to JSON array file")
    parser.add_argument("--timeout", type=float, default=10.0)
    parser.add_argument("--dry-run", action="store_true")
    args = parser.parse_args()

    base_url = args.base_url.rstrip("/")
    items_url = f"{base_url}/api/items"

    input_path = Path(args.input)
    data = json.loads(input_path.read_text(encoding="utf-8"))
    if not isinstance(data, list):
        raise ValueError("input must be a JSON array")

    normalized: list[dict[str, Any]] = []
    for idx, raw in enumerate(data, start=1):
        if not isinstance(raw, dict):
            raise ValueError(f"item #{idx} is not an object")
        try:
            normalized.append(validate_item(raw))
        except Exception as e:
            raise ValueError(f"item #{idx} invalid: {e}") from e

    existing_res = requests.get(items_url, timeout=args.timeout)
    existing_res.raise_for_status()
    existing_items = existing_res.json()

    seen = {to_key(item) for item in existing_items}

    inserted: list[dict[str, Any]] = []
    skipped: list[dict[str, Any]] = []
    errors: list[dict[str, Any]] = []

    for item in normalized:
        key = to_key(item)
        if key in seen:
            skipped.append(item)
            continue

        if args.dry_run:
            inserted.append(item)
            seen.add(key)
            continue

        try:
            res = requests.post(items_url, json=item, timeout=args.timeout)
            res.raise_for_status()
            created = res.json()
            inserted.append(created)
            seen.add(key)
        except Exception as e:  # noqa: BLE001
            errors.append({"item": item, "error": str(e)})

    summary = {
        "fetched": len(normalized),
        "inserted": len(inserted),
        "skipped": len(skipped),
        "errors": len(errors),
        "inserted_items": inserted,
        "skipped_items": skipped,
        "error_items": errors,
    }
    print(json.dumps(summary, ensure_ascii=False, indent=2))
    return 0 if not errors else 2


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except Exception as exc:  # noqa: BLE001
        print(f"ERROR: {exc}", file=sys.stderr)
        raise
