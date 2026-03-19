# gui: XRDPのオン・オフ制御

ヘッドレスサーバー上のXRDPサービスをワンコマンドで起動・停止・確認するユーティリティ。

## 背景・動機

arigato-nasは基本的にヘッドレス（SSH/CLI）で運用しているが、ブラウザリレー設定やGUI操作が必要な場面がたまにある。そのときだけXRDPを起動してMacからRDP接続し、終わったら止める。常時起動は無駄なので、必要なときだけ上げ下げするスタイル。

## やったこと

3つのシンプルなコマンドで、sudoなしで（NOPASSWD設定済み）XRDPを制御できるようにした。

## 仕組みの説明

```
gui-on   → systemctl start xrdp  → Mac RDPで接続可能に
gui-off  → systemctl stop xrdp   → RDPセッション終了
gui-status → systemctl is-active / status xrdp
```

sudoは `NOPASSWD` で `/usr/bin/systemctl` に対して許可されている前提。

## ファイル構成

| ファイル | 役割 |
|---|---|
| `gui-on` | XRDPを起動し、接続先情報を表示 |
| `gui-off` | XRDPを停止 |
| `gui-status` | XRDPの稼働状態を表示 |

## 注意点

- `sudo -n`（非対話的sudo）を使用しているため、事前にsudoers設定が必要
- RDP接続先: `arigato-nas:3389`（Tailscale経由なら `100.85.219.71:3389`）
