#!/usr/bin/env python3
import argparse
import json
import re
import subprocess
import time
from pathlib import Path

parser = argparse.ArgumentParser()
parser.add_argument("device", nargs="?", default="/dev/sr0", help="CD device path")
args = parser.parse_args()
DEV = args.device

incoming=Path("/mnt/media/audio/_incoming")
dev_name = DEV.split("/")[-1]
active=incoming/f"active_rip_{dev_name}.json"
if not active.exists():
    raise SystemExit(f"no {active}")
st=json.loads(active.read_text())
run=Path(st['run_dir'])
started_epoch=st.get('started_epoch')
meta=json.loads((run/'meta.json').read_text())
artist=meta.get('artist', 'Unknown Artist')
album=meta.get('album', 'Unknown Album')
year=meta.get('year','')
genre=meta.get('genre','')
titles=meta.get('titles', [])

if not titles:
    # Fallback: generate placeholder titles from track_count so rip doesn't crash
    track_count = meta.get('track_count', 0)
    if track_count > 0:
        titles = [f'Track {i}' for i in range(1, track_count + 1)]
    else:
        raise SystemExit('meta.json has no titles and no track_count; cannot finalize')

# Multi-disc normalization:
# If album looks like "... DISC1" / "... DISC2", unify ALBUM and set DISCNUMBER/TOTALDISCS.
m=re.match(r'^(.*)\s+DISC\s*([0-9]+)$', album, flags=re.IGNORECASE)
base_album=album
disc_number=''
total_discs=''
if m:
    base_album=m.group(1).strip()
    disc_number=m.group(2)
    # try to infer total discs from sibling folders
    root=Path('/mnt/media/music')/artist
    nums=[]
    if root.exists():
      for d in root.iterdir():
        if d.is_dir():
          mm=re.match(rf'^{re.escape(base_album)}\s+DISC\s*([0-9]+)$', d.name, flags=re.IGNORECASE)
          if mm:
            nums.append(int(mm.group(1)))
    if nums:
      total_discs=str(max(nums))

dst=Path('/mnt/media/music')/artist/album
dst.mkdir(parents=True,exist_ok=True)

# convert + tag + move
def _safe_filename_title(t:str)->str:
    """Strip audio extensions from title for filename safety. Metadata tag TITLE stays untouched."""
    return re.sub(r'\.(m4a|mp3|wav|flac|aif|aiff)$', '', t, flags=re.IGNORECASE).strip()

for i,title in enumerate(titles,1):
    wav=run/f'track{i:02d}.cdda.wav'
    if wav.exists():
        subprocess.check_call(['flac','-f','-8',str(wav)],stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL)
        wav.unlink(missing_ok=True)
    fl=run/f'track{i:02d}.cdda.flac'
    if not fl.exists():
        fl=run/f'track{i:02d}.cdda.wav.flac'
    if not fl.exists():
        cands=list(run.glob(f'track{i:02d}*.flac'))
        if cands:
            fl=cands[0]
    if not fl.exists():
        raise SystemExit(f'missing flac for track {i}')
    tags=[
      'metaflac','--remove-all-tags',
      f'--set-tag=ARTIST={artist}',f'--set-tag=ALBUM={base_album}',f'--set-tag=TITLE={title}',
      f'--set-tag=TRACKNUMBER={i}',
      *( [f'--set-tag=DATE={year}'] if year else [] ),
      *( [f'--set-tag=GENRE={genre}'] if genre else [] ),
      *( [f'--set-tag=DISCNUMBER={disc_number}'] if disc_number else [] ),
      *( [f'--set-tag=TOTALDISCS={total_discs}'] if total_discs else [] ),
      str(fl)
    ]
    subprocess.check_call(tags)
    file_title=_safe_filename_title(title)
    safe=(f"{i:02d} {artist} - {file_title}.flac").replace('/','-')
    fl.rename(dst/safe)

if (run/'rip.log').exists():
    (run/'rip.log').rename(dst/'rip.log')
active.rename(str(active) + '.done')

# Plex music scan refresh (best-effort)
try:
    tok = subprocess.check_output([
        'docker','exec','plex','sh','-lc',
        'grep -o "PlexOnlineToken=\"[^\"]*\"" "/config/Library/Application Support/Plex Media Server/Preferences.xml" | head -n1 | cut -d\" -f2'
    ], text=True).strip()
    if tok:
        subprocess.run([
            'curl','-s','-o','/dev/null','-w','%{http_code}',
            f'http://127.0.0.1:32400/library/sections/2/refresh?X-Plex-Token={tok}'
        ], check=False)
except Exception:
    pass

# kashidashi ripped_at update (best-effort)
import os
import sys

def _norm(s:str)->str:
    """V1 normalization: strip disc suffixes, collapse to alphanum+kana+kanji."""
    x=(s or '').lower().strip()
    x=x.replace('〜','~').replace('～','~').replace('　',' ')
    x=re.sub(r'\(disc[- ]?\d+\)',' ',x,flags=re.I)
    x=re.sub(r'\[disc[- ]?\d+\]',' ',x,flags=re.I)
    x=re.sub(r'disc[- ]?\d+',' ',x,flags=re.I)
    x=re.sub(r'[^0-9a-zぁ-んァ-ヶ一-龠]+','',x)
    return x

def _norm_v2(s:str)->str:
    """V2 normalization: stronger — katakana→hiragana, strip more punctuation variants."""
    x=_norm(s)
    # katakana block (U+30A1..U+30F6) → hiragana (U+3041..U+3096)
    x=''.join(chr(ord(c)-0x60) if '\u30a1'<=c<='\u30f6' else c for c in x)
    return x

