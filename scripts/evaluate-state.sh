#!/usr/bin/env bash
set -euo pipefail

show_help() {
  cat <<'HELP'
Usage: scripts/evaluate-state.sh --run-id <run-id> [--issue <issue-id>] [--write-run] [--output <file>] [--markdown <file>]

Evaluate a local ai-loop run directory and suggest the next Multica Loop state.

Options:
  --run-id    Run directory name under runs/, required
  --issue     Optional issue identifier, for example FUZ-554
  --write-run Write state-evaluation.json and state-evaluation.md into the run directory
  --output    Optional JSON output path
  --markdown  Optional Markdown output path
  -h, --help  Show this help

This script is local-only. It reads runs/ and never performs remote writes.
HELP
}

run_id=""
issue=""
output=""
markdown=""
write_run="false"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --run-id)
      run_id="${2:-}"; shift 2 ;;
    --issue)
      issue="${2:-}"; shift 2 ;;
    --write-run)
      write_run="true"; shift ;;
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

if [[ "$write_run" == "true" ]]; then
  output="$run_dir/state-evaluation.json"
  markdown="$run_dir/state-evaluation.md"
fi

if [[ -z "$issue" ]]; then
  issue="$(printf '%s\n' "$run_id" | grep -Eo '^[A-Z]+-[0-9]+' || true)"
  if [[ ! "$issue" =~ ^[A-Z]+-[0-9]+$ ]]; then
    issue="unknown"
  fi
fi

summary_path="$run_dir/summary.md"
stage_report_path="$run_dir/stage-report.md"
comment_path="$run_dir/multica-comment.md"
patch_summary_path="$run_dir/patch-summary.md"
review_packet_path="$run_dir/review-packet.md"
scope_split_path="$run_dir/scope-split-report.md"
verification_report_path="$run_dir/verification-report.md"
writeback_path="$run_dir/writeback-summary.md"
run_json_path="$run_dir/run.json"

json_content="$(python3 - <<'PY' \
  "$issue" "$run_id" "$run_dir" \
  "$summary_path" "$stage_report_path" "$comment_path" "$patch_summary_path" \
  "$review_packet_path" "$scope_split_path" "$verification_report_path" "$writeback_path" "$run_json_path"
import json
import sys
from pathlib import Path

(
    issue,
    run_id,
    run_dir,
    summary_path,
    stage_report_path,
    comment_path,
    patch_summary_path,
    review_packet_path,
    scope_split_path,
    verification_report_path,
    writeback_path,
    run_json_path,
) = sys.argv[1:]


def present(path: str) -> bool:
    item = Path(path)
    return item.is_file() and item.stat().st_size > 0


def read_text(path: str) -> str:
    item = Path(path)
    if not item.is_file():
        return ""
    return item.read_text(encoding="utf-8", errors="replace")


def writeback_completed(path: str) -> bool:
    text = read_text(path)
    if not text:
        return False
    completed_markers = [
        "Comment written: true",
        "Status written: true",
        "Metadata written: true",
        "Comment ID:",
    ]
    failed_markers = [
        "Comment written: failed",
        "Status written: failed",
        "Metadata written: failed",
    ]
    return any(marker in text for marker in completed_markers) and not any(
        marker in text for marker in failed_markers
    )


artifacts = {
    "summary": {"path": summary_path, "present": present(summary_path)},
    "stage_report": {"path": stage_report_path, "present": present(stage_report_path)},
    "comment_draft": {"path": comment_path, "present": present(comment_path)},
    "patch_summary": {"path": patch_summary_path, "present": present(patch_summary_path)},
    "review_packet": {"path": review_packet_path, "present": present(review_packet_path)},
    "scope_split_report": {"path": scope_split_path, "present": present(scope_split_path)},
    "verification_report": {"path": verification_report_path, "present": present(verification_report_path)},
    "writeback_summary": {"path": writeback_path, "present": present(writeback_path)},
    "run_json": {"path": run_json_path, "present": present(run_json_path)},
}

missing_core = [
    name
    for name in ("summary", "stage_report", "comment_draft")
    if not artifacts[name]["present"]
]
remote_write_completed = writeback_completed(writeback_path)

if missing_core:
    from_state = "running"
    to_state = "blocked"
    reason = "missing_evidence: " + ", ".join(missing_core)
    next_actor = "execution_agent"
    side_effects_allowed = False
elif not artifacts["verification_report"]["present"]:
    from_state = "running"
    to_state = "evidence_ready"
    reason = "core evidence complete; verification report is not present"
    next_actor = "execution_agent"
    side_effects_allowed = False
elif remote_write_completed:
    from_state = "writeback_ready"
    to_state = "done"
    reason = "writeback summary shows at least one completed remote write"
    next_actor = "human"
    side_effects_allowed = False
else:
    from_state = "evidence_ready"
    to_state = "review_ready"
    reason = "core evidence complete and verification report present"
    next_actor = "reviewer"
    side_effects_allowed = False

checks = {
    "core_evidence": "FAILED" if missing_core else "PASSED",
    "verification_report": "PRESENT" if artifacts["verification_report"]["present"] else "MISSING",
    "writeback_summary": "PRESENT" if artifacts["writeback_summary"]["present"] else "MISSING",
    "remote_write_completed": "YES" if remote_write_completed else "NO",
}

data = {
    "schema_version": 1,
    "issue": issue,
    "run_id": run_id,
    "run_dir": run_dir,
    "from": from_state,
    "to": to_state,
    "reason": reason,
    "required_next_actor": next_actor,
    "side_effects_allowed": side_effects_allowed,
    "checks": checks,
    "missing_core_evidence": missing_core,
    "artifacts": artifacts,
}

print(json.dumps(data, ensure_ascii=False, indent=2))
PY
)"

markdown_content="$(python3 - <<'PY' "$json_content"
import json
import sys

data = json.loads(sys.argv[1])


def status(present: bool) -> str:
    return "present" if present else "missing"


rows = []
for label, key in [
    ("Summary", "summary"),
    ("Stage report", "stage_report"),
    ("Comment draft", "comment_draft"),
    ("Patch summary", "patch_summary"),
    ("Review packet", "review_packet"),
    ("Scope split report", "scope_split_report"),
    ("Verification report", "verification_report"),
    ("Writeback summary", "writeback_summary"),
]:
    artifact = data["artifacts"][key]
    rows.append(f"| {label} | {status(artifact['present'])} | {artifact['path']} |")

print(f"""# Loop State Evaluation: {data['issue']} / {data['run_id']}

## Suggested Transition

- From: {data['from']}
- To: {data['to']}
- Reason: {data['reason']}
- Required next actor: {data['required_next_actor']}
- Side effects allowed: {str(data['side_effects_allowed']).lower()}

## Checks

- Core evidence: {data['checks']['core_evidence']}
- Verification report: {data['checks']['verification_report']}
- Writeback summary: {data['checks']['writeback_summary']}

## Artifacts

| Artifact | Status | Path |
|---|---|---|
{chr(10).join(rows)}

## Notes

- This is a local recommendation only.
- It does not write Multica comments or status.
- Remote side effects still require the existing policy and human control.
""")
PY
)"

if [[ -n "$output" ]]; then
  mkdir -p "$(dirname "$output")"
  printf '%s\n' "$json_content" > "$output"
  echo "state_json: $output"
else
  printf '%s\n' "$json_content"
fi

if [[ -n "$markdown" ]]; then
  mkdir -p "$(dirname "$markdown")"
  printf '%s' "$markdown_content" > "$markdown"
  echo "state_markdown: $markdown"
fi
