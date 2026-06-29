#!/usr/bin/env bash
set -euo pipefail

show_help() {
  cat <<'HELP'
Usage: scripts/share-preflight.sh [--case <case-id>] [--pattern <glob>] [--output-dir <dir>] [--golden-run-id <run-id>]

Run the local sharing preflight pipeline: refresh run evidence, verify gates, and build a review packet.

Options:
  --case        Case identifier, default: FUZ-554
  --pattern     Run glob pattern under runs/, default: '<case>*'
  --output-dir  Directory for generated reports, default: /tmp/ai-loop-share-preflight-<case>
  --golden-run-id
                Optional completed run id for golden-path consistency check
  --skip-golden-path
                Do not run golden-path-check even when --golden-run-id is set
  --skip-obsidian
                Pass --skip-obsidian to golden-path-check
  --skip-verify Do not run verify-toolchain; write a local skipped verification note
  --persist-to-run
                Copy share-preflight summary artifacts into runs/<golden-run-id>/
  -h, --help    Show this help

This script is local-only. It writes reports to --output-dir and state artifacts under matching runs/ directories. It never writes Multica.
HELP
}

case_id="FUZ-554"
pattern=""
output_dir=""
golden_run_id=""
skip_golden_path="false"
skip_obsidian="false"
skip_verify="false"
persist_to_run="false"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --case)
      case_id="${2:-}"; shift 2 ;;
    --pattern)
      pattern="${2:-}"; shift 2 ;;
    --output-dir)
      output_dir="${2:-}"; shift 2 ;;
    --golden-run-id)
      golden_run_id="${2:-}"; shift 2 ;;
    --skip-golden-path)
      skip_golden_path="true"; shift ;;
    --skip-obsidian)
      skip_obsidian="true"; shift ;;
    --skip-verify)
      skip_verify="true"; shift ;;
    --persist-to-run)
      persist_to_run="true"; shift ;;
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

if [[ -z "$output_dir" ]]; then
  output_dir="/tmp/ai-loop-share-preflight-${case_id}"
fi

mkdir -p "$output_dir"

refresh_report="$output_dir/refresh-report.md"
verify_report="$output_dir/verification-report.md"
review_packet="$output_dir/review-packet.md"
golden_path_report="$output_dir/golden-path-check.md"
golden_path_json="$output_dir/golden-path-check.json"
summary_report="$output_dir/share-preflight-summary.md"
summary_json="$output_dir/share-preflight-summary.json"

./scripts/refresh-run-evidence.sh \
  --pattern "$pattern" \
  --issue "$case_id" \
  --output "$refresh_report"

if [[ "$skip_verify" == "true" ]]; then
  cat > "$verify_report" <<VERIFY
# Toolchain Verification: ${case_id}

## Result

- Result: SKIPPED
- Reason: share-preflight invoked with --skip-verify

Local helper toolchain smoke checks were skipped by caller.
VERIFY
else
  ./scripts/verify-toolchain.sh \
    --case "$case_id" \
    --pattern "$pattern" \
    --strict \
    --state-gate \
    --output "$verify_report"
fi

./scripts/review-packet.sh \
  --case "$case_id" \
  --pattern "$pattern" \
  --output "$review_packet"

golden_path_result="SKIPPED"
golden_failed_count="n/a"
golden_time_contract_json="[]"
if [[ "$skip_golden_path" != "true" && -n "$golden_run_id" ]]; then
  ./scripts/golden-path-check.sh \
    --issue "$case_id" \
    --run-id "$golden_run_id" \
    ${skip_obsidian:+--skip-obsidian} \
    --output "$golden_path_report" \
    --json-output "$golden_path_json"
  golden_path_result="$(python3 - <<'PY' "$golden_path_json"
import json
import sys
with open(sys.argv[1], encoding="utf-8") as fh:
    data = json.load(fh)
print(data.get("result") or "UNKNOWN")
PY
)"
  golden_failed_count="$(python3 - <<'PY' "$golden_path_json"
import json
import sys
with open(sys.argv[1], encoding="utf-8") as fh:
    data = json.load(fh)
print(data.get("failed_count", "unknown"))
PY
)"
  golden_time_contract_json="$(python3 - <<'PY' "$golden_path_json"
import json
import sys
with open(sys.argv[1], encoding="utf-8") as fh:
    data = json.load(fh)
