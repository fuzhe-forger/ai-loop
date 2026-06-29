#!/bin/bash
# 每日运营巡检与效能报告同步入口。
# 由 crontab 调用；负责把 Multica/Loop/CodeGraph 快照写入 Obsidian。
set -euo pipefail

export HOME="${HOME:-/home/user}"
export PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/home/user/.local/bin:${PATH:-}"

REPO_ROOT="${REPO_ROOT:-/home/user/JAVA/ai/ai-loop}"
WIN_REPO_ROOT="${WIN_REPO_ROOT:-/mnt/d/JAVA/ai/ai-loop}"
VAULT_PATH="${VAULT_PATH:-/mnt/d/JAVA/knowledge/tiandao}"
JAVA_ROOT="${JAVA_ROOT:-/mnt/d/JAVA}"
LOG_DIR="${LOG_DIR:-/mnt/d/JAVA/logs/ai-loop}"
RETENTION_DAYS="${ARCHIVED_ISSUE_RETENTION_DAYS:-7}"
TIMESTAMP="$(date '+%Y%m%d-%H%M%S')"
LOG_FILE="$LOG_DIR/daily-ops-sync-$TIMESTAMP.log"
LATEST_LOG="$LOG_DIR/daily-ops-sync.latest.log"

mkdir -p "$LOG_DIR"

{
  echo "daily-ops-sync start: $(date '+%F %T %z')"
  echo "repo=$REPO_ROOT"
  echo "vault=$VAULT_PATH"
  echo "java_root=$JAVA_ROOT"
  echo "archived_issue_retention_days=$RETENTION_DAYS"

  cd "$REPO_ROOT"

  DRY_RUN=false \
  VAULT_PATH="$VAULT_PATH" \
  REPO_ROOT="$REPO_ROOT" \
  JAVA_ROOT="$JAVA_ROOT" \
  ARCHIVED_ISSUE_RETENTION_DAYS="$RETENTION_DAYS" \
    ./scripts/obsidian-sync.sh

  if [[ -d "$WIN_REPO_ROOT/scripts" ]]; then
    rsync -a "$REPO_ROOT/scripts/obsidian-sync.sh" "$WIN_REPO_ROOT/scripts/obsidian-sync.sh"
    rsync -a "$REPO_ROOT/scripts/daily-ops-sync.sh" "$WIN_REPO_ROOT/scripts/daily-ops-sync.sh"
    echo "synced scripts to $WIN_REPO_ROOT/scripts"
  fi

  echo "daily-ops-sync done: $(date '+%F %T %z')"
} 2>&1 | tee "$LOG_FILE"

cp "$LOG_FILE" "$LATEST_LOG"
