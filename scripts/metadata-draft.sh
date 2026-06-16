#!/usr/bin/env bash
set -euo pipefail

show_help() {
  cat <<'HELP'
Usage: scripts/metadata-draft.sh --run-id <run-id> [--issue <issue-id>] [--output <file>] [--markdown <file>] [--review-verdict <value>]

Generate a local issue metadata draft from run state evidence.

Options:
  --run-id          Run directory name under runs/, required
  --issue           Optional issue identifier, for example FUZ-554
  --output          Optional JSON output path
  --markdown        Optional Markdown output path
  --review-verdict  pending | approved | changes_requested | blocked | not_required, default: pending
  -h, --help        Show this help

This script is local-only. It reads runs/ and never writes Multica metadata.
HELP
}

run_id=""
issue=""
output=""
markdown=""
review_verdict="pending"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --run-id)
      run_id="${2:-}"; shift 2 ;;
    --issue)
      issue="${2:-}"; shift 2 ;;
    --output)
      output="${2:-}"; shift 2 ;;
    --markdown)
      markdown="${2:-}"; shift 2 ;;
    --review-verdict)
      review_verdict="${2:-}"; shift 2 ;;
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

case "$review_verdict" in
  pending|approved|changes_requested|blocked|not_required) ;;
  *)
    echo "Invalid --review-verdict: $review_verdict" >&2
    exit 2 ;;
esac

run_dir="runs/${run_id}"
if [[ ! -d "$run_dir" ]]; then
  echo "Run directory not found: $run_dir" >&2
  exit 1
fi

if [[ -z "$issue" ]]; then
  issue="$(printf '%s\n' "$run_id" | grep -Eo '^[A-Z]+-[0-9]+' || true)"
  if [[ ! "$issue" =~ ^[A-Z]+-[0-9]+$ ]]; then
    issue="unknown"
  fi
fi

state_json_path="$run_dir/state-evaluation.json"
evidence_json_path="$run_dir/evidence.json"

if [[ ! -s "$state_json_path" ]]; then
  ./scripts/evaluate-state.sh --issue "$issue" --run-id "$run_id" --write-run >/dev/null
fi

json_content="$(python3 - <<'PY' "$issue" "$run_id" "$run_dir" "$state_json_path" "$evidence_json_path" "$review_verdict"
import datetime as dt
import json
import sys
from pathlib import Path

issue, run_id, run_dir, state_json_path, evidence_json_path, review_verdict = sys.argv[1:]

with open(state_json_path, encoding="utf-8") as fh:
    state = json.load(fh)

strict_gate = "UNKNOWN"
evidence_path = Path(evidence_json_path)
if evidence_path.is_file() and evidence_path.stat().st_size > 0:
    with evidence_path.open(encoding="utf-8") as fh:
        evidence = json.load(fh)
    strict_gate = evidence.get("checks", {}).get("strict_gate") or strict_gate

pipeline_status = state.get("to") or "unknown"
state_reason = state.get("reason") or "unknown"
blocked_reason = state_reason if pipeline_status == "blocked" else ""

metadata = {
    "pipeline_status": pipeline_status,
    "review_verdict": review_verdict,
    "latest_run_id": state.get("run_id") or run_id,
    "strict_gate": strict_gate,
    "blocked_reason": blocked_reason,
    "next_actor": state.get("required_next_actor") or "unknown",
    "state_reason": state_reason,
    "updated_by": "multica-loop-local",
    "updated_at": dt.datetime.now(dt.timezone.utc).replace(microsecond=0).isoformat().replace("+00:00", "Z"),
}

data = {
    "schema_version": 1,
    "issue": issue,
    "run_id": run_id,
    "run_dir": run_dir,
    "metadata": metadata,
    "sources": {
        "state_evaluation": state_json_path,
        "evidence": evidence_json_path if evidence_path.is_file() else "",
    },
    "remote_write": False,
}

print(json.dumps(data, ensure_ascii=False, indent=2))
PY
)"

markdown_content="$(python3 - <<'PY' "$json_content"
import json
import sys

data = json.loads(sys.argv[1])
metadata = data["metadata"]

print(f"""# Issue Metadata Draft: {data['issue']}

## Scope

- Issue: {data['issue']}
- Run ID: {data['run_id']}
- Remote write: {str(data['remote_write']).lower()}

## Metadata

| Field | Value |
|---|---|
| pipeline_status | {metadata['pipeline_status']} |
| review_verdict | {metadata['review_verdict']} |
| latest_run_id | {metadata['latest_run_id']} |
| strict_gate | {metadata['strict_gate']} |
| blocked_reason | {metadata['blocked_reason']} |
| next_actor | {metadata['next_actor']} |
| state_reason | {metadata['state_reason']} |
| updated_by | {metadata['updated_by']} |
| updated_at | {metadata['updated_at']} |

## Sources

- State evaluation: {data['sources']['state_evaluation']}
- Evidence: {data['sources']['evidence'] or 'not available'}

## Notes

- This is a local metadata draft only.
- It does not write Multica issue metadata.
- Remote metadata sync requires explicit approval and writeback evidence.
""")
PY
)"

if [[ -n "$output" ]]; then
  mkdir -p "$(dirname "$output")"
  printf '%s\n' "$json_content" > "$output"
  echo "metadata_json: $output"
else
  printf '%s\n' "$json_content"
fi

if [[ -n "$markdown" ]]; then
  mkdir -p "$(dirname "$markdown")"
  printf '%s' "$markdown_content" > "$markdown"
  echo "metadata_markdown: $markdown"
fi
