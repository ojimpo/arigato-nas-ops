---
name: wol-hachiman
description: Wake hachiman-desk (gaming PC) via Wake-on-LAN.
---

# WoL Hachiman Skill

## Overview

hachiman-desk（ゲーミングPC）をWake-on-LANで起動するスキル。

- MAC: `XX:XX:XX:XX:XX:XX`
- LAN IP: `192.168.x.x`
- Tailscale IP: `100.x.x.x`

## Commands

**起動:**
```
bash /home/kouki/clawd/skills/wol-hachiman/scripts/wake.sh
```

**起動確認（Tailscale経由でping）:**
```
ping -c 3 100.x.x.x
```

## Chat Style

- 起動コマンド実行後、「WoLパケットを送りました。30〜60秒で起動します。」と伝える。
- 確認したい場合はTailscale IPにpingして応答を確認。
- Tone: 素子スタイル（簡潔・冷静）。
