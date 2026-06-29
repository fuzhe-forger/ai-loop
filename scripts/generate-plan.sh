#!/usr/bin/env bash
set -euo pipefail

show_help() {
  cat <<'HELP'
Usage: scripts/generate-plan.sh --issue <issue> [options]

Generate a local execution-plan draft. It does not execute the plan.

Options:
  --issue <issue>       Issue identifier, required
  --input <file>        Issue JSON file with title/description/labels
  --output <file>       Write Markdown plan draft to file
  --json-output <file>  Write structured JSON plan draft to file
  --memory-dir <dir>    Memory directory (default: memory/)
  --ai-model <model>    AI model: llama3 | gpt-4 | none (default: none)
  -h, --help            Show this help
HELP
}

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
issue_id=""
input_file=""
output_file=""
json_output_file=""
memory_dir="$ROOT_DIR/memory"
ai_model="none"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --issue) issue_id="${2:-}"; shift 2 ;;
    --input) input_file="${2:-}"; shift 2 ;;
    --output) output_file="${2:-}"; shift 2 ;;
    --json-output) json_output_file="${2:-}"; shift 2 ;;
    --memory-dir) memory_dir="${2:-}"; shift 2 ;;
    --ai-model) ai_model="${2:-}"; shift 2 ;;
    -h|--help) show_help; exit 0 ;;
    *) echo "Unknown argument: $1" >&2; show_help; exit 2 ;;
  esac
done

if [[ -z "$issue_id" ]]; then
  echo "--issue is required" >&2
  show_help
  exit 2
fi

classification_file="$(mktemp)"
recommendation_file="$(mktemp)"
trap 'rm -f "$classification_file" "$recommendation_file"' EXIT
./scripts/classify-task.sh --issue "$issue_id" ${input_file:+--input "$input_file"} --output "$classification_file" >/tmp/generate-plan-classify.out
query_text="$issue_id"
if [[ -n "$input_file" && -f "$input_file" ]]; then
  query_text="$(python3 - "$input_file" <<'PY'
import json
import sys
with open(sys.argv[1], encoding='utf-8') as fh:
    data = json.load(fh)
print((data.get('title') or '') + '\n' + (data.get('description') or data.get('content') or ''))
PY
)"
fi
./scripts/recommend-memory.sh --query "$query_text" --memory-dir "$memory_dir" --output "$recommendation_file" --limit 5 >/tmp/generate-plan-memory.out

json_report="$(python3 - "$issue_id" "$input_file" "$classification_file" "$recommendation_file" "$ai_model" <<'PY'
import datetime as dt
import json
import sys
from pathlib import Path

issue, input_file, classification_file, recommendation_file, ai_model = sys.argv[1:]
source = {"title": issue, "description": ""}
if input_file and Path(input_file).is_file():
    raw = json.loads(Path(input_file).read_text(encoding="utf-8"))
    source = {"title": raw.get("title") or issue, "description": raw.get("description") or raw.get("content") or ""}
classification = json.loads(Path(classification_file).read_text(encoding="utf-8"))
recommendations = json.loads(Path(recommendation_file).read_text(encoding="utf-8"))
task_type = classification["task_type"]
risk = classification["risk"]
policy_path = Path("config/gate-policy.json")
policy = json.loads(policy_path.read_text(encoding="utf-8")) if policy_path.is_file() else {}
task_policy = policy.get("task_types", {}).get(task_type) or policy.get("task_types", {}).get(policy.get("default_task_type", "unknown"), {})
required_gates = task_policy.get("required_gates", ["requirement", "design", "deliverable"])
optional_gates = task_policy.get("optional_gates", [])
minimum_scores = task_policy.get("minimum_scores", {})
steps = [
    {"id": "plan-1", "title": "确认目标和边界", "acceptance": "目标、非目标、验收标准明确", "verification": "loop-execution-preflight 输出 PASSED"},
    {"id": "plan-2", "title": "本地实现或文档变更", "acceptance": "只修改计划范围内文件", "verification": "patch-summary 或 git diff 复核"},
    {"id": "plan-3", "title": "运行针对性验证", "acceptance": "关键脚本/测试通过", "verification": "verify-toolchain 或任务专属验证命令"},
    {"id": "plan-4", "title": "收集 evidence 并复核", "acceptance": "evidence-summary/review-packet 完整", "verification": "collect-evidence + review-packet"},
]
if task_type == "writeback":
    steps.append({"id": "plan-5", "title": "走受控写回审批", "acceptance": "approval boundary 通过且 readback 留痕", "verification": "writeback-gate allowed=true；readback artifact 存在"})
side_effects = ["local_files", "local_verification"]
if task_type == "writeback" or risk == "high":
    side_effects.append("remote_write_requires_approval")
