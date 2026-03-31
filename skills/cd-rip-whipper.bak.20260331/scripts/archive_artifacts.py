#!/usr/bin/env python3
import argparse
from pathlib import Path
import zipfile

EXTS = {'.toc', '.cue', '.m3u', '.log'}


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('album_dir', help='Album directory path')
    args = ap.parse_args()

    album = Path(args.album_dir)
    if not album.exists() or not album.is_dir():
        raise SystemExit(f'album_dir not found: {album}')

    ripmeta = album / '_ripmeta'
    ripmeta.mkdir(parents=True, exist_ok=True)

    artifact_files = [
        p for p in album.rglob('*')
        if p.is_file() and p.suffix.lower() in EXTS and '_ripmeta' not in p.parts
    ]

    if not artifact_files:
        print('NO_ARTIFACTS')
        return

    by_parent = {}
    for f in artifact_files:
        by_parent.setdefault(f.parent, []).append(f)

    archived = []
    for parent, files in sorted(by_parent.items(), key=lambda x: str(x[0])):
        rel = parent.relative_to(album)
        label = 'album_root' if str(rel) == '.' else str(rel).replace('/', '__')
        zpath = ripmeta / f'{label}_artifacts.zip'
        i = 1
        while zpath.exists():
            zpath = ripmeta / f'{label}_artifacts_{i}.zip'
            i += 1

        with zipfile.ZipFile(zpath, 'w', compression=zipfile.ZIP_DEFLATED) as zf:
            for f in sorted(files):
                zf.write(f, arcname=str(f.relative_to(parent)))

        # delete originals only after zip success
        for f in files:
            f.unlink(missing_ok=True)

        archived.append((str(zpath), len(files)))

    for z, c in archived:
        print(f'ARCHIVED {c} -> {z}')


if __name__ == '__main__':
    main()
