# browser-relay: OpenClawブラウザリレーの完全自動化

OpenClawのブラウザリレー（Chrome拡張経由でWebページを操作する機能）を、マシン再起動後も自動で復旧するようにした。

## 背景・動機

OpenClawのブラウザリレーは便利だが、以下の手動作業が毎回必要だった：

1. Chrome起動
2. ウィンドウ最大化
3. Chrome拡張のアイコンをクリックしてアタッチ

特にヘッドレスサーバー（arigato-nas）上でRDP経由で操作していたため、再起動のたびにRDPで繋いでポチポチする必要があり、地味にだるかった。

## やったこと

systemdのoneshotサービスで、gateway起動後に3ステップを自動実行する：

```
openclaw-gateway.service (起動)
  └─ openclaw-browser-autostart.service
       ├── browser-start.sh      … Chrome起動 (リトライ付き)
       ├── browser-maximize.sh   … CDP経由でウィンドウ最大化
       └── browser-autoattach.sh … スクショ→テンプレートマッチング→アイコンクリック
```

### テンプレートマッチングによるアイコン検出

拡張アイコンの位置をハードコードすると、拡張の追加・削除やChrome更新で座標がズレる。

そこで**OpenCVのテンプレートマッチング**で毎回スクショからアイコンを探す方式にした：

1. `xwd` でX11のスクリーンショットを撮る
2. 事前に保存したアイコン画像（32×32px）をテンプレートとして `cv2.matchTemplate` で検索
3. 一致度 0.8 以上ならその座標をクリック、成功座標をキャッシュ
4. 一致しない場合はキャッシュした前回座標にフォールバック

#### XWDパースの罠

Pythonで `xwd` の出力をパースする際、ヘッダサイズだけオフセットすると**カラーマップの分だけズレる**：

```python
# ❌ 間違い
pixel_offset = header_size

# ✅ 正しい
ncolors = struct.unpack('>I', data[76:80])[0]
pixel_offset = header_size + ncolors * 12  # XWDColor = 12 bytes each
```

### Discord通知

各ステップの成功・失敗をDiscord Webhookで通知する：

- ✅ 全ステップ成功（検出座標付き）
- ❌ Chrome起動失敗
- ⚠️ 最大化失敗 / アイコン検出失敗 / アタッチ失敗

## セットアップ

### 前提

- Linux + X11 (XRDP等でディスプレイが存在すること)
- OpenClaw gateway が動作していること
- OpenClaw Browser Relay 拡張がChromeにインストール・ピン留めされていること

### 必要パッケージ

```bash
sudo apt install xdotool x11-apps  # xdotool, xwd
pip install --user opencv-python-headless websocket-client numpy
```

### 手順

1. 環境変数ファイルを作成：

```bash
cp env.example ~/.config/openclaw-browser-relay.env
# トークン・Webhook URLを記入
```

2. アイコンのテンプレート画像を用意：

RDPでChromeを開き、拡張がOFF状態のときにスクショを撮ってアイコン部分を32×32pxで切り出す。
（同梱の `icon-template.png` はOpenClaw Browser Relay拡張のデフォルトアイコン）

3. systemdサービスを配置・有効化：

```bash
cp autostart.service ~/.config/systemd/user/openclaw-browser-autostart.service
# ExecStart/ExecStartPost のパスを自分の環境に合わせて編集
systemctl --user daemon-reload
systemctl --user enable openclaw-browser-autostart
```

## ファイル構成

| ファイル | 役割 |
|---|---|
| `autostart.service` | systemd oneshotサービス定義 |
| `browser-start.sh` | Chrome起動（最大30秒リトライ） |
| `browser-maximize.sh` | CDP経由でウィンドウ最大化 |
| `browser-autoattach.sh` | テンプレートマッチング→アイコンクリック→検証 |
| `icon-template.png` | 拡張アイコンのテンプレート画像（32×32px） |
| `env.example` | 環境変数のテンプレート |

## 注意点

- 画面解像度が変わった場合、テンプレート画像の再作成が必要になる場合がある
- `--disable-setuid-sandbox` の警告バーが表示される場合、ツールバーの描画領域がずれてテンプレートマッチングに影響する可能性がある
- Chrome拡張のアイコンが「ピン留め」されていることを確認すること（パズルピースメニューに入ると検出できない）
