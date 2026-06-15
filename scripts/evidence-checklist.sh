#!/usr/bin/env bash
set -euo pipefail

show_help() {
  cat <<'HELP'
Usage: scripts/evidence-checklist.sh --run-id <run-id> [--output <file>]

Generate a local evidence checklist for an ai-loop run directory.

Options:
  --run-id   Run directory name under runs/, required
  --output   Optional file path to write the checklist
  -h, --help Show this help

This script is local-only. It does not read Multica and never performs remote writes.
HELP
}

run_id=""
output=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --run-id)
      run_id="${2:-}"; shift 2 ;;
    --output)
      output="${2:-}"; shift 2 ;;
    -h|--help)
      show_help; exit 0 ;;
    *)
      echo "Unknown argument: $1" >&2
      show_help
      exit 2 ;;
  esac
done

if [[ -z "$run_id" ]]; then
  echo "--run-id is required" >&2
  show_help
  exit 2
fi

run_dir="runs/${run_id}"
if [[ ! -d "$run_dir" ]]; then
  echo "Run directory not found: $run_dir" >&2
  exit 1
fi

has_file() {
  local path="$1"
  if [[ -s "$path" ]]; then
    printf 'present'
  else
    printf 'missing'
  fi
}

checklist="$(cat <<REPORT
# Evidence Checklist: ${run_id}

## Core Artifacts

- summary.md: $(has_file "$run_dir/summary.md")
- stage-report.md: $(has_file "$run_dir/stage-report.md")
- multica-comment.md: $(has_file "$run_dir/multica-comment.md")
- writeback-summary.md: $(has_file "$run_dir/writeback-summary.md")

## Review Questions

- Is the task goal clear?
- Are local deliverables listed?
- Was verification executed or explicitly skipped with a reason?
- Are remote side effects recorded as none, pending approval, or completed?
- Is the next action clear?

## Local Paths

- Run directory: ${run_dir}
- Summary: ${run_dir}/summary.md
- Stage report: ${run_dir}/stage-report.md
- Comment draft: ${run_dir}/multica-comment.md
REPORT
)"

if [[ -n "$output" ]]; then
  mkdir -p "$(dirname "$output")"
  printf '%s\n' "$checklist" > "$output"
  echo "checklist: $output"
else
  printf '%s\n' "$checklist"
fi
