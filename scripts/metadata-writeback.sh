#!/usr/bin/env bash
set -euo pipefail

show_help() {
  cat <<'HELP'
Usage: scripts/metadata-writeback.sh --issue <issue> --run-id <run-id> [options]

Productized Multica metadata writeback wrapper.

Default mode is dry-run: it validates the local metadata draft and writes local
plan artifacts only. Use --write for the remote Multica metadata KV side effect.

Options:
  --issue <issue>        Issue identifier, required
  --run-id <run-id>      Run identifier under runs/, required
  --key <key>            Metadata key to write (default: pipeline_status)
  --value <value>        Metadata value; default reads metadata.<key> from metadata-draft.json
  --value-type <type>    Force Multica value type: string | number | bool (default: string)
  --approved-by <who>    Human approver name; required with --write
  --workspace-id <id>    Multica workspace id; defaults to MULTICA_WORKSPACE_ID
  --write                Execute remote Multica metadata set/get/list
  --output <file>        Markdown report path (default: runs/<run>/metadata-writeback.md)
  --json-output <file>   JSON report path (default: runs/<run>/metadata-writeback.json)
  -h, --help             Show this help

Allowed keys are intentionally conservative:
  pipeline_status, latest_run_id, strict_gate, next_actor, assigned_actor, blocked_reason

This script never changes Multica issue status, comments, assignee, priority, or reviewer verdict.
HELP
}

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

issue_id=""
run_id=""
metadata_key="pipeline_status"
metadata_value=""
value_type="string"
approved_by=""
workspace_id="${MULTICA_WORKSPACE_ID:-}"
write_remote="false"
output_file=""
json_output_file=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --issue)
      issue_id="${2:-}"; shift 2 ;;
    --run-id)
      run_id="${2:-}"; shift 2 ;;
    --key)
      metadata_key="${2:-}"; shift 2 ;;
    --value)
      metadata_value="${2:-}"; shift 2 ;;
    --value-type)
      value_type="${2:-}"; shift 2 ;;
    --approved-by)
      approved_by="${2:-}"; shift 2 ;;
    --workspace-id)
      workspace_id="${2:-}"; shift 2 ;;
    --write)
      write_remote="true"; shift ;;
    --output)
      output_file="${2:-}"; shift 2 ;;
    --json-output)
      json_output_file="${2:-}"; shift 2 ;;
    -h|--help)
      show_help; exit 0 ;;
    *)
      echo "Unknown argument: $1" >&2
      show_help
      exit 2 ;;
  esac
done

if [[ -z "$issue_id" || -z "$run_id" ]]; then
  echo "--issue and --run-id are required" >&2
  show_help
  exit 2
fi

case "$metadata_key" in
  pipeline_status|latest_run_id|strict_gate|next_actor|assigned_actor|blocked_reason) ;;
  *)
    echo "Metadata key is not allowed for automated writeback: $metadata_key" >&2
    exit 2 ;;
esac

case "$value_type" in
  string|number|bool) ;;
  *)
    echo "Invalid --value-type: $value_type (expected string, number, or bool)" >&2
    exit 2 ;;
esac

run_dir="$ROOT_DIR/runs/$run_id"
metadata_draft="$run_dir/metadata-draft.json"
writeback_summary="$run_dir/writeback-summary.md"
gate_output="$run_dir/writeback-gate-metadata.json"
approval_output="$run_dir/approval-boundary-metadata.md"
approval_json_output="$run_dir/approval-boundary-metadata.json"
result_output="$run_dir/multica-metadata-write-result.json"
readback_output="$run_dir/multica-metadata-get-${metadata_key}.json"
before_output="$run_dir/multica-metadata-before.json"
after_output="$run_dir/multica-metadata-after.json"
error_output="$run_dir/multica-metadata-write-error.log"

if [[ ! -d "$run_dir" ]]; then
  echo "Run directory not found: $run_dir" >&2
  exit 1
fi

if [[ ! -s "$metadata_draft" ]]; then
  echo "Metadata draft is missing or empty: $metadata_draft" >&2
  exit 1
fi

if [[ -z "$output_file" ]]; then
  output_file="$run_dir/metadata-writeback.md"
fi
if [[ -z "$json_output_file" ]]; then
  json_output_file="$run_dir/metadata-writeback.json"
fi

cd "$ROOT_DIR"

if [[ -z "$metadata_value" ]]; then
  metadata_value="$(python3 - <<'PY' "$metadata_draft" "$metadata_key"
import json
import sys
from pathlib import Path
path, key = sys.argv[1:]
data = json.loads(Path(path).read_text(encoding="utf-8"))
metadata = data.get("metadata", {})
value = metadata.get(key)
if value is None:
    raise SystemExit(f"metadata.{key} is absent in {path}")
