#!/bin/bash
# Google Photos (Google Takeout) → Immich インポートスクリプト
#
# 使い方:
#   ./import-google-photos.sh <takeoutファイルまたはフォルダ>
#
# 例:
#   ./import-google-photos.sh /path/to/takeout-20240101-001.zip
#   ./import-google-photos.sh /path/to/takeout-folder/
#   ./import-google-photos.sh /path/to/takeout-*.zip

set -euo pipefail

IMMICH_SERVER="http://localhost:2283"
IMMICH_GO="/home/kouki/bin/immich-go"

# APIキーを環境変数 IMMICH_API_KEY から取得
if [ -z "${IMMICH_API_KEY:-}" ]; then
  echo "エラー: IMMICH_API_KEY 環境変数を設定してください"
  echo ""
  echo "Immich Web UI でAPIキーを取得する手順:"
  echo "  1. http://localhost:2283 にログイン"
  echo "  2. アカウント設定 → APIキー → 新規作成"
  echo "  3. 以下を実行してからこのスクリプトを再実行:"
  echo "     export IMMICH_API_KEY=<your-api-key>"
  exit 1
fi

if [ $# -eq 0 ]; then
  echo "使い方: $0 <takeoutファイルまたはフォルダ> [追加のパス...]"
  echo ""
  echo "例:"
  echo "  $0 /path/to/takeout-20240101-001.zip"
  echo "  $0 /path/to/takeout-folder/"
  exit 1
fi

echo "==================================="
echo " Google Photos → Immich インポート"
echo "==================================="
echo "サーバー: $IMMICH_SERVER"
echo "対象: $*"
echo ""

"$IMMICH_GO" upload from-google-photos \
  --server="$IMMICH_SERVER" \
  --api-key="$IMMICH_API_KEY" \
  "$@"

echo ""
echo "インポート完了!"
echo "Immich Web UI で確認: $IMMICH_SERVER"
