#!/usr/bin/env bash
set -euo pipefail

show_help() {
  cat <<'HELP'
Usage: scripts/classify-task.sh --issue <issue> [options]

Classify task type, risk, tier, and clarification need using deterministic heuristics or AI fallback.

Options:
  --issue <issue>     Issue identifier, required
  --input <file>      Issue JSON file with title/description/labels
  --output <file>     Write classification JSON to file
  --ai-model <model>  AI model: llama3 | gpt-4 | none (default: none)
  --ai-endpoint <url> AI endpoint URL (default: http://localhost:11434/api/generate)
  -h, --help          Show this help
HELP
}

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
issue_id=""
input_file=""
output_file=""
ai_model="none"
ai_endpoint="http://localhost:11434/api/generate"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --issue) issue_id="${2:-}"; shift 2 ;;
    --input) input_file="${2:-}"; shift 2 ;;
    --output) output_file="${2:-}"; shift 2 ;;
    --ai-model) ai_model="${2:-}"; shift 2 ;;
    --ai-endpoint) ai_endpoint="${2:-}"; shift 2 ;;
    -h|--help) show_help; exit 0 ;;
    *) echo "Unknown argument: $1" >&2; show_help; exit 2 ;;
  esac
done

if [[ -z "$issue_id" ]]; then
  echo "--issue is required" >&2
  show_help
  exit 2
fi

json_report="$(python3 - "$issue_id" "$input_file" "$ai_model" <<'PY'
import datetime as dt
import json
import re
import sys
from pathlib import Path

issue_id, input_file, ai_model = sys.argv[1:]
source = {"title": issue_id, "description": "", "labels": []}
if input_file and Path(input_file).is_file():
    raw = json.loads(Path(input_file).read_text(encoding="utf-8"))
    labels = []
    for item in raw.get("labels") or []:
        labels.append(str(item.get("name") or item.get("label") or item.get("title") if isinstance(item, dict) else item))
    source = {
        "title": str(raw.get("title") or issue_id),
        "description": str(raw.get("description") or raw.get("content") or ""),
        "labels": labels,
    }
text = " ".join([source["title"], source["description"], " ".join(source["labels"])]).lower()

rules = []
def hit(name, pattern):
    matched = re.search(pattern, text, re.I) is not None
    if matched:
        rules.append(name)
    return matched

remote = hit("remote_side_effect", r"feishu|飞书|multica|写回|comment|status|metadata|git remote|push|deploy|部署|安装|install|codex config")
writeback = hit("writeback", r"写回|comment|status|metadata|feishu|飞书|multica")
script = hit("local_script", r"script|脚本|toolchain|preflight|evidence|verify|校准|门禁|司南|loop")
doc = hit("documentation", r"doc|文档|报告|分享|模板|demo|演示|复盘|方案")
bug = hit("bug", r"bug|fix|修复|失败|报错|error|exception")
feature = hit("feature", r"feature|需求|接口|新增|实现|能力|automation|自动")
ambiguous = hit("ambiguous", r"^\s*(执行|继续|推进|走|做|推|\?+|司南健身)\s*$") or len(text.strip()) < 8

if writeback:
    task_type = "writeback"
elif doc and not any(marker in text for marker in ["verify", "toolchain", "preflight", "evidence", "校准", "门禁"]):
    task_type = "documentation"
elif script:
    task_type = "local_script_patch"
elif doc:
    task_type = "documentation"
elif bug:
    task_type = "bug_fix"
elif feature:
    task_type = "feature"
else:
    task_type = "unknown"

if remote:
    risk = "high"
elif ambiguous:
    risk = "medium"
elif task_type in {"local_script_patch", "feature"}:
    risk = "medium"
else:
    risk = "low"

if ambiguous:
    tier = "L0"
elif remote:
    tier = "L3"
elif task_type in {"local_script_patch", "feature"}:
    tier = "L2"
elif task_type == "documentation":
    tier = "L1"
else:
    tier = "L1"

needs_clarification = ambiguous or task_type == "unknown"
confidence = 0.85 if rules else 0.35
if needs_clarification:
    confidence = min(confidence, 0.55)

report = {
    "schema_version": 1,
    "issue": issue_id,
    "task_type": task_type,
    "risk": risk,
    "risk_level": risk,
    "tier": tier,
    "needs_clarification": needs_clarification,
    "requires_clarification": needs_clarification,
    "estimated_complexity": "high" if tier == "L3" else ("medium" if tier == "L2" else "low"),
    "confidence": confidence,
    "reasoning": "matched rules: " + (", ".join(rules) if rules else "none"),
    "classification_method": "heuristic" if ai_model == "none" else f"heuristic_fallback:{ai_model}",
    "automation_boundary": {
        "auto_execute": False,
        "auto_writeback_decision": False,
        "auto_reviewer": False,
    },
    "timestamp": dt.datetime.now(dt.timezone.utc).replace(microsecond=0).isoformat().replace("+00:00", "Z"),
}
print(json.dumps(report, ensure_ascii=False, indent=2))
PY
)"

if [[ -n "$output_file" ]]; then
  mkdir -p "$(dirname "$output_file")"
  printf '%s\n' "$json_report" > "$output_file"
  echo "classification: $output_file"
fi
printf '%s\n' "$json_report"
