#!/usr/bin/env bash
set -euo pipefail

show_help() {
  cat <<'HELP'
Usage: scripts/refresh-run-evidence.sh --pattern <glob> [--issue <issue-id>] [--output <file>]

Refresh local state evaluation and metadata draft artifacts for matching run directories.

Options:
  --pattern  Glob pattern under runs/, for example 'FUZ-554*', required
  --issue    Optional issue identifier, for example FUZ-554
  --output   Optional Markdown report path
  -h, --help Show this help

This script is local-only. It writes only under matching runs/ directories and never writes Multica.
HELP
}

pattern=""
issue=""
output=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --pattern)
      pattern="${2:-}"; shift 2 ;;
    --issue)
      issue="${2:-}"; shift 2 ;;
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

generated_at="$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
rows="| Run | State | Metadata | Suggested State | Remote Write Done |
|---|---|---|---|---|
"
refreshed_count=0

for run_dir in "${run_dirs[@]}"; do
  if [[ ! -d "$run_dir" ]]; then
    continue
  fi
  run_id="$(basename "$run_dir")"
  run_issue="$issue"
  if [[ -z "$run_issue" ]]; then
    run_issue="$(printf '%s\n' "$run_id" | grep -Eo '^[A-Z]+-[0-9]+' || true)"
    if [[ ! "$run_issue" =~ ^[A-Z]+-[0-9]+$ ]]; then
      run_issue="unknown"
    fi
  fi

  ./scripts/evaluate-state.sh --issue "$run_issue" --run-id "$run_id" --write-run >/dev/null
  ./scripts/metadata-draft.sh \
    --issue "$run_issue" \
    --run-id "$run_id" \
    --output "$run_dir/metadata-draft.json" \
    --markdown "$run_dir/metadata-draft.md" >/dev/null

  suggested_state="$(python3 - <<'PY' "$run_dir/state-evaluation.json"
import json
import sys
with open(sys.argv[1], encoding="utf-8") as fh:
    data = json.load(fh)
print(data.get("to") or "unknown")
PY
)"
  remote_write_done="$(python3 - <<'PY' "$run_dir/state-evaluation.json"
import json
import sys
with open(sys.argv[1], encoding="utf-8") as fh:
    data = json.load(fh)
print(data.get("checks", {}).get("remote_write_completed") or "unknown")
PY
)"

  refreshed_count=$((refreshed_count + 1))
  rows+="| ${run_id} | yes | yes | ${suggested_state} | ${remote_write_done} |
"
done

report="# Run Evidence Refresh

## Metadata

- Generated at: ${generated_at}
- Pattern: runs/${pattern}
- Issue override: ${issue:-none}
- Refreshed runs: ${refreshed_count}
- Remote writes: false

## Runs

${rows}
"

if [[ -n "$output" ]]; then
  mkdir -p "$(dirname "$output")"
  printf '%s' "$report" > "$output"
  echo "refresh_report: $output"
else
  printf '%s' "$report"
fi
