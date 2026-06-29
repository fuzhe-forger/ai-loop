#!/usr/bin/env bash
set -euo pipefail

show_help() {
  cat <<'HELP'
Usage: scripts/golden-path-check.sh --issue <issue> --run-id <run-id> [options]

Check that a completed Multica × ai-loop case has a reproducible golden path:
local evidence, gate policy, writeback summary, metadata artifacts, and optional
Obsidian generated pages are all consistent.

Options:
  --issue <issue>       Issue identifier, required
  --run-id <run-id>     Run identifier under runs/, required
  --generated-root <p>  Obsidian generated root (default: /mnt/d/JAVA/knowledge/tiandao/99-generated)
  --skip-obsidian       Do not check generated Obsidian files
  --output <file>       Markdown report path
  --json-output <file>  JSON report path
  -h, --help            Show this help

This script is read-only. It never writes Multica, Feishu, Obsidian, or Git remote.
HELP
}

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
issue_id=""
run_id=""
generated_root="/mnt/d/JAVA/knowledge/tiandao/99-generated"
skip_obsidian="false"
output_file=""
json_output_file=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --issue)
      issue_id="${2:-}"; shift 2 ;;
    --run-id)
      run_id="${2:-}"; shift 2 ;;
    --generated-root)
      generated_root="${2:-}"; shift 2 ;;
    --skip-obsidian)
      skip_obsidian="true"; shift ;;
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

run_dir="$ROOT_DIR/runs/$run_id"
if [[ ! -d "$run_dir" ]]; then
  echo "Run directory not found: $run_dir" >&2
  exit 1
fi

if [[ -z "$output_file" ]]; then
  output_file="$run_dir/golden-path-check.md"
fi
if [[ -z "$json_output_file" ]]; then
  json_output_file="$run_dir/golden-path-check.json"
fi

json_report="$(python3 - <<'PY' "$ROOT_DIR" "$issue_id" "$run_id" "$generated_root" "$skip_obsidian"
import json
import re
import sys
from pathlib import Path

root, issue, run_id, generated_root, skip_obsidian = sys.argv[1:]
root = Path(root)
run_dir = root / "runs" / run_id
generated_root = Path(generated_root)
checks = []


def add(name, status, detail=""):
    checks.append({"name": name, "status": status, "detail": detail})


def read(path):
    item = Path(path)
    if not item.is_file():
        return ""
    return item.read_text(encoding="utf-8", errors="replace")


def load_json(path):
    item = Path(path)
    if not item.is_file() or item.stat().st_size == 0:
        return None
    try:
        return json.loads(item.read_text(encoding="utf-8"))
    except json.JSONDecodeError:
        return None

core_files = ["summary.md", "stage-report.md", "multica-comment.md"]
for filename in core_files:
    path = run_dir / filename
    add(f"core:{filename}", "PASSED" if path.is_file() and path.stat().st_size > 0 else "FAILED", str(path.relative_to(root)))

state = load_json(run_dir / "state-evaluation.json")
add("state_json", "PASSED" if isinstance(state, dict) else "FAILED", "state-evaluation.json")
if isinstance(state, dict):
    add("state_done", "PASSED" if state.get("to") == "done" else "FAILED", str(state.get("to")))
    add("remote_write_completed", "PASSED" if state.get("checks", {}).get("remote_write_completed") == "YES" else "FAILED", str(state.get("checks", {}).get("remote_write_completed")))

metadata_draft = load_json(run_dir / "metadata-draft.json")
add("metadata_draft", "PASSED" if isinstance(metadata_draft, dict) else "FAILED", "metadata-draft.json")
if isinstance(metadata_draft, dict):
    metadata = metadata_draft.get("metadata", {})
    add("metadata_pipeline_status", "PASSED" if metadata.get("pipeline_status") == "done" else "FAILED", str(metadata.get("pipeline_status")))
    add("metadata_strict_gate", "PASSED" if metadata.get("strict_gate") == "PASSED" else "FAILED", str(metadata.get("strict_gate")))

for gate_name in ["requirement", "deliverable"]:
    text = read(run_dir / f"{gate_name}-gate.md")
    add(f"{gate_name}_gate", "PASSED" if "- Result: PASSED" in text else "FAILED", f"{gate_name}-gate.md")

policy = load_json(run_dir / "gate-policy-check.json")
add("gate_policy_json", "PASSED" if isinstance(policy, dict) else "FAILED", "gate-policy-check.json")
if isinstance(policy, dict):
    add("gate_policy_passed", "PASSED" if policy.get("result") == "PASSED" else "FAILED", str(policy.get("result")))
    add("task_type_documentation", "PASSED" if policy.get("task_type") == "documentation" else "FAILED", str(policy.get("task_type")))

