# immich: Google Photos → Immich インポート

Google Takeoutでエクスポートした写真データをImmich（セルフホスト型写真管理）に一括インポートするスクリプト。

## 背景・動機

Google Photosからの脱却として、セルフホストのImmichに移行した。Google Takeoutで書き出したzipファイルやフォルダをImmichに取り込む作業を、`immich-go` CLI経由で簡単に実行できるようにした。

## やったこと

- Google Takeout形式（zipまたは展開済みフォルダ）を `immich-go upload from-google-photos` でImmichにインポートするラッパースクリプト

## 仕組みの説明

```
import-google-photos.sh <takeoutファイル or フォルダ>
  ├─ IMMICH_API_KEY 環境変数をチェック
  └─ immich-go upload from-google-photos を実行
       └─ http://localhost:2283（Immichサーバー）にアップロード
```

## ファイル構成

| ファイル | 役割 |
|---|---|
| `import-google-photos.sh` | Google Takeout → Immich インポートスクリプト |

## セットアップ

### 前提

- Immichが `http://localhost:2283` で稼働していること
- `immich-go` バイナリが `~/bin/immich-go` に配置されていること
- Immich Web UIでAPIキーを発行済みであること

### 使い方

```bash
export IMMICH_API_KEY=your-api-key
./import-google-photos.sh /path/to/takeout-20240101-001.zip
./import-google-photos.sh /path/to/takeout-folder/
```

## 注意点

- APIキーは環境変数 `IMMICH_API_KEY` で渡す（スクリプト内にハードコードしない）
- 大量のファイルをインポートする場合は時間がかかるため、tmux等で実行推奨
