#!/usr/bin/env python3
"""Check rip progress for one or all drives (sr0/sr1/sr2)."""
import argparse
import json
from pathlib import Path

INCOMING = Path('/mnt/media/audio/_incoming')
DEVICES = ['sr0', 'sr1', 'sr2']

parser = argparse.ArgumentParser()
parser.add_argument('--device', default=None, help='Device path e.g. /dev/sr0 (omit to check all drives)')
args = parser.parse_args()

def check_drive(dev_name: str) -> dict:
    active = INCOMING / f'active_rip_{dev_name}.json'
    if not active.exists():
        return {'device': dev_name, 'active': False}
    st = json.loads(active.read_text())
    run = Path(st['run_dir'])
    meta = json.loads((run / 'meta.json').read_text()) if (run / 'meta.json').exists() else {'track_count': 0, 'titles': []}
    tracks = meta.get('track_count', 0)
    titles = meta.get('titles', [])
    # track00 is pregap, ignore
    done = sorted([p for p in run.glob('track*.cdda.wav') if p.name != 'track00.cdda.wav'])
    count = len(done)
    obj = {'device': dev_name, 'active': True, 'runDir': str(run), 'doneTracks': count, 'totalTracks': tracks, 'done': (tracks > 0 and count >= tracks)}
    if tracks > 0:
        obj['lastTitle'] = titles[count - 1] if 0 < count <= len(titles) else None
    return obj

if args.device:
    dev_name = args.device.split('/')[-1]
    print(json.dumps(check_drive(dev_name), ensure_ascii=False))
else:
    # Check all drives, report only active ones (or all-inactive summary)
    results = [check_drive(d) for d in DEVICES]
    active_results = [r for r in results if r['active']]
    print(json.dumps(active_results if active_results else results, ensure_ascii=False))