verification = read(run_dir / "verification-report.md")
add("verification_report", "PASSED" if verification else "FAILED", "verification-report.md")
add("strict_evidence_gate", "PASSED" if re.search(r"Strict Evidence Gate[\s\S]*\| .* \| PASSED \|", verification) else "FAILED", "Strict Evidence Gate")
add("state_metadata_gate", "PASSED" if re.search(r"State Metadata Gate[\s\S]*\| .* \| PASSED \|", verification) else "FAILED", "State Metadata Gate")

time_contract_md = run_dir / "execution-time-contract.md"
time_contract_json = load_json(run_dir / "execution-time-contract.json")
add("execution_time_contract", "PASSED" if time_contract_md.is_file() and time_contract_md.stat().st_size > 0 else "FAILED", "execution-time-contract.md")
add("execution_time_contract_json", "PASSED" if isinstance(time_contract_json, dict) else "FAILED", "execution-time-contract.json")
if isinstance(time_contract_json, dict):
    required_fields = [
        "estimate_minutes",
        "basis",
        "started_at",
        "completed_at",
        "elapsed_seconds",
        "elapsed_minutes",
        "variance_note",
        "next_estimate_minutes",
    ]
    missing_fields = [field for field in required_fields if time_contract_json.get(field) in (None, "")]
    add("execution_time_contract_fields", "PASSED" if not missing_fields else "FAILED", ", ".join(missing_fields) if missing_fields else "complete")
    elapsed_seconds = time_contract_json.get("elapsed_seconds")
    add("execution_time_contract_elapsed", "PASSED" if isinstance(elapsed_seconds, (int, float)) and elapsed_seconds >= 0 else "FAILED", str(elapsed_seconds))
    add("execution_time_contract_closeout", "PASSED" if time_contract_json.get("completed_at") else "FAILED", str(time_contract_json.get("completed_at")))

time_calibration_md = run_dir / "time-estimation-calibration.md"
time_calibration_json = load_json(run_dir / "time-estimation-calibration.json")
add("time_estimation_calibration", "PASSED" if time_calibration_md.is_file() and time_calibration_md.stat().st_size > 0 else "FAILED", "time-estimation-calibration.md")
add("time_estimation_calibration_json", "PASSED" if isinstance(time_calibration_json, dict) else "FAILED", "time-estimation-calibration.json")
if isinstance(time_calibration_json, dict):
    summary = time_calibration_json.get("summary") or {}
    add("time_calibration_summary", "PASSED" if "trusted_measured_runs" in summary and "execution_time_contract_runs" in summary else "FAILED", ", ".join(sorted(summary.keys())))

evidence_summary_json = load_json(run_dir / "evidence-summary.json")
if isinstance(evidence_summary_json, dict):
    artifacts = evidence_summary_json.get("artifacts") or {}
    required_time_artifacts = [
        "continuation_gate",
        "continuation_gate_json",
        "execution_time_contract",
        "execution_time_contract_json",
        "time_estimation_calibration",
        "time_estimation_calibration_json",
    ]
    missing_time_artifacts = [key for key in required_time_artifacts if key not in artifacts]
    add("evidence_summary_time_artifacts", "PASSED" if not missing_time_artifacts else "FAILED", ", ".join(missing_time_artifacts) if missing_time_artifacts else "complete")
else:
    add("evidence_summary_time_artifacts", "FAILED", "evidence-summary.json")

writeback = read(run_dir / "writeback-summary.md")
add("writeback_summary", "PASSED" if writeback else "FAILED", "writeback-summary.md")
writeback_json = load_json(run_dir / "writeback-summary.json")
add("writeback_summary_json", "PASSED" if isinstance(writeback_json, dict) else "FAILED", "writeback-summary.json")
if isinstance(writeback_json, dict):
    results = writeback_json.get("results", {})
    metadata = writeback_json.get("metadata", {})
    comment = writeback_json.get("comment", {})
    approval_boundaries = writeback_json.get("approval_boundaries", {})
    add("comment_written", "PASSED" if results.get("comment") is True else "FAILED", str(results.get("comment")))
    add("metadata_written", "PASSED" if results.get("metadata") is True else "FAILED", str(results.get("metadata")))
    add("metadata_pipeline_status", "PASSED" if metadata.get("key") == "pipeline_status" and metadata.get("value") == "done" else "FAILED", metadata.get("raw_value") or "")
    add("status_not_written", "PASSED" if results.get("status") is False else "FAILED", str(results.get("status")))
    if results.get("comment") is True:
        comment_boundary = comment.get("approval_boundary") or approval_boundaries.get("comment")
        add("comment_approval_boundary", "PASSED" if comment_boundary and (root / comment_boundary).is_file() else "FAILED", comment_boundary or "missing")
    else:
        add("comment_approval_boundary", "SKIPPED", "comment not written")
    if results.get("metadata") is True:
        metadata_boundary = metadata.get("approval_boundary") or approval_boundaries.get("metadata")
        add("metadata_approval_boundary", "PASSED" if metadata_boundary and (root / metadata_boundary).is_file() else "FAILED", metadata_boundary or "missing")
    else:
        add("metadata_approval_boundary", "SKIPPED", "metadata not written")