def _kashi_log(msg:str):
    """Observability log for kashidashi matching. Writes to stderr so it shows in rip logs."""
    print(f"[kashidashi] {msg}", file=sys.stderr)

KASHIDASHI_V2   = os.environ.get('KASHIDASHI_MATCH_V2','') == '1'
KASHIDASHI_DRY  = os.environ.get('KASHIDASHI_DRY_RUN','') == '1'
# Structured status for caller-facing completion messages
kashi_status = {
    'status': 'unknown',
    'mode': 'V2' if KASHIDASHI_V2 else 'V1',
    'dry_run': KASHIDASHI_DRY,
    'matched_item_id': None,
    'reason': None,
}

try:
    import urllib.request, urllib.error
    from datetime import datetime, timezone

    base=os.environ.get('KASHIDASHI_BASE_URL','http://localhost:18080').rstrip('/')
    with urllib.request.urlopen(f'{base}/api/items', timeout=8) as resp:
        items=json.loads(resp.read().decode('utf-8'))

    norm_fn = _norm_v2 if KASHIDASHI_V2 else _norm
    album_n=norm_fn(base_album or album)
    artist_n=norm_fn(artist)
    _kashi_log(f"mode={'V2' if KASHIDASHI_V2 else 'V1'} dry={KASHIDASHI_DRY} album_n={album_n!r} artist_n={artist_n!r}")

    cands=[]
    for it in items:
        if it.get('type')!='cd':
            continue
        if it.get('returned_at'):
            continue

        title_n=norm_fn(it.get('title',''))
        item_artist_n=norm_fn(it.get('artist',''))
        score=0

        if KASHIDASHI_V2:
            # V2: also check metadata_album / metadata_artist fields
            meta_album_n=norm_fn(it.get('metadata_album',''))
            meta_artist_n=norm_fn(it.get('metadata_artist',''))

            # album match: check both title and metadata_album
            for an in [title_n, meta_album_n]:
                if an and album_n and (album_n==an or album_n in an or an in album_n):
                    score += 3
                    break
            # artist match: check both artist and metadata_artist
            for ar in [item_artist_n, meta_artist_n]:
                if ar and artist_n and (artist_n in ar or ar in artist_n):
                    score += 1
                    break
        else:
            # V1: original matching logic
            if album_n and (album_n==title_n or album_n in title_n or title_n in album_n):
                score += 3
            if artist_n and item_artist_n and (artist_n in item_artist_n or item_artist_n in artist_n):
                score += 1

        if score>0:
            cands.append((score, it))

    _kashi_log(f"candidates={len(cands)}" + (f" scores={[c[0] for c in cands]}" if cands else ""))

    if cands:
        cands.sort(key=lambda x: (x[0], x[1].get('borrowed_date','')), reverse=True)
        top_score=cands[0][0]

        # Ambiguity guard: if multiple items share the top score, skip to avoid wrong update
        tied=[c for c in cands if c[0]==top_score]
        if len(tied)>1 and KASHIDASHI_V2:
            _kashi_log(f"SKIP: {len(tied)} items tied at score={top_score}, ambiguous — ids={[c[1].get('id') for c in tied]}")
            kashi_status.update({'status':'skipped','reason':'ambiguous_tie'})
        else:
            if len(tied)>1:
                _kashi_log(f"WARN: {len(tied)} items tied at score={top_score} (V1 proceeds anyway)")

            target=cands[0][1]
            rid=target.get('id')
            now_iso=datetime.now(timezone.utc).replace(microsecond=0).isoformat().replace('+00:00','Z')
            _kashi_log(f"match: id={rid} title={target.get('title')!r} artist={target.get('artist')!r} score={top_score}")

            # Build PATCH payload — V2 enriches with metadata_artist/metadata_album from rip
            patch_data={'ripped_at': now_iso}
            if KASHIDASHI_V2:
                patch_data['metadata_artist']=artist
                patch_data['metadata_album']=base_album or album

            if KASHIDASHI_DRY:
                _kashi_log(f"DRY-RUN: would PATCH id={rid} with {json.dumps(patch_data, ensure_ascii=False)}")
                kashi_status.update({'status':'dry_run_match','matched_item_id':rid,'reason':'dry_run'})
            else:
                req=urllib.request.Request(
                    f'{base}/api/items/{rid}',
                    data=json.dumps(patch_data).encode('utf-8'),
                    headers={'Content-Type':'application/json'},
                    method='PATCH'
                )
                with urllib.request.urlopen(req, timeout=8) as _:
                    _kashi_log(f"PATCHED id={rid}")
                kashi_status.update({'status':'matched','matched_item_id':rid})
    else:
        _kashi_log("no candidates matched")
        kashi_status.update({'status':'no_match','reason':'no_candidates'})
except Exception as e:
    _kashi_log(f"error: {e}")  # observability even on failure
    kashi_status.update({'status':'error','reason':str(e)})

def _fmt_elapsed(sec:int)->str:
    h=sec//3600; m=(sec%3600)//60; s=sec%60
    if h>0:
        return f"{h:02d}:{m:02d}:{s:02d}"
    return f"{m:02d}:{s:02d}"

if isinstance(started_epoch, int):
    elapsed=max(0,int(time.time())-started_epoch)
    print(json.dumps({"dst":str(dst),"elapsed_seconds":elapsed,"elapsed":_fmt_elapsed(elapsed),"kashidashi":kashi_status}, ensure_ascii=False))
else:
    print(json.dumps({"dst":str(dst),"kashidashi":kashi_status}, ensure_ascii=False))
