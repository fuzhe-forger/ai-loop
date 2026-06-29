#!/usr/bin/env bash
set -euo pipefail

show_help() {
  cat <<'HELP'
Usage: scripts/design-gate.sh --input <design.md> [--issue <issue-id>] [--strict] [--output <file>]

Check whether a design document is ready for review before execution.

Required sections or signals:
  - background / context / problem
  - goal / objective
  - scope / boundary / non-goal
  - solution / design / architecture
  - dependency / impact / integration
  - risk / fallback / rollback
  - acceptance / verification / test
  - open questions / decisions
  - owner / DRI / reviewer
  - side-effect / writeback policy

Options:
  --input    Design markdown file, required
  --issue    Optional issue identifier; when present, the document must reference it
  --strict   Also require explicit evidence/source basis
  --output   Optional markdown report output
  -h, --help Show this help

This script is local-only. It does not read Multica and never performs remote writes.
HELP
}

input_file=""
issue_id=""
strict="false"
output_file=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --input)
      input_file="${2:-}"; shift 2 ;;
    --issue)
      issue_id="${2:-}"; shift 2 ;;
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

if [[ -z "$input_file" ]]; then
  echo "--input is required" >&2
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

if [[ -f "$input_file" && -s "$input_file" ]]; then
  add_check "Input file" "PASSED" "$input_file"
else
  add_check "Input file" "FAILED" "$input_file missing or empty"
fi

if [[ -n "$issue_id" ]]; then
  if [[ "$issue_id" =~ ^[A-Z]+-[0-9]+$ ]]; then
    add_check "Issue ID format" "PASSED" "$issue_id"
  else
    add_check "Issue ID format" "FAILED" "expected format like FUZ-554"
  fi

  if [[ -f "$input_file" ]] && rg -q --fixed-strings "$issue_id" "$input_file"; then
    add_check "Issue reference" "PASSED" "$issue_id"
  else
    add_check "Issue reference" "FAILED" "document must mention $issue_id"
  fi
else
  add_check "Issue reference" "SKIPPED" "no --issue provided" "false"
fi

check_pattern "Background" "背景|上下文|现状|问题|Background|Context|Problem" "background/context/problem"
check_pattern "Goal" "目标|目的|Objective|Goal|Purpose" "goal/objective"
check_pattern "Scope boundary" "非目标|不做|范围|边界|Scope|Boundary|Non-goal|Out of scope" "scope/boundary/non-goal"
check_pattern "Solution design" "方案|设计|架构|Solution|Design|Architecture" "solution/design/architecture"
check_pattern "Dependencies impact" "依赖|影响|集成|Dependency|Impact|Integration" "dependency/impact/integration"
check_pattern "Risk fallback" "风险|回滚|降级|兜底|Risk|Fallback|Rollback" "risk/fallback/rollback"
check_pattern "Acceptance verification" "验收|验证|测试|Acceptance|Verification|Test" "acceptance/verification/test"
check_pattern "Open decisions" "待决策|开放问题|决策|Decision|Open question|TODO|待确认" "open questions/decisions"
check_pattern "Owner reviewer" "负责人|DRI|Owner|Reviewer|评审|Assignee" "owner/DRI/reviewer"
check_pattern "Side-effect policy" "副作用|回写|远端|外部|Side effect|Writeback|Remote|External" "side-effect/writeback policy"

if [[ "$strict" == "true" ]]; then
  check_pattern "Evidence basis" "证据|Evidence|来源|Source|依据|参考|Reference" "evidence/source basis" "true"
fi

score=0
if [[ "$required_total" -gt 0 ]]; then
  score=$((required_passed * 100 / required_total))
fi

result="PASSED"
if [[ "$required_failed" -gt 0 || "$score" -lt 80 ]]; then
  result="FAILED"
fi

notes="Design is ready for review."
if [[ "$result" != "PASSED" ]]; then
  notes="Design is not ready. Fix failed checks or record an explicit human exception before execution."
fi

report="# Design Gate Report

## Result

- Result: ${result}
- Score: ${score}/100
- Input: ${input_file}
- Issue: ${issue_id:-none}
- Strict: ${strict}
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
  echo "design_gate_report: $output_file"
else
  printf '%s' "$report"
fi

if [[ "$result" != "PASSED" ]]; then
  exit 1
fi