else:
    writeback_markers = {
        "comment_written": "Comment written: true",
        "metadata_written": "Metadata written: true",
        "metadata_pipeline_status": "Metadata write value: pipeline_status=done",
        "status_not_written": "Status written: false",
    }
    for name, marker in writeback_markers.items():
        add(name, "PASSED" if marker in writeback else "FAILED", marker)
    if "Comment written: true" in writeback:
        add("comment_approval_boundary", "PASSED" if "Approval boundary comment:" in writeback else "FAILED", "Approval boundary comment")
    else:
        add("comment_approval_boundary", "SKIPPED", "comment not written")
    if "Metadata written: true" in writeback:
        add("metadata_approval_boundary", "PASSED" if "Approval boundary metadata:" in writeback else "FAILED", "Approval boundary metadata")
    else:
        add("metadata_approval_boundary", "SKIPPED", "metadata not written")

metadata_after = load_json(run_dir / "multica-metadata-after.json")
add("metadata_after_artifact", "PASSED" if isinstance(metadata_after, dict) else "FAILED", "multica-metadata-after.json")
if isinstance(metadata_after, dict):
    add("metadata_after_pipeline_status", "PASSED" if metadata_after.get("pipeline_status") == "done" else "FAILED", str(metadata_after.get("pipeline_status")))

if skip_obsidian == "true":
    add("obsidian", "SKIPPED", "--skip-obsidian")
else:
    index = generated_root / "loop" / "runs-index.md"
    detail = generated_root / "loop" / "runs" / f"{run_id}.md"
    index_text = read(index)
    detail_text = read(detail)
    add("obsidian_index", "PASSED" if f"| {run_id} | done |" in index_text else "FAILED", str(index))
    add("obsidian_detail", "PASSED" if detail_text else "FAILED", str(detail))
    obsidian_markers = {
        "obsidian_gate_policy": "| Policy result | PASSED |",
        "obsidian_comment_written": "Comment written: true",
        "obsidian_metadata_written": "Metadata written: true",
        "obsidian_metadata_value": "Metadata write value: pipeline_status=done",
        "obsidian_execution_time_contract": "## Execution Time Contract",
        "obsidian_time_contract_elapsed": "Elapsed seconds:",
        "obsidian_share_time_contract_gates": "### Time Contract Gates",
        "obsidian_share_time_contract_fields": "execution_time_contract_fields: PASSED",
        "obsidian_share_time_contract_snapshot": "## Share Time Contract Gate Snapshot",
        "obsidian_share_evidence_time_artifacts": "| evidence_summary_time_artifacts | PASSED | complete |",
    }
    for name, marker in obsidian_markers.items():
        add(name, "PASSED" if marker in detail_text else "FAILED", marker)

failed = [check for check in checks if check["status"] == "FAILED"]
report = {
    "schema_version": 1,
    "issue": issue,
    "run_id": run_id,
    "generated_root": str(generated_root),
    "result": "PASSED" if not failed else "FAILED",
    "failed_count": len(failed),
    "checks": checks,
}
print(json.dumps(report, ensure_ascii=False, indent=2))
PY
)"

mkdir -p "$(dirname "$json_output_file")"
printf '%s\n' "$json_report" > "$json_output_file"

markdown_report="$(python3 - <<'PY' "$json_report"
import json
import sys
report = json.loads(sys.argv[1])
rows = ""
for check in report["checks"]:
    detail = str(check.get("detail") or "").replace("|", "\\|")
    rows += f"| {check['name']} | {check['status']} | {detail} |\n"
print(f"""# Golden Path Check: {report['issue']}

## Result

- Result: {report['result']}
- Failed checks: {report['failed_count']}
- Issue: {report['issue']}
- Run ID: {report['run_id']}
- Generated root: {report['generated_root']}
- Remote writes: false

## Checks

| Check | Result | Detail |
|---|---|---|
{rows}
## Notes

- This check is read-only.
- It verifies local evidence, writeback artifacts, and Obsidian generated consistency.
""")
PY
)"

mkdir -p "$(dirname "$output_file")"
printf '%s' "$markdown_report" > "$output_file"

echo "golden_path_report: $output_file"
echo "golden_path_json: $json_output_file"

result="$(python3 - <<'PY' "$json_output_file"
import json
import sys
with open(sys.argv[1], encoding="utf-8") as fh:
    print(json.load(fh).get("result"))
PY
)"

if [[ "$result" != "PASSED" ]]; then
  exit 1
fi