report = {
    "schema_version": 1,
    "issue": issue,
    "title": source["title"],
    "task_type": task_type,
    "risk": risk,
    "tier": classification["tier"],
    "needs_clarification": classification["needs_clarification"],
    "classification": classification,
    "steps": steps,
    "acceptance": [step["acceptance"] for step in steps],
    "verification_commands": [
        "./scripts/loop-execution-preflight.sh --issue <issue> --task <task.md> --repo . --run-id <run-id>",
        "./scripts/verify-toolchain.sh --case <issue> --pattern <run-id> --strict --state-gate",
        "./scripts/collect-evidence.sh --issue <issue> --run-id <run-id>",
    ],
    "side_effects_draft": side_effects,
    "gate_plan": {
        "policy_file": str(policy_path),
        "task_type": task_type,
        "required_gates": required_gates,
        "optional_gates": optional_gates,
        "minimum_scores": minimum_scores,
        "commands": [
            "./scripts/requirement-gate.sh --input <task-or-requirement.md> --issue <issue> --output runs/<run-id>/requirement-gate.md --clarification-output runs/<run-id>/clarification.md",
            "./scripts/design-gate.sh --input <design.md> --issue <issue> --output runs/<run-id>/design-gate.md",
            "./scripts/deliverable-gate.sh --run-id <run-id> --issue <issue> --strict --output runs/<run-id>/deliverable-gate.md",
            "./scripts/gate-policy-check.sh --run-id <run-id> --task-type <task-type> --output runs/<run-id>/gate-policy-check.md --json-output runs/<run-id>/gate-policy-check.json",
        ],
    },
    "memory_recommendations": recommendations.get("recommendations") or [],
    "automation_boundary": {
        "auto_execute": False,
        "auto_writeback_decision": False,
        "auto_reviewer": False,
        "human_review_required": True,
    },
    "generation_method": "deterministic_template" if ai_model == "none" else f"deterministic_template_fallback:{ai_model}",
    "generated_at": dt.datetime.now(dt.timezone.utc).replace(microsecond=0).isoformat().replace("+00:00", "Z"),
}
print(json.dumps(report, ensure_ascii=False, indent=2))
PY
)"

markdown_report="$(python3 - "$json_report" <<'PY'
import json
import sys
report = json.loads(sys.argv[1])
steps = "\n".join(f"{idx}. {step['title']}\n   - 验收：{step['acceptance']}\n   - 验证：{step['verification']}" for idx, step in enumerate(report['steps'], 1))
commands = "\n".join(f"- `{cmd}`" for cmd in report['verification_commands'])
side_effects = "\n".join(f"- {item}" for item in report['side_effects_draft'])
gate_plan = report.get('gate_plan') or {}
required_gates = ", ".join(gate_plan.get('required_gates') or []) or "none"
optional_gates = ", ".join(gate_plan.get('optional_gates') or []) or "none"
minimum_scores = ", ".join(f"{k}:{v}" for k, v in (gate_plan.get('minimum_scores') or {}).items()) or "none"
gate_commands = "\n".join(f"- `{cmd}`" for cmd in gate_plan.get('commands') or [])
memories = "\n".join(f"- {item.get('id')}：{item.get('reason')} ({item.get('path')})" for item in report['memory_recommendations']) or "- none"
print(f"""# {report['issue']} 执行计划草稿

## Summary

- Title: {report['title']}
- Task type: {report['task_type']}
- Risk: {report['risk']}
- Tier: {report['tier']}
- Needs clarification: {str(report['needs_clarification']).lower()}
- Human review required: true

## Steps

{steps}

## Verification Commands

{commands}

## Gate Plan

- Policy file: `{gate_plan.get('policy_file', 'config/gate-policy.json')}`
- Required gates: {required_gates}
- Optional gates: {optional_gates}
- Minimum scores: {minimum_scores}

{gate_commands}

## Side Effects Draft

{side_effects}

## Memory Recommendations

{memories}

## Automation Boundary

- 不自动执行计划。
- 不自动做 reviewer 结论。
- 不自动做远端写回决策。
""")
PY
)"

if [[ -n "$json_output_file" ]]; then
  mkdir -p "$(dirname "$json_output_file")"
  printf '%s\n' "$json_report" > "$json_output_file"
  echo "plan_json: $json_output_file"
fi
if [[ -n "$output_file" ]]; then
  mkdir -p "$(dirname "$output_file")"
  printf '%s\n' "$markdown_report" > "$output_file"
  echo "plan_draft: $output_file"
fi
if [[ -z "$output_file" && -z "$json_output_file" ]]; then
  printf '%s\n' "$markdown_report"
fi
