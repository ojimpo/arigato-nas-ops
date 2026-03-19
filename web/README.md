# web: ojimpo.com 個人サイトサーバー

ojimpo.com（個人サイト）をPythonの軽量HTTPサーバーでホスティングするsystemdサービス。

## 背景・動機

個人サイト ojimpo.com を自宅サーバーから直接配信したかった。Nginx等のフル機能Webサーバーは不要で、Pythonスクリプト1つで十分なので、systemdユーザーサービスとして常駐させている。Cloudflare Tunnelで外部公開。

## やったこと

- Pythonの軽量サーバースクリプト（`~/sites/ojimpo/server.py`）をsystemdユーザーサービスとして自動起動・自動復旧する設定

## 仕組みの説明

```
systemd (user)
  └─ ojimpo-web.service
       └─ python3 ~/sites/ojimpo/server.py
       └─ Restart=on-failure で障害時自動復旧

外部公開:
  Cloudflare Tunnel → ojimpo-web.service → 静的ファイル配信
```

## ファイル構成

| ファイル | 役割 |
|---|---|
| `ojimpo-web.service` | 個人サイトサーバーのsystemdサービス定義 |

## 注意点

- サーバー本体のコード（`server.py`）は `~/sites/ojimpo/` に配置されており、このリポジトリには含まない
- Cloudflare Tunnel側の設定は別途必要
