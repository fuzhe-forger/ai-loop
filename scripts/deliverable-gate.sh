#!/usr/bin/env bash
set -euo pipefail

show_help() {
  cat <<'HELP'
Usage: scripts/deliverable-gate.sh [--input <artifact.md>] [--run-id <run-id>] [--issue <issue-id>] [--strict] [--output <file>]

Check whether a human-facing deliverable is complete enough to hand off, review, or write back.

Required sections or signals:
  - purpose / goal
  - conclusion / summary / result
  - evidence / artifacts / links
  - verification / test result
  - owner / actor / DRI
  - next action / follow-up
  - side-effect / writeback state

When --run-id is provided, the input defaults to runs/<run-id>/stage-report.md, falling back to summary.md.
With --strict, run mode also requires core evidence files: summary.md, stage-report.md, multica-comment.md.

Options:
  --input    Markdown deliverable to check
  --run-id   Optional local run identifier under runs/
  --issue    Optional issue identifier; when present, the deliverable must reference it
  --strict   Require core run evidence when --run-id is used
  --output   Optional markdown report output
  -h, --help Show this help

This script is local-only. It does not read Multica and never performs remote writes.
HELP
}

input_file=""
run_id=""
issue_id=""
strict="false"
output_file=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --input)
      input_file="${2:-}"; shift 2 ;;
    --run-id)
      run_id="${2:-}"; shift 2 ;;
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

if [[ -z "$input_file" && -n "$run_id" ]]; then
  if [[ -s "runs/$run_id/stage-report.md" ]]; then
    input_file="runs/$run_id/stage-report.md"
  else
    input_file="runs/$run_id/summary.md"
  fi
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

  for required_file in summary.md stage-report.md multica-comment.md; do
    if [[ -s "runs/$run_id/$required_file" ]]; then
      add_check "Core evidence ${required_file}" "PASSED" "runs/$run_id/$required_file" "$strict"
    else
      if [[ "$strict" == "true" ]]; then
        add_check "Core evidence ${required_file}" "FAILED" "runs/$run_id/$required_file missing" "true"
      else
        add_check "Core evidence ${required_file}" "WARN" "runs/$run_id/$required_file missing" "false"
      fi
    fi
  done
else
  add_check "Run directory" "SKIPPED" "no --run-id provided" "false"
fi

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
    add_check "Issue reference" "FAILED" "deliverable must mention $issue_id"
  fi
else
  add_check "Issue reference" "SKIPPED" "no --issue provided" "false"
fi

check_pattern "Purpose" "目标|目的|Purpose|Goal|Objective" "purpose/goal"
check_pattern "Conclusion" "结论|核心结论|Summary|Result|Conclusion|Status" "conclusion/summary/result"
check_pattern "Evidence" "证据|Evidence|Artifacts|产物|路径|runs/|docs/|tasks/|memory/|链接|Link" "evidence/artifacts/links"
check_pattern "Verification" "验证|测试|Verification|Test|PASSED|FAILED|通过|失败" "verification/test result"
check_pattern "Owner" "负责人|DRI|Owner|Actor|角色|Assignee|Reviewer|执行者" "owner/actor/DRI"
check_pattern "Next action" "下一步|后续|Next action|Next|Follow-up|Recommended|建议" "next action/follow-up"
check_pattern "Side-effect state" "副作用|回写|远端|外部|Side effect|Writeback|Remote writes|External" "side-effect/writeback state"

score=0
if [[ "$required_total" -gt 0 ]]; then
  score=$((required_passed * 100 / required_total))
fi

result="PASSED"
if [[ "$required_failed" -gt 0 || "$score" -lt 80 ]]; then
  result="FAILED"
fi

notes="Deliverable is ready for handoff/review/writeback decision."
if [[ "$result" != "PASSED" ]]; then
  notes="Deliverable is not ready. Fix failed checks or record an explicit human exception before handoff/writeback."
fi

report="# Deliverable Gate Report

## Result

- Result: ${result}
- Score: ${score}/100
- Input: ${input_file}
- Run ID: ${run_id:-none}
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
  echo "deliverable_gate_report: $output_file"
else
  printf '%s' "$report"
fi

if [[ "$result" != "PASSED" ]]; then
  exit 1
fi
