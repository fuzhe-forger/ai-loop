#!/usr/bin/env bash
set -euo pipefail

show_help() {
  cat <<'HELP'
Usage: scripts/karpathy-gate.sh --input <task-or-plan.md> [--output <file>]

Check that a coding task follows the local Karpathy/Greykey discipline:
assumptions, scope, surgical-change boundary, and verification.

This script is local-only. It never performs network access or remote writes.
HELP
}

input_file=""
output_file=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --input)
      input_file="${2:-}"; shift 2 ;;
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

add_check() {
  local name="$1"
  local status="$2"
  local detail="$3"
  rows+="| ${name} | ${status} | ${detail} |"$'\n'
  required_total=$((required_total + 1))
  if [[ "$status" == "PASSED" ]]; then
    required_passed=$((required_passed + 1))
  else
    required_failed=$((required_failed + 1))
  fi
}

check_pattern() {
  local name="$1"
  local pattern="$2"
  local detail="$3"
  if [[ -f "$input_file" ]] && rg -qi -- "$pattern" "$input_file"; then
    add_check "$name" "PASSED" "$detail"
  else
    add_check "$name" "FAILED" "missing ${detail}"
  fi
}

if [[ -f "$input_file" && -s "$input_file" ]]; then
  add_check "Input file" "PASSED" "$input_file"
else
  add_check "Input file" "FAILED" "$input_file missing or empty"
fi

check_pattern "Assumptions surfaced" "假设|Assumption|Assumptions" "explicit assumptions or no-assumption statement"
check_pattern "Scope boundary" "范围|边界|非目标|不做|Scope|Boundary|Non-goal|Out of scope" "scope and non-goals"
check_pattern "Surgical change" "最小|精确|只改|diff|surgical|focused|smallest|changed line" "small/surgical-change constraint"
check_pattern "Verification" "验收|验证|测试|Verification|Test|Acceptance|check" "verification command or acceptance check"

score=0
if [[ "$required_total" -gt 0 ]]; then
  score=$((required_passed * 100 / required_total))
fi

result="PASSED"
if [[ "$required_failed" -gt 0 ]]; then
  result="FAILED"
fi

report="# Karpathy Gate Report

## Result

- Result: ${result}
- Score: ${score}/100
- Input: ${input_file}
- Required checks: ${required_passed}/${required_total}
- Remote writes: false

## Four Questions

1. What assumptions are explicit?
2. What is the smallest safe scope?
3. Can every changed line trace to the goal?
4. What command or artifact verifies success?

## Checks

| Check | Result | Detail |
|---|---|---|
${rows}
"

if [[ -n "$output_file" ]]; then
  mkdir -p "$(dirname "$output_file")"
  printf '%s' "$report" > "$output_file"
  echo "karpathy_gate_report: $output_file"
else
  printf '%s' "$report"
fi

if [[ "$result" != "PASSED" ]]; then
  exit 1
fi