if isinstance(value, bool):
    print("true" if value else "false")
else:
    print(value)
PY
)"
fi

if [[ -z "$metadata_value" && "$metadata_key" != "blocked_reason" ]]; then
  echo "Metadata value is empty for key: $metadata_key" >&2
  exit 1
fi

if [[ "$write_remote" == "true" && -z "$approved_by" ]]; then
  echo "--approved-by is required with --write" >&2
  exit 2
fi

if [[ -n "$approved_by" ]]; then
  ./scripts/approval-boundary.sh \
    --action multica-metadata \
    --issue "$issue_id" \
    --run-id "$run_id" \
    --approved-by "$approved_by" \
    --output "$approval_output" \
    --json-output "$approval_json_output" >/dev/null
  ./scripts/writeback-gate.sh \
    --issue "$issue_id" \
    --run-id "$run_id" \
    --type metadata \
    --approved-by "$approved_by" \
    --output "$gate_output" >/dev/null
  gate_status="PASSED"
else
  gate_status="NOT_RUN"
fi

run_multica() {
  if [[ -n "$workspace_id" ]]; then
    MULTICA_WORKSPACE_ID="$workspace_id" multica "$@"
  else
    multica "$@"
  fi
}

written="false"
readback_value=""
remote_error=""

if [[ "$write_remote" == "true" ]]; then
  run_multica issue metadata list "$issue_id" --output json > "$before_output" 2>"$error_output" || {
    remote_error="failed to list metadata before write"
    written="failed"
  }

  if [[ "$written" != "failed" ]]; then
    if run_multica issue metadata set "$issue_id" --key "$metadata_key" --value "$metadata_value" --type "$value_type" --output json > "$result_output" 2>"$error_output"; then
      written="true"
    else
      remote_error="failed to set metadata"
      written="failed"
    fi
  fi

  if [[ "$written" == "true" ]]; then
    if run_multica issue metadata get "$issue_id" --key "$metadata_key" --output json > "$readback_output" 2>>"$error_output"; then
      readback_value="$(cat "$readback_output")"
    else
      remote_error="failed to read back metadata"
      written="failed"
    fi
  fi

  if [[ "$written" == "true" ]]; then
    run_multica issue metadata list "$issue_id" --output json > "$after_output" 2>>"$error_output" || {
      remote_error="failed to list metadata after write"
      written="failed"
    }
  fi

  if [[ ! -s "$error_output" ]]; then
    rm -f "$error_output"
  fi
fi

if [[ "$write_remote" == "true" && "$written" == "true" ]]; then
  python3 - <<'PY' "$writeback_summary" "$run_id" "$metadata_key" "$metadata_value" "$approved_by"
from pathlib import Path
import sys
summary_path, run_id, key, value, approved_by = sys.argv[1:]
path = Path(summary_path)
if path.exists():
    text = path.read_text(encoding="utf-8")
else:
    text = "# Multica Loop Writeback Summary\n\n## Remote Write Requests\n\n## Remote Write Results\n\n## Policy Notes\n\n"
if "- Write metadata requested:" in text:
    text = text.replace("- Write metadata requested: false", "- Write metadata requested: true", 1)
    text = text.replace("- Write metadata requested: true\n- Write metadata requested: true", "- Write metadata requested: true")
else:
    text = text.replace("## Remote Write Requests\n", "## Remote Write Requests\n\n- Write metadata requested: true\n", 1)
if "- Metadata written:" in text:
    text = text.replace("- Metadata written: false", "- Metadata written: true", 1)
else:
    text = text.replace("## Remote Write Results\n", "## Remote Write Results\n\n- Metadata written: true\n", 1)
if "- Metadata write value:" in text:
    import re
    text = re.sub(r"- Metadata write value: .*", f"- Metadata write value: {key}={value}", text, count=1)
else:
    marker = "- Metadata written: true\n"
    text = text.replace(marker, marker + f"- Metadata write value: {key}={value}\n", 1)
entry = f"""- Metadata write result: runs/{run_id}/multica-metadata-write-result.json
- Metadata readback: runs/{run_id}/multica-metadata-get-{key}.json
- Metadata before: runs/{run_id}/multica-metadata-before.json
- Metadata after: runs/{run_id}/multica-metadata-after.json
- Approval boundary metadata: runs/{run_id}/approval-boundary-metadata.md
- Metadata writeback gate: runs/{run_id}/writeback-gate-metadata.json
- Metadata approved by: {approved_by}
"""
if "Metadata write result:" not in text:
    marker = f"- Metadata write value: {key}={value}\n"
    text = text.replace(marker, marker + entry, 1)
