#!/bin/bash
# Watch arigato-nas-ops repo for changes and auto-commit+push.
# Run as: systemctl --user start ops-auto-sync

REPO_DIR="/home/kouki/dev/arigato-nas-ops"
cd "$REPO_DIR" || exit 1

echo "Watching $REPO_DIR for changes..."

inotifywait -m -r -e close_write -e create -e delete -e moved_to \
  --exclude '\.git/' \
  "$REPO_DIR" |
while read -r dir event file; do
  # Debounce: wait a bit for multiple rapid changes
  sleep 2

  # Drain any queued events
  while read -t 0.5 -r _ _ _; do :; done

  # Check if there are actual changes
  cd "$REPO_DIR"
  if git diff --quiet && git diff --cached --quiet && [ -z "$(git ls-files --others --exclude-standard)" ]; then
    continue
  fi

  # Auto-commit and push
  git add -A
  CHANGED=$(git diff --cached --name-only | head -5 | tr '\n' ', ' | sed 's/,$//')
  git commit -m "auto: update ${CHANGED}" > /dev/null 2>&1
  git push origin master > /dev/null 2>&1

  if [ $? -eq 0 ]; then
    echo "$(date '+%Y-%m-%d %H:%M:%S') pushed: ${CHANGED}"
  else
    echo "$(date '+%Y-%m-%d %H:%M:%S') push failed" >&2
  fi
done