wanted = [
    "execution_time_contract",
    "execution_time_contract_json",
    "execution_time_contract_fields",
    "execution_time_contract_elapsed",
    "execution_time_contract_closeout",
    "time_estimation_calibration",
    "time_estimation_calibration_json",
    "time_calibration_summary",
    "evidence_summary_time_artifacts",
]
checks = {item.get("name"): item for item in data.get("checks") or []}
rows = []
for name in wanted:
    item = checks.get(name) or {"name": name, "status": "MISSING", "detail": "not found"}
    rows.append({
        "name": name,
        "status": item.get("status") or "UNKNOWN",
        "detail": item.get("detail") or "",
    })
print(json.dumps(rows, ensure_ascii=False))
PY
)"
fi

generated_at="$(date -u '+%Y-%m-%dT%H:%M:%SZ')"

verification_conclusion="$(awk 'NF {last=$0} END {print last}' "$verify_report")"
approval_boundary_json="$(python3 - <<'PY' "$review_packet"
import json
import sys
from pathlib import Path

path = Path(sys.argv[1])
if not path.is_file():
    print(json.dumps([{
        "run_id": None,
        "approval_boundary": "unavailable",
        "remote_write_done": "UNKNOWN",
        "note": "review packet missing",
    }], ensure_ascii=False))
    raise SystemExit
rows = []
headers = []
for line in path.read_text(encoding="utf-8", errors="replace").splitlines():
    if not line.startswith("|") or line.startswith("|---"):
        continue
    cells = [cell.strip() for cell in line.strip().strip("|").split("|")]
    if "Run" in cells and "Approval Boundary" in cells and "Remote Write Done" in cells:
        headers = cells
        continue
    if not headers:
        continue
    try:
        run_idx = headers.index("Run")
        approval_idx = headers.index("Approval Boundary")
        remote_idx = headers.index("Remote Write Done")
    except ValueError:
        continue
    if len(cells) <= max(run_idx, approval_idx, remote_idx):
        continue
    run_id = cells[run_idx]
    approval_boundary = cells[approval_idx]
    remote_write_done = cells[remote_idx]
    if remote_write_done == "YES" or approval_boundary not in ("", "none"):
        rows.append({
            "run_id": run_id,
            "approval_boundary": approval_boundary,
            "remote_write_done": remote_write_done,
        })
if rows:
    print(json.dumps(rows, ensure_ascii=False))
else:
    print(json.dumps([], ensure_ascii=False))
PY
)"
approval_boundary_rows="$(python3 - <<'PY' "$approval_boundary_json"
import json
import sys
rows = json.loads(sys.argv[1])
if not rows:
    print("- No completed remote writes detected in review packet.")
else:
    for row in rows:
        run_id = row.get("run_id") or "unknown"
        approval_boundary = row.get("approval_boundary") or "none"
        remote_write_done = row.get("remote_write_done") or "UNKNOWN"
        note = row.get("note")
        suffix = f"; note={note}" if note else ""
        print(f"- {run_id}: approval_boundary={approval_boundary}; remote_write_done={remote_write_done}{suffix}")
PY
)"
golden_time_contract_rows="$(python3 - <<'PY' "$golden_time_contract_json" "$golden_path_result"
import json
import sys
rows = json.loads(sys.argv[1])
golden_path_result = sys.argv[2]
if golden_path_result == "SKIPPED":
    print("- Golden path check skipped; time contract gates not evaluated.")
elif not rows:
    print("- No time contract gate results found.")
else:
    for row in rows:
        detail = row.get("detail") or ""
        suffix = f"; detail={detail}" if detail else ""
        print(f"- {row.get('name')}: {row.get('status')}{suffix}")
PY
)"

persisted_summary_report=""
persisted_summary_json=""
if [[ "$persist_to_run" == "true" ]]; then
  if [[ -z "$golden_run_id" ]]; then
    echo "--persist-to-run requires --golden-run-id" >&2
    exit 2
  fi
  run_dir="runs/$golden_run_id"
  if [[ ! -d "$run_dir" ]]; then
    echo "Run directory not found for --persist-to-run: $run_dir" >&2
    exit 1
  fi
  persisted_summary_report="$run_dir/share-preflight-summary.md"
  persisted_summary_json="$run_dir/share-preflight-summary.json"