text = text.replace("- Metadata remote write is not implemented in this phase.", f"- Metadata remote write was executed by scripts/metadata-writeback.sh for approved key `{key}` only.")
text = text.replace("- This summary is generated even when no remote writes are requested.", "- This summary records approved remote writes and their local verification artifacts.")
path.write_text(text, encoding="utf-8")
PY
fi

timestamp="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
report_json="$(python3 - <<'PY' \
  "$issue_id" "$run_id" "$metadata_key" "$metadata_value" "$value_type" "$write_remote" "$written" "$gate_status" "$approved_by" "$workspace_id" "$timestamp" "$output_file" "$json_output_file" "$gate_output" "$result_output" "$readback_output" "$before_output" "$after_output" "$error_output" "$remote_error" "$readback_value"
import json
import sys
(
    issue, run_id, key, value, value_type, write_remote, written, gate_status,
    approved_by, workspace_id, timestamp, output_file, json_output_file,
    gate_output, result_output, readback_output, before_output, after_output,
    error_output, remote_error, readback_value,
) = sys.argv[1:]
report = {
    "schema_version": 1,
    "issue": issue,
    "run_id": run_id,
    "type": "metadata_writeback",
    "dry_run": write_remote != "true",
    "write_requested": write_remote == "true",
    "written": written,
    "metadata": {
        "key": key,
        "value": value,
        "value_type": value_type,
    },
    "gate": {
        "status": gate_status,
        "path": gate_output if gate_status != "NOT_RUN" else "",
    },
    "approval_boundary": {
        "path": "runs/%s/approval-boundary-metadata.md" % run_id if approved_by else "",
        "json_path": "runs/%s/approval-boundary-metadata.json" % run_id if approved_by else "",
        "status": "PASSED" if approved_by else "NOT_RUN",
    },
    "approval": {
        "approved_by": approved_by or None,
    },
    "workspace_id": workspace_id or None,
    "artifacts": {
        "markdown_report": output_file,
        "json_report": json_output_file,
        "write_result": result_output if written in ("true", "failed") else "",
        "readback": readback_output if written == "true" else "",
        "metadata_before": before_output if written in ("true", "failed") else "",
        "metadata_after": after_output if written == "true" else "",
        "error_log": error_output if remote_error else "",
    },
    "readback_value": readback_value or None,
    "remote_error": remote_error or None,
    "timestamp": timestamp,
}
print(json.dumps(report, ensure_ascii=False, indent=2))
PY
)"

mkdir -p "$(dirname "$json_output_file")"
printf '%s\n' "$report_json" > "$json_output_file"

markdown_report="$(python3 - <<'PY' "$report_json"
import json
import sys
report = json.loads(sys.argv[1])
metadata = report["metadata"]
gate = report["gate"]
approval_boundary = report["approval_boundary"]
artifacts = report["artifacts"]
print(f"""# Metadata Writeback Report: {report['issue']}

## Scope

- Issue: {report['issue']}
- Run ID: {report['run_id']}
- Dry run: {str(report['dry_run']).lower()}
- Write requested: {str(report['write_requested']).lower()}
- Written: {report['written']}
- Key: {metadata['key']}
- Value: {metadata['value']}
- Value type: {metadata['value_type']}
- Approved by: {report['approval']['approved_by'] or 'not provided'}
- Workspace ID: {report['workspace_id'] or 'default'}

## Gate

- Approval boundary: {approval_boundary['status']}
- Approval boundary path: {approval_boundary['path'] or 'not run'}
- Status: {gate['status']}
- Path: {gate['path'] or 'not run'}

## Artifacts

- JSON report: {artifacts['json_report']}
- Approval boundary: {approval_boundary['path'] or 'not run'}
- Gate: {gate['path'] or 'not run'}
- Write result: {artifacts['write_result'] or 'not written'}
- Readback: {artifacts['readback'] or 'not written'}
- Metadata before: {artifacts['metadata_before'] or 'not read'}
- Metadata after: {artifacts['metadata_after'] or 'not read'}
- Error log: {artifacts['error_log'] or 'none'}

## Notes

- This script writes only a single allowlisted metadata key.
- It never changes issue status, comments, assignee, priority, or reviewer verdict.
- Use `--write` only after explicit human approval.
""")
PY
)"
mkdir -p "$(dirname "$output_file")"
printf '%s' "$markdown_report" > "$output_file"

echo "metadata_writeback_report: $output_file"
echo "metadata_writeback_json: $json_output_file"

if [[ "$write_remote" == "true" && "$written" != "true" ]]; then
  exit 1
fi
