#!/bin/bash
# 早计划采集 wrapper: 跑 collect.sh + 生成 pending-plan.json 供次日会话检测
set -euo pipefail
export PATH="/home/user/.local/bin:/usr/local/bin:/usr/bin:/bin:$PATH"

COLLECT_DIR="${COLLECT_DIR:-~/knowledge/vault/30-projects/daily-recommendation}"
PENDING_FILE="$HOME/.config/daily-work-log/pending-plan.json"
TOMORROW=$(date -d "+1 day" '+%Y-%m-%d')
WEEKDAY=$(date -d "+1 day" '+%u')  # 1=Mon...7=Sun

# 周六周日(6,7)不需要早计划
if [[ "$WEEKDAY" == "6" || "$WEEKDAY" == "7" ]]; then
    echo "次日是周末($WEEKDAY),跳过早计划采集"
    exit 0
fi

# 跑采集
bash "$COLLECT_DIR/scripts/collect.sh" || true

# 生成 pending-plan.json
mkdir -p "$(dirname "$PENDING_FILE")"
python3 -c "
import json, datetime, os
pending = {
    'date': '$TOMORROW',
    'generated_at': datetime.datetime.now().isoformat(timespec='seconds'),
    'claimed_by': None,
    'status': 'pending_plan',
    'sources_file': '$COLLECT_DIR/data/sources.json',
    'rules_file': '$COLLECT_DIR/recommend-rules.md',
    'history_dir': '$COLLECT_DIR/history',
}
with open('$PENDING_FILE', 'w', encoding='utf-8') as f:
    json.dump(pending, f, ensure_ascii=False, indent=2)
print(f'✓ pending-plan.json 已生成: $PENDING_FILE (为 $TOMORROW 准备)')
"

# 更新 cron 指向 wrapper
