#!/usr/bin/env bash
set -euo pipefail

show_help() {
  cat <<'HELP'
Usage: scripts/verify-toolchain.sh [--case <case-id>] [--pattern <glob>] [--strict] [--output <file>]

Run local-only smoke checks for the Multica × ai-loop helper scripts.

Options:
  --case     Case identifier, default: FUZ-554
  --pattern  Run glob pattern under runs/, default: '<case>*'
  --strict   Require every matched run to include core evidence files
  --output   Optional file path to write the verification report
  --list-checks
             List the local smoke checks and exit without reading runs/
  -h, --help Show this help

This script is local-only. It does not read Multica and never performs remote writes.
HELP
}

show_checks() {
  cat <<'HELP'
# Toolchain Smoke Checks

- bash -n scripts/verify-toolchain.sh
- bash -n scripts/multica-loop.sh
- bash -n scripts/evidence-checklist.sh
- bash -n scripts/evidence-index.sh
- bash -n scripts/patch-summary.sh
- bash -n scripts/review-packet.sh
- bash -n scripts/collect-evidence.sh
- ./scripts/multica-loop.sh --policy-help
- ./scripts/collect-evidence.sh --issue <case-id> --run-id <sample-run>
- ./scripts/patch-summary.sh --help
- ./scripts/evidence-checklist.sh --run-id <sample-run>
- ./scripts/evidence-index.sh --pattern <pattern>
- ./scripts/review-packet.sh --case <case-id> --pattern <pattern>
- ./scripts/verify-toolchain.sh --case <case-id> --pattern <pattern> --strict

This list is local-only. It does not read Multica and never performs remote writes.
HELP
}

case_id="FUZ-554"
pattern=""
output=""
list_checks="false"
strict="false"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --case)
      case_id="${2:-}"; shift 2 ;;
    --pattern)
      pattern="${2:-}"; shift 2 ;;
    --output)
      output="${2:-}"; shift 2 ;;
    --strict)
      strict="true"; shift ;;
    --list-checks)
      list_checks="true"; shift ;;
    -h|--help)
      show_help; exit 0 ;;
    *)
      echo "Unknown argument: $1" >&2
      show_help
      exit 2 ;;
  esac
done

if [[ -z "$pattern" ]]; then
  pattern="${case_id}*"
fi

if [[ "$list_checks" == "true" ]]; then
  show_checks
  exit 0
fi

first_run=""
shopt -s nullglob
run_dirs=(runs/$pattern)
shopt -u nullglob
if [[ ${#run_dirs[@]} -gt 0 ]]; then
  first_run="$(basename "${run_dirs[0]}")"
fi

if [[ -z "$first_run" ]]; then
  echo "No run directories matched: runs/$pattern" >&2
  exit 1
fi

checks=()
run_check() {
  local name="$1"
  shift
  if "$@" >/tmp/verify-toolchain.out 2>/tmp/verify-toolchain.err; then
    checks+=("| ${name} | PASSED | |")
  else
    local error
    error="$(tr '\n' ' ' </tmp/verify-toolchain.err | sed 's/|/-/g')"
    checks+=("| ${name} | FAILED | ${error} |")
    return 1
  fi
}

run_check "bash -n scripts/verify-toolchain.sh" bash -n scripts/verify-toolchain.sh
run_check "bash -n scripts/multica-loop.sh" bash -n scripts/multica-loop.sh
run_check "bash -n scripts/evidence-checklist.sh" bash -n scripts/evidence-checklist.sh
run_check "bash -n scripts/evidence-index.sh" bash -n scripts/evidence-index.sh
run_check "bash -n scripts/patch-summary.sh" bash -n scripts/patch-summary.sh
run_check "bash -n scripts/review-packet.sh" bash -n scripts/review-packet.sh
run_check "bash -n scripts/collect-evidence.sh" bash -n scripts/collect-evidence.sh
run_check "multica-loop --policy-help" ./scripts/multica-loop.sh --policy-help
run_check "collect-evidence" ./scripts/collect-evidence.sh --issue "$case_id" --run-id "$first_run"
run_check "patch-summary --help" ./scripts/patch-summary.sh --help
run_check "evidence-checklist" ./scripts/evidence-checklist.sh --run-id "$first_run"
run_check "evidence-index" ./scripts/evidence-index.sh --pattern "$pattern"
run_check "review-packet" ./scripts/review-packet.sh --case "$case_id" --pattern "$pattern"

strict_rows=""
strict_fail_count=0
if [[ "$strict" == "true" ]]; then
  for run_dir in "${run_dirs[@]}"; do
    if [[ ! -d "$run_dir" ]]; then
      continue
    fi
    run_id="$(basename "$run_dir")"
    missing=()
    for required_file in summary.md stage-report.md multica-comment.md; do
      if [[ ! -s "$run_dir/$required_file" ]]; then
        missing+=("$required_file")
      fi
    done
    if [[ ${#missing[@]} -eq 0 ]]; then
      strict_rows+="| ${run_id} | PASSED | |"
    else
      strict_fail_count=$((strict_fail_count + 1))
      missing_text="$(IFS=,; printf '%s' "${missing[*]}")"
      strict_rows+="| ${run_id} | FAILED | ${missing_text} |"
    fi
    strict_rows+=$'\n'
  done
fi

report="# Toolchain Verification: ${case_id}

## Scope

- Case: ${case_id}
- Pattern: runs/${pattern}
- Sample run: ${first_run}
- Strict evidence gate: ${strict}
- Network access: false
- Remote writes: false

## Checks

| Check | Result | Error |
|---|---|---|
"

for row in "${checks[@]}"; do
  report+="${row}
"
done

if [[ "$strict" == "true" ]]; then
  report+="
## Strict Evidence Gate

| Run | Result | Missing Core Evidence |
|---|---|---|
${strict_rows}"
fi

conclusion="Local helper toolchain smoke checks passed."
if [[ "$strict" == "true" && "$strict_fail_count" -gt 0 ]]; then
  conclusion="Local helper toolchain smoke checks passed, but strict evidence gate failed for ${strict_fail_count} run(s)."
elif [[ "$strict" == "true" ]]; then
  conclusion="Local helper toolchain smoke checks and strict evidence gate passed."
fi

report+="
## Conclusion

${conclusion}
"

if [[ -n "$output" ]]; then
  mkdir -p "$(dirname "$output")"
  printf '%s' "$report" > "$output"
  echo "verification_report: $output"
else
  printf '%s' "$report"
fi

if [[ "$strict" == "true" && "$strict_fail_count" -gt 0 ]]; then
  exit 1
fi
