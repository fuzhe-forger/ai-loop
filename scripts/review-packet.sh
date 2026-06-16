#!/usr/bin/env bash
set -euo pipefail

show_help() {
  cat <<'HELP'
Usage: scripts/review-packet.sh --case <case-id> --pattern <glob> [--include-patch-summary <file>] [--output <file>]

Generate a local human-review packet for a case using run evidence directories.

Options:
  --case     Case identifier, for example FUZ-554, required
  --pattern  Glob pattern under runs/, for example 'FUZ-554*', required
  --include-patch-summary
            Optional local patch-summary.md file to reference in the packet
  --output   Optional file path to write the review packet
  -h, --help Show this help

This script is local-only. It reads runs/ and never performs remote writes.
HELP
}

case_id=""
pattern=""
output=""
patch_summary=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --case)
      case_id="${2:-}"; shift 2 ;;
    --pattern)
      pattern="${2:-}"; shift 2 ;;
    --include-patch-summary)
      patch_summary="${2:-}"; shift 2 ;;
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

if [[ -z "$case_id" || -z "$pattern" ]]; then
  echo "--case and --pattern are required" >&2
  show_help
  exit 2
fi

if [[ -n "$patch_summary" && ! -s "$patch_summary" ]]; then
  echo "Patch summary file is missing or empty: $patch_summary" >&2
  exit 1
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

state_field() {
  local state_json="$1"
  local field="$2"
  if [[ ! -s "$state_json" ]]; then
    printf 'not evaluated'
    return
  fi
  python3 - <<'PY' "$state_json" "$field"
import json
import sys

path, field = sys.argv[1:]
with open(path, encoding="utf-8") as fh:
    data = json.load(fh)
print(data.get(field) or "unknown")
PY
}

state_check() {
  local state_json="$1"
  local writeback_summary="$2"
  local field="$3"
  python3 - <<'PY' "$state_json" "$writeback_summary" "$field"
import json
import sys
from pathlib import Path

state_path, writeback_path, field = sys.argv[1:]

def writeback_completed(path: str) -> str:
    item = Path(path)
    if not item.is_file() or item.stat().st_size == 0:
        return "NO"
    text = item.read_text(encoding="utf-8", errors="replace")
    completed = any(marker in text for marker in [
        "Comment written: true",
        "Status written: true",
        "Metadata written: true",
        "Comment ID:",
    ])
    failed = any(marker in text for marker in [
        "Comment written: failed",
        "Status written: failed",
        "Metadata written: failed",
    ])
    return "YES" if completed and not failed else "NO"

if Path(state_path).is_file() and Path(state_path).stat().st_size > 0:
    with open(state_path, encoding="utf-8") as fh:
        data = json.load(fh)
    print(data.get("checks", {}).get(field) or writeback_completed(writeback_path))
else:
    print(writeback_completed(writeback_path))
PY
}

run_count=0
complete_core_count=0
remote_write_count=0
runs_table="| Run | Summary | Stage Report | Comment Draft | Writeback | Remote Write Done | Suggested State | Next Actor |
|---|---|---|---|---|---|---|---|
"

for run_dir in "${run_dirs[@]}"; do
  if [[ ! -d "$run_dir" ]]; then
    continue
  fi
  run_count=$((run_count + 1))
  run_id="$(basename "$run_dir")"
  summary="$(has_file "$run_dir/summary.md")"
  stage_report="$(has_file "$run_dir/stage-report.md")"
  comment="$(has_file "$run_dir/multica-comment.md")"
  writeback="$(has_file "$run_dir/writeback-summary.md")"
  remote_write_done="$(state_check "$run_dir/state-evaluation.json" "$run_dir/writeback-summary.md" remote_write_completed)"
  suggested_state="$(state_field "$run_dir/state-evaluation.json" to)"
  next_actor="$(state_field "$run_dir/state-evaluation.json" required_next_actor)"
  if [[ "$summary" == "yes" && "$stage_report" == "yes" && "$comment" == "yes" ]]; then
    complete_core_count=$((complete_core_count + 1))
  fi
  if [[ "$writeback" == "yes" ]]; then
    remote_write_count=$((remote_write_count + 1))
  fi
  runs_table+="| ${run_id} | ${summary} | ${stage_report} | ${comment} | ${writeback} | ${remote_write_done} | ${suggested_state} | ${next_actor} |
"
done

generated_at="$(date -u '+%Y-%m-%dT%H:%M:%SZ')"

patch_section=""
if [[ -n "$patch_summary" ]]; then
  patch_base="$(awk -F': ' '/^- Base: / {print $2; exit}' "$patch_summary")"
  patch_changed_files="$(awk -F': ' '/^- Changed files: / {print $2; exit}' "$patch_summary")"
  patch_tracked_files="$(awk -F': ' '/^- Tracked changed files: / {print $2; exit}' "$patch_summary")"
  patch_untracked_files="$(awk -F': ' '/^- Untracked files: / {print $2; exit}' "$patch_summary")"
  patch_scope_status="$(awk -F': ' '/^- Status: / {print $2; exit}' "$patch_summary")"

  patch_section="## Patch Summary

- Source: ${patch_summary}
- Base: ${patch_base:-unknown}
- Changed files: ${patch_changed_files:-unknown}
- Tracked changed files: ${patch_tracked_files:-unknown}
- Untracked files: ${patch_untracked_files:-unknown}
- Scope check status: ${patch_scope_status:-unknown}

"
fi

packet="# Review Packet: ${case_id}

## Metadata

- Generated at: ${generated_at}
- Pattern: runs/${pattern}
- Ordering: shell glob expansion order under runs/ with nullglob enabled

## Scope

- Case: ${case_id}
- Run pattern: runs/${pattern}
- Run count: ${run_count}
- Runs with core evidence: ${complete_core_count}
- Runs with writeback summary: ${remote_write_count}

## Evidence Index

${runs_table}
${patch_section}
## Review Checklist

- Are the case goal and boundaries clear?
- Do all formal review runs include summary, stage report, and comment draft?
- Do evaluated runs have a clear suggested state and next actor?
- Does the remote-write-done column match the intended writeback evidence?
- Are remote side effects recorded in writeback summaries when they happened?
- If a patch summary is included, does its scope check pass and match the intended change boundary?
- Is there at least one final report or guide that a teammate can read first?
- Is the next action explicit: continue, review, write back, or stop?

## Suggested Review Decision

- Approve for sharing if core evidence is complete and remote side effects are documented.
- Request follow-up if any formal review run lacks summary or stage report.
- Do not infer business completion from dry-run evidence alone.
"

if [[ -n "$output" ]]; then
  mkdir -p "$(dirname "$output")"
  printf '%s' "$packet" > "$output"
  echo "review_packet: $output"
else
  printf '%s' "$packet"
fi