fi

python3 - <<'PY' \
  "$summary_json" "$generated_at" "$case_id" "$pattern" "$output_dir" "${golden_run_id:-}" "$golden_path_result" "$golden_failed_count" "$golden_time_contract_json" "$skip_verify" "$verification_conclusion" "$refresh_report" "$verify_report" "$review_packet" "$golden_path_report" "$golden_path_json" "$approval_boundary_json" "$persisted_summary_report" "$persisted_summary_json"
import json
import sys
from pathlib import Path

(
    summary_json,
    generated_at,
    case_id,
    pattern,
    output_dir,
    golden_run_id,
    golden_path_result,
    golden_failed_count,
    golden_time_contract_json,
    skip_verify,
    verification_conclusion,
    refresh_report,
    verify_report,
    review_packet,
    golden_path_report,
    golden_path_json,
    approval_boundary_json,
    persisted_summary_report,
    persisted_summary_json,
) = sys.argv[1:]

def coerce_failed_count(value: str):
    try:
        return int(value)
    except ValueError:
        return value

data = {
    "schema_version": 1,
    "generated_at": generated_at,
    "case": case_id,
    "pattern": f"runs/{pattern}",
    "output_dir": output_dir,
    "golden_run_id": golden_run_id or None,
    "golden_path": {
        "result": golden_path_result,
        "failed_checks": coerce_failed_count(golden_failed_count),
        "time_contract_gates": json.loads(golden_time_contract_json),
        "report": golden_path_report,
        "json": golden_path_json,
    },
    "toolchain_verification": {
        "mode": "SKIPPED" if skip_verify == "true" else "RUN",
        "conclusion": verification_conclusion,
        "report": verify_report,
    },
    "approval_boundary": json.loads(approval_boundary_json),
    "reports": {
        "refresh": refresh_report,
        "verification": verify_report,
        "review_packet": review_packet,
        "golden_path": golden_path_report,
        "golden_path_json": golden_path_json,
        "summary_markdown": str(Path(summary_json).with_suffix(".md")),
        "summary_json": summary_json,
        "persisted_summary_markdown": persisted_summary_report or None,
        "persisted_summary_json": persisted_summary_json or None,
    },
    "network_access": False,
    "remote_writes": False,
}
Path(summary_json).write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
PY

cat > "$summary_report" <<REPORT
# Sharing Preflight Summary: ${case_id}

## Metadata

- Generated at: ${generated_at}
- Case: ${case_id}
- Pattern: runs/${pattern}
- Output directory: ${output_dir}
- Golden run ID: ${golden_run_id:-none}
- Golden path check: ${golden_path_result}
- Golden path failed checks: ${golden_failed_count}
- Toolchain verification: $(if [[ "$skip_verify" == "true" ]]; then printf 'SKIPPED'; else printf 'RUN'; fi)
- Network access: false
- Remote writes: false

## Reports

- Refresh report: ${refresh_report}
- Verification report: ${verify_report}
- Review packet: ${review_packet}
- Golden path report: ${golden_path_report}
- Golden path JSON: ${golden_path_json}
- Summary JSON: ${summary_json}
- Persisted summary: ${persisted_summary_report:-not persisted}
- Persisted summary JSON: ${persisted_summary_json:-not persisted}

## Review Snapshot

- Verification conclusion: ${verification_conclusion}

### Approval Boundary

${approval_boundary_rows}

### Time Contract Gates

${golden_time_contract_rows}

## Result

Sharing preflight completed locally.
REPORT

if [[ "$persist_to_run" == "true" ]]; then
  cp "$summary_report" "$persisted_summary_report"
  cp "$summary_json" "$persisted_summary_json"
fi

echo "refresh_report: $refresh_report"
echo "verification_report: $verify_report"
echo "review_packet: $review_packet"
if [[ "$golden_path_result" != "SKIPPED" ]]; then
  echo "golden_path_report: $golden_path_report"
  echo "golden_path_json: $golden_path_json"
fi
echo "summary_report: $summary_report"
echo "summary_json: $summary_json"
if [[ -n "$persisted_summary_report" ]]; then
  echo "persisted_summary_report: $persisted_summary_report"
  echo "persisted_summary_json: $persisted_summary_json"
fi
