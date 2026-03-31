#!/usr/bin/env python3
import json, re, urllib.parse, urllib.request, subprocess, argparse
from pathlib import Path

parser = argparse.ArgumentParser()
parser.add_argument("--device", default="/dev/sr0", help="CD device path")
args = parser.parse_args()
DEV = args.device

OUT=Path(f"/mnt/media/audio/_incoming/current_cd_meta_{DEV.split('/')[-1]}.json")
BASE='https://gnudb.gnudb.org/~cddb/cddb.cgi'
HELLO='kouki arigato-nas freac 1.1.7'


DISC_PAT = re.compile(r"(?:disc|cd)\s*[-_\[(]*\s*(\d+)\s*[\])]*", re.I)

def normalize_album_base(album: str) -> str:
    a = DISC_PAT.sub('', album)
    a = re.sub(r'\s+', ' ', a).strip(" -_[]()")
    return a or album

def detect_disc_hint(album: str) -> bool:
    return bool(DISC_PAT.search(album))

def suggest_total_discs_musicbrainz(artist: str, album: str):
    base = normalize_album_base(album)
    q = f'release:"{base}" AND artist:"{artist}"'
    url = 'https://musicbrainz.org/ws/2/release/?' + urllib.parse.urlencode({'query': q, 'fmt': 'json', 'limit': 20})
    req_mb = urllib.request.Request(url, headers={'User-Agent': 'clawd-cd-rip/1.0 (personal use)'})
    try:
        data = json.loads(urllib.request.urlopen(req_mb, timeout=20).read().decode('utf-8', 'replace'))
    except Exception:
        return None, base, 'musicbrainz_error'
    releases = data.get('releases') or []
    counts = []
    for r in releases:
        mc = r.get('medium-count')
        if isinstance(mc, int) and mc > 0:
            title = (r.get('title') or '').lower()
            if base.lower() in title or title in base.lower() or len(releases) <= 3:
                counts.append(mc)
    if not counts:
        return None, base, 'no_candidates'
    # mode, then max as tie-breaker
    mode = max(set(counts), key=lambda x: (counts.count(x), x))
    return int(mode), base, 'musicbrainz'

def req(cmd):
    q={'cmd':cmd,'hello':HELLO,'proto':'6'}
    u=BASE+'?'+urllib.parse.urlencode(q,quote_via=urllib.parse.quote)
    b=urllib.request.urlopen(u,timeout=20).read()
    for e in ('utf-8','shift_jis','euc_jp','latin-1'):
        try:return b.decode(e)
        except:pass
    return b.decode('latin-1','replace')

try:
    o=subprocess.run(['whipper','cd','-d',DEV,'info'],stdout=subprocess.PIPE,stderr=subprocess.STDOUT,text=True,timeout=90).stdout
except subprocess.TimeoutExpired:
    raise SystemExit('cd_meta timeout: whipper cd info took too long (drive busy?)')
m1=re.search(r'CDDB disc id:\s*([0-9a-fA-F]+)',o)
m2=re.search(r'Disc duration:\s*([0-9:.]+),\s*(\d+)\s+audio tracks',o)
m3=re.search(r'MusicBrainz lookup URL\s+\S*\btoc=([^\s&]+)',o)
if not (m1 and m2 and m3):
    raise SystemExit('failed to parse disc info')
discid=m1.group(1).lower(); tracks=int(m2.group(2))
toc_raw=urllib.parse.unquote_plus(m3.group(1))
parts=[int(x) for x in re.split(r'[ +]+', toc_raw.strip()) if x]
leadout=parts[2]; offsets=parts[3:3+tracks]
hhmmss=m2.group(1).split('.')[0]
tp=[int(x) for x in hhmmss.split(':')]
secs=tp[0]*3600+tp[1]*60+tp[2] if len(tp)==3 else tp[0]*60+tp[1]

q=req('cddb query %s %d %s %d'%(discid,tracks,' '.join(map(str,offsets)),secs))
lines=[l.strip() for l in q.splitlines() if l.strip()]
# CDDB response: line 0 is status, line 1+ are matches. Guard against empty/malformed response.
if len(lines) < 2:
    raise SystemExit(f'CDDB query returned no matches for discid {discid}')
parts=lines[1].split(' ',2)
if len(parts) < 2:
    raise SystemExit(f'CDDB query response malformed: {lines[1]}')
cat,did=parts[:2]
r=req(f'cddb read {cat} {did}')
artist='Unknown Artist'; album='Unknown Album'; year=''; genre=''; titles=[]
for line in r.splitlines():
    if line.startswith('DTITLE='):
        v=line.split('=',1)[1]
        if ' / ' in v: artist,album=v.split(' / ',1)
        else: album=v
    elif line.startswith('DYEAR='): year=line.split('=',1)[1]
    elif line.startswith('DGENRE='): genre=line.split('=',1)[1]
    elif line.startswith('TTITLE'):
        k,v=line.split('=',1); titles.append((int(k.replace('TTITLE','')),v))
titles=[v for _,v in sorted(titles)]
frames=[(offsets[i+1] if i+1<len(offsets) else leadout)-offsets[i] for i in range(len(offsets))]
durations=[f/75 for f in frames]
disc_hint = detect_disc_hint(album)
suggested_total_discs, album_base, suggestion_source = suggest_total_discs_musicbrainz(artist, album)
obj={
  'discid':discid,'track_count':tracks,'artist':artist,'album':album,'album_base':album_base,'year':year,'genre':genre,
  'titles':titles,'durations':durations,
  'disc_hint_detected':disc_hint,
  'suggested_total_discs':suggested_total_discs,
  'suggestion_source':suggestion_source
}
OUT.parent.mkdir(parents=True,exist_ok=True)
OUT.write_text(json.dumps(obj,ensure_ascii=False,indent=2),encoding='utf-8')
print(json.dumps(obj,ensure_ascii=False))
