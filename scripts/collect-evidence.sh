#!/usr/bin/env bash
set -euo pipefail

show_help() {
  cat <<'HELP'
Usage: scripts/collect-evidence.sh --issue <issue-id> --run-id <run-id> [--output <file>] [--markdown <file>]

Collect a structured local evidence summary for one ai-loop run.

Options:
  --issue     Issue identifier, for example FUZ-554, required
  --run-id    Run directory name under runs/, required
  --output    Optional JSON output path
  --markdown  Optional Markdown output path
  -h, --help  Show this help

This script is local-only. It reads runs/ and never performs remote writes.
HELP
}

issue=""
run_id=""
output=""
markdown=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --issue)
      issue="${2:-}"; shift 2 ;;
    --run-id)
      run_id="${2:-}"; shift 2 ;;
    --output)
      output="${2:-}"; shift 2 ;;
    --markdown)
      markdown="${2:-}"; shift 2 ;;
    -h|--help)
      show_help; exit 0 ;;
    *)
      echo "Unknown argument: $1" >&2
      show_help
      exit 2 ;;
  esac
done

if [[ -z "$issue" || -z "$run_id" ]]; then
  echo "--issue and --run-id are required" >&2
  show_help
  exit 2
fi

run_dir="runs/${run_id}"
if [[ ! -d "$run_dir" ]]; then
  echo "Run directory not found: $run_dir" >&2
  exit 1
fi

file_status() {
  local path="$1"
  if [[ -s "$path" ]]; then
    printf 'present'
  else
    printf 'missing'
  fi
}

json_bool() {
  local path="$1"
  if [[ -s "$path" ]]; then
    printf 'true'
  else
    printf 'false'
  fi
}

summary_path="$run_dir/summary.md"
stage_report_path="$run_dir/stage-report.md"
comment_path="$run_dir/multica-comment.md"
patch_summary_path="$run_dir/patch-summary.md"
review_packet_path="$run_dir/review-packet.md"
verification_report_path="$run_dir/verification-report.md"
writeback_path="$run_dir/writeback-summary.md"
run_json_path="$run_dir/run.json"

core_status="PASSED"
for required in "$summary_path" "$stage_report_path" "$comment_path"; do
  if [[ ! -s "$required" ]]; then
    core_status="FAILED"
  fi
done

run_status="unknown"
run_mode="unknown"
if [[ -s "$run_json_path" ]]; then
  run_status="$(python3 - <<'PY' "$run_json_path"
import json, sys
with open(sys.argv[1], encoding='utf-8') as fh:
    data = json.load(fh)
print(data.get('status') or 'unknown')
PY
)"
  run_mode="$(python3 - <<'PY' "$run_json_path"
import json, sys
with open(sys.argv[1], encoding='utf-8') as fh:
    data = json.load(fh)
print(data.get('mode') or 'run')
PY
)"
fi

strict_status="UNKNOWN"
if [[ -s "$verification_report_path" ]]; then
  if grep -q "strict evidence gate passed" "$verification_report_path"; then
    strict_status="PASSED"
  elif grep -q "strict evidence gate failed" "$verification_report_path"; then
    strict_status="FAILED"
  fi
fi

json_content="$(python3 - <<'PY' \
  "$issue" "$run_id" "$run_dir" "$run_status" "$run_mode" "$core_status" "$strict_status" \
  "$summary_path" "$stage_report_path" "$comment_path" "$patch_summary_path" "$review_packet_path" "$verification_report_path" "$writeback_path" "$run_json_path"
import json, sys
(
    issue, run_id, run_dir, run_status, run_mode, core_status, strict_status,
    summary_path, stage_report_path, comment_path, patch_summary_path,
    review_packet_path, verification_report_path, writeback_path, run_json_path,
) = sys.argv[1:]
from pathlib import Path

def present(path: str) -> bool:
    return Path(path).is_file() and Path(path).stat().st_size > 0

data = {
    "schema_version": 1,
    "issue": issue,
    "run_id": run_id,
    "run_dir": run_dir,
    "run": {
        "status": run_status,
        "mode": run_mode,
        "run_json": run_json_path,
        "run_json_present": present(run_json_path),
    },
    "checks": {
        "core_evidence": core_status,
        "strict_gate": strict_status,
    },
    "artifacts": {
        "summary": {"path": summary_path, "present": present(summary_path)},
        "stage_report": {"path": stage_report_path, "present": present(stage_report_path)},
        "comment_draft": {"path": comment_path, "present": present(comment_path)},
        "patch_summary": {"path": patch_summary_path, "present": present(patch_summary_path)},
        "review_packet": {"path": review_packet_path, "present": present(review_packet_path)},
        "verification_report": {"path": verification_report_path, "present": present(verification_report_path)},
        "writeback_summary": {"path": writeback_path, "present": present(writeback_path)},
    },
    "remote_writes": False,
}
print(json.dumps(data, ensure_ascii=False, indent=2))
PY
)"

markdown_content="# Evidence Summary: ${issue} / ${run_id}

## Run

- Issue: ${issue}
- Run ID: ${run_id}
- Run status: ${run_status}
- Run mode: ${run_mode}
- Run directory: ${run_dir}
- Remote writes: false

## Checks

- Core evidence: ${core_status}
- Strict gate: ${strict_status}

## Artifacts

| Artifact | Status | Path |
|---|---|---|
| Summary | $(file_status "$summary_path") | ${summary_path} |
| Stage report | $(file_status "$stage_report_path") | ${stage_report_path} |
| Comment draft | $(file_status "$comment_path") | ${comment_path} |
| Patch summary | $(file_status "$patch_summary_path") | ${patch_summary_path} |
| Review packet | $(file_status "$review_packet_path") | ${review_packet_path} |
| Verification report | $(file_status "$verification_report_path") | ${verification_report_path} |
| Writeback summary | $(file_status "$writeback_path") | ${writeback_path} |
| Run JSON | $(file_status "$run_json_path") | ${run_json_path} |

## Review Notes

- Core evidence requires summary, stage report, and comment draft.
- Strict gate is detected from the local verification report when available.
- This collector is local-only and does not write Multica.
"

if [[ -n "$output" ]]; then
  mkdir -p "$(dirname "$output")"
  printf '%s\n' "$json_content" > "$output"
  echo "evidence_json: $output"
else
  printf '%s\n' "$json_content"
fi

if [[ -n "$markdown" ]]; then
  mkdir -p "$(dirname "$markdown")"
  printf '%s' "$markdown_content" > "$markdown"
  echo "evidence_markdown: $markdown"
fi

if [[ "$core_status" == "FAILED" ]]; then
  exit 1
fi
