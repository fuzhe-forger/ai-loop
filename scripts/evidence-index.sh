#!/usr/bin/env bash
set -euo pipefail

show_help() {
  cat <<'HELP'
Usage: scripts/evidence-index.sh --pattern <glob> [--output <file>]

Generate a local Markdown index for multiple run evidence directories.

Options:
  --pattern  Glob pattern under runs/, for example 'FUZ-554*', required
  --output   Optional file path to write the index
  -h, --help Show this help

This script is local-only. It reads runs/ and never performs remote writes.
HELP
}

pattern=""
output=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --pattern)
      pattern="${2:-}"; shift 2 ;;
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

if [[ -z "$pattern" ]]; then
  echo "--pattern is required" >&2
  show_help
  exit 2
fi

shopt -s nullglob
run_dirs=(runs/$pattern)
shopt -u nullglob

if [[ ${#run_dirs[@]} -eq 0 ]]; then
  echo "No run directories matched: runs/$pattern" >&2
  exit 1
fi

has_file() {
  local path="$1"
  if [[ -s "$path" ]]; then
    printf 'yes'
  else
    printf 'no'
  fi
}

generated_at="$(date -u '+%Y-%m-%dT%H:%M:%SZ')"

index="# Evidence Index: runs/${pattern}

## Metadata

- Generated at: ${generated_at}
- Pattern: runs/${pattern}
- Ordering: shell glob expansion order under runs/ with nullglob enabled

## Runs

| Run | Summary | Stage Report | Comment Draft | Writeback |
|---|---|---|---|---|
"

for run_dir in "${run_dirs[@]}"; do
  if [[ ! -d "$run_dir" ]]; then
    continue
  fi
  run_id="$(basename "$run_dir")"
  index+="| ${run_id} | $(has_file "$run_dir/summary.md") | $(has_file "$run_dir/stage-report.md") | $(has_file "$run_dir/multica-comment.md") | $(has_file "$run_dir/writeback-summary.md") |
"
done

index+="
## Review Notes

- Prefer runs with summary and stage report for formal review.
- A missing writeback summary is acceptable when no remote write was requested.
- Remote side effects must be confirmed from stage report or writeback summary.
"

if [[ -n "$output" ]]; then
  mkdir -p "$(dirname "$output")"
  printf '%s' "$index" > "$output"
  echo "index: $output"
else
  printf '%s' "$index"
fi
