#!/usr/bin/env python3
import json
import os
import re
import urllib.request
import urllib.error
from pathlib import Path

STATE = Path('/mnt/media/audio/_incoming/final_notify_sent.json')
LOGS = [Path('/tmp/rip_sr0.log'), Path('/tmp/rip_sr1.log'), Path('/tmp/rip_sr2.log')]
PAT = re.compile(r'<@YOUR_DISCORD_USER_ID> リッピング完了.*ディスクをイジェクトする？')


def load_seen() -> set[str]:
    if not STATE.exists():
        return set()
    try:
        obj = json.loads(STATE.read_text(encoding='utf-8'))
    except Exception:
        return set()
    if isinstance(obj, list):
        return set(str(x) for x in obj)
    if isinstance(obj, dict):
        seen = obj.get('seen', [])
        if isinstance(seen, list):
            return set(str(x) for x in seen)
    return set()


def save_seen(seen: set[str]) -> None:
    STATE.write_text(json.dumps({'seen': sorted(seen)}, ensure_ascii=False, indent=2), encoding='utf-8')


def completion_lines(log_path: Path) -> list[str]:
    if not log_path.exists():
        return []
    lines = log_path.read_text(errors='ignore').splitlines()
    return [ln.strip() for ln in lines if PAT.search(ln)]


def post_to_discord(message: str) -> None:
    webhook_url = os.environ.get('CD_RIP_DISCORD_WEBHOOK_URL', '').strip()
    if not webhook_url:
        raise RuntimeError('CD_RIP_DISCORD_WEBHOOK_URL is not set')
    body = json.dumps({'content': message}).encode('utf-8')
    req = urllib.request.Request(
        webhook_url,
        data=body,
        headers={'Content-Type': 'application/json'},
        method='POST',
    )
    urllib.request.urlopen(req, timeout=10)


def main() -> None:
    seen = load_seen()
    candidates: list[tuple[str, str]] = []
    for lp in LOGS:
        for line in completion_lines(lp):
            key = f'{lp}|{line}'
            if key not in seen:
                candidates.append((key, line))

    if not candidates:
        return

    # Send oldest unseen first to avoid dropping earlier completions
    key, line = candidates[0]
    seen.add(key)
    save_seen(seen)
    post_to_discord(line)


if __name__ == '__main__':
    main()
