#!/usr/bin/env bash
# 建issue前查重：拉全量issue比对标题，命中同标题(任意状态)则建议复用而非新建。
# 用法: issue-dedup-check.sh "<标题>"
# 退出码: 0=无重复可建; 1=有重复建议复用; 2=参数错误
set -euo pipefail
export PATH="/usr/local/bin:/home/user/.local/bin:$PATH"

TITLE="${1:-}"
if [[ -z "$TITLE" ]]; then
  echo "usage: $0 <title>" >&2
  exit 2
fi
export TITLE

issue-tracker issue list --output json 2>/dev/null | python3 -c '
import sys, json, os
title = os.environ["TITLE"].strip()
data = json.load(sys.stdin)
issues = data.get("issues", data) if isinstance(data, dict) else data
hits = [i for i in issues if isinstance(i, dict) and i.get("title", "").strip() == title]
if hits:
    print("DUPLICATE_FOUND: " + str(len(hits)) + " 个同标题 issue 已存在，建议复用而非新建：")
    for i in hits:
        print("  " + str(i.get("identifier")) + " | " + str(i.get("status")) + " | " + str(i.get("title")))
    print("建议: 在已有 issue 上 comment add 或 update，不要 issue-tracker issue create。")
    print("如确需新建重复 issue，显式加 --allow-duplicate 并说明理由。")
    sys.exit(1)
else:
    print("NO_DUPLICATE: 未找到同标题 issue，可安全创建。")
    sys.exit(0)
'
