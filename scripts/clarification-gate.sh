#!/usr/bin/env bash
set -euo pipefail

show_help() {
  cat <<'HELP'
Usage: scripts/clarification-gate.sh [--input <clarification.md>] [--run-id <run-id>] [--strict] [--output <file>]

Check whether a clarification draft is actionable enough for human confirmation.

Required sections or signals:
  - summary / source / gate result / next state
  - why this is needed
  - questions for human confirmation
  - at least 5 concrete questions
  - suggested requirement skeleton
  - next step
  - side-effect / remote write visibility

When --run-id is provided, the input defaults to runs/<run-id>/clarification.md.

Options:
  --input    Clarification markdown file
  --run-id   Optional local run identifier under runs/
  --strict   Also require all 10 standard requirement skeleton sections
  --output   Optional markdown report output
  -h, --help Show this help

This script is local-only. It does not read Multica and never performs remote writes.
HELP
}

input_file=""
run_id=""
strict="false"
output_file=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --input)
      input_file="${2:-}"; shift 2 ;;
    --run-id)
      run_id="${2:-}"; shift 2 ;;
    --strict)
      strict="true"; shift ;;
    --output)
      output_file="${2:-}"; shift 2 ;;
    -h|--help)
      show_help; exit 0 ;;
    *)
      echo "Unknown argument: $1" >&2
      show_help
      exit 2 ;;
  esac
done

if [[ -z "$input_file" && -n "$run_id" ]]; then
  input_file="runs/$run_id/clarification.md"
fi

if [[ -z "$input_file" ]]; then
  echo "--input or --run-id is required" >&2
  show_help
  exit 2
fi

rows=""
required_total=0
required_passed=0
required_failed=0
warning_count=0

add_check() {
  local name="$1"
  local status="$2"
  local detail="$3"
  local required="${4:-true}"
  rows+="| ${name} | ${status} | ${detail} |"$'\n'
  if [[ "$required" == "true" && "$status" != "SKIPPED" ]]; then
    required_total=$((required_total + 1))
  fi
  if [[ "$required" == "true" && "$status" == "PASSED" ]]; then
    required_passed=$((required_passed + 1))
  elif [[ "$required" == "true" && "$status" == "FAILED" ]]; then
    required_failed=$((required_failed + 1))
  elif [[ "$status" == "WARN" ]]; then
    warning_count=$((warning_count + 1))
  fi
}

check_pattern() {
  local name="$1"
  local pattern="$2"
  local detail="$3"
  local required="${4:-true}"
  if [[ -f "$input_file" ]] && rg -qi -- "$pattern" "$input_file"; then
    add_check "$name" "PASSED" "$detail" "$required"
  else
    if [[ "$required" == "true" ]]; then
      add_check "$name" "FAILED" "missing ${detail}" "$required"
    else
      add_check "$name" "WARN" "missing ${detail}" "$required"
    fi
  fi
}

if [[ -n "$run_id" ]]; then
  if [[ -d "runs/$run_id" ]]; then
    add_check "Run directory" "PASSED" "runs/$run_id"
  else
    add_check "Run directory" "FAILED" "runs/$run_id missing"
  fi
else
  add_check "Run directory" "SKIPPED" "no --run-id provided" "false"
fi

if [[ -f "$input_file" && -s "$input_file" ]]; then
  add_check "Input file" "PASSED" "$input_file"
else
  add_check "Input file" "FAILED" "$input_file missing or empty"
fi

check_pattern "Summary" "Summary|摘要|Source requirement|Gate result|Next state|来源|状态" "summary/source/gate result/next state"
check_pattern "Why needed" "Why This Is Needed|为什么|原因|not clear enough|需求不清" "why this is needed"
check_pattern "Human questions section" "Questions For Human Confirmation|澄清问题|人工确认|Human Confirmation|Questions" "questions for human confirmation"
check_pattern "Requirement skeleton" "Suggested Requirement Skeleton|需求骨架|背景 / 问题|验收 / 成功标准" "suggested requirement skeleton"
check_pattern "Next step" "Next Step|下一步|rerun|重新运行|补充确认" "next step"
check_pattern "Side-effect visibility" "副作用|远端|外部写入|Remote writes|Network access|Side effect|Writeback" "side-effect/remote write visibility"

question_count=0
if [[ -f "$input_file" ]]; then
  question_count="$(python3 - <<'PY' "$input_file"
import re
import sys
from pathlib import Path

text = Path(sys.argv[1]).read_text(encoding="utf-8", errors="replace")
count = 0
for line in text.splitlines():
    stripped = line.strip()
    if stripped.startswith("- ") and ("？" in stripped or "?" in stripped):
        count += 1
print(count)
PY
)"
fi

if [[ "$question_count" -ge 5 ]]; then
  add_check "Concrete questions" "PASSED" "${question_count} question(s)"
else
  add_check "Concrete questions" "FAILED" "need at least 5 concrete questions, found ${question_count}"
fi

if [[ "$strict" == "true" ]]; then
  for section in \
    "背景 / 问题" \
    "用户 / 干系人 / 场景" \
    "目标 / 期望结果" \
    "范围 / 非目标 / 边界" \
    "验收 / 成功标准" \
    "约束 / 假设" \
    "依赖 / 输入 / 上下游" \
    "风险 / 待确认问题" \
    "优先级 / 时间要求" \
    "副作用 / 外部写入策略"; do
    check_pattern "Skeleton section ${section}" "$section" "$section" "true"
  done
fi

score=0
if [[ "$required_total" -gt 0 ]]; then
  score=$((required_passed * 100 / required_total))
fi

result="PASSED"
if [[ "$required_failed" -gt 0 || "$score" -lt 80 ]]; then
  result="FAILED"
fi

notes="Clarification draft is actionable for human confirmation."
if [[ "$result" != "PASSED" ]]; then
  notes="Clarification draft is not actionable enough. Add missing questions/sections before handoff."
fi

report="# Clarification Gate Report

## Result

- Result: ${result}
- Score: ${score}/100
- Input: ${input_file}
- Run ID: ${run_id:-none}
- Strict: ${strict}
- Question count: ${question_count}
- Required checks: ${required_passed}/${required_total}
- Required failures: ${required_failed}
- Warnings: ${warning_count}
- Network access: false
- Remote writes: false

## Checks

| Check | Result | Detail |
|---|---|---|
${rows}
## Notes

${notes}
"

if [[ -n "$output_file" ]]; then
  mkdir -p "$(dirname "$output_file")"
  printf '%s' "$report" > "$output_file"
  echo "clarification_gate_report: $output_file"
else
  printf '%s' "$report"
fi

if [[ "$result" != "PASSED" ]]; then
  exit 1
fi
