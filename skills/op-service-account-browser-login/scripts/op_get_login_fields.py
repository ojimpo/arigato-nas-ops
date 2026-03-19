#!/usr/bin/env python3
import argparse
import json
import subprocess
import sys


def run(cmd):
    p = subprocess.run(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
    if p.returncode != 0:
        sys.stderr.write(p.stderr)
        raise SystemExit(p.returncode)
    return p.stdout


def main():
    ap = argparse.ArgumentParser(description="Extract username/password from a 1Password Login item")
    ap.add_argument("--vault", required=True)
    ap.add_argument("--item", required=True, help="Item title or ID")
    args = ap.parse_args()

    raw = run(["op", "item", "get", args.item, "--vault", args.vault, "--format", "json"])
    obj = json.loads(raw)

    username = ""
    password = ""

    for f in obj.get("fields", []):
        fid = (f.get("id") or "").lower()
        label = (f.get("label") or "").strip().lower()
        val = f.get("value") or ""

        if not username and (fid == "username" or label in {"username", "user", "id", "email", "メールアドレス"}):
            username = val
        if not password and (fid == "password" or label == "password"):
            password = val

    # Fallback for custom labels when standard ids are missing
    if not username:
        for f in obj.get("fields", []):
            label = (f.get("label") or "").strip().lower()
            if "user" in label or "mail" in label or "メール" in label:
                username = f.get("value") or ""
                break

    out = {"username": username, "password": password}
    print(json.dumps(out, ensure_ascii=False))

    if not username or not password:
        raise SystemExit("warning: one or more fields are empty")


if __name__ == "__main__":
    main()
