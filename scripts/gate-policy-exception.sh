#!/usr/bin/env bash
set -euo pipefail

show_help() {
  cat <<'HELP'
Usage: scripts/gate-policy-exception.sh --run-id <run-id> --approved-by <name> --reason <text> --expires <YYYY-MM-DD> [options]

Create a local, auditable human exception for a failed gate-policy-check.

Options:
  --run-id <run-id>       Run directory under runs/, required
  --issue <issue-id>      Optional issue identifier
  --approved-by <name>    Human approver, required
  --reason <text>         Why the exception is acceptable, required
  --expires <YYYY-MM-DD>  Expiration date, required
  --scope <text>          Exception scope, default: gate_policy_check
  --output <file>         Markdown output, default runs/<run-id>/gate-policy-exception.md
  --json-output <file>    JSON output, default runs/<run-id>/gate-policy-exception.json
  -h, --help              Show this help

This script is local-only. It writes exception evidence under runs/ and never performs remote writes.
HELP
}

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
run_id=""
issue_id=""
approved_by=""
reason=""
expires=""
scope="gate_policy_check"
output_file=""
json_output_file=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --run-id)
      run_id="${2:-}"; shift 2 ;;
    --issue)
      issue_id="${2:-}"; shift 2 ;;
    --approved-by)
      approved_by="${2:-}"; shift 2 ;;
    --reason)
      reason="${2:-}"; shift 2 ;;
    --expires)
      expires="${2:-}"; shift 2 ;;
    --scope)
      scope="${2:-}"; shift 2 ;;
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

if [[ -z "$run_id" || -z "$approved_by" || -z "$reason" || -z "$expires" ]]; then
  echo "--run-id, --approved-by, --reason, and --expires are required" >&2
  show_help
  exit 2
fi

if [[ ! "$expires" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]]; then
  echo "--expires must use YYYY-MM-DD" >&2
  exit 2
fi

run_dir="$ROOT_DIR/runs/$run_id"
if [[ ! -d "$run_dir" ]]; then
  echo "Run directory not found: runs/$run_id" >&2
  exit 1
fi

if [[ -z "$issue_id" ]]; then
  issue_id="$(printf '%s\n' "$run_id" | grep -Eo '^[A-Z]+-[0-9]+' || true)"
  if [[ ! "$issue_id" =~ ^[A-Z]+-[0-9]+$ ]]; then
    issue_id="unknown"
  fi
fi

if [[ -z "$output_file" ]]; then
  output_file="$run_dir/gate-policy-exception.md"
fi
if [[ -z "$json_output_file" ]]; then
  json_output_file="$run_dir/gate-policy-exception.json"
fi

json_report="$(python3 - <<'PY' "$issue_id" "$run_id" "$scope" "$approved_by" "$reason" "$expires" "$run_dir/gate-policy-check.json" "$run_dir/gate-policy-check.md"
import json
import sys
from datetime import date
from pathlib import Path

issue, run_id, scope, approved_by, reason, expires, gate_policy_json, gate_policy_md = sys.argv[1:]
try:
    expires_date = date.fromisoformat(expires)
except ValueError:
    raise SystemExit("invalid expires date")
status = "ACTIVE" if expires_date >= date.today() else "EXPIRED"

def read_gate_result() -> str:
    json_path = Path(gate_policy_json)
    if json_path.is_file() and json_path.stat().st_size > 0:
        try:
            return json.loads(json_path.read_text(encoding="utf-8")).get("result") or "UNKNOWN"
        except json.JSONDecodeError:
            return "UNKNOWN"
    md_path = Path(gate_policy_md)
    if md_path.is_file() and md_path.stat().st_size > 0:
        for line in md_path.read_text(encoding="utf-8", errors="replace").splitlines():
            stripped = line.strip()
            if stripped.startswith("- Result:"):
                return stripped.split(":", 1)[1].strip() or "UNKNOWN"
    return "MISSING"

data = {
    "schema_version": 1,
    "issue": issue,
    "run_id": run_id,
    "scope": scope,
    "approved_by": approved_by,
    "reason": reason,
    "expires": expires,
    "status": status,
    "gate_policy_result": read_gate_result(),
    "created_at": date.today().isoformat(),
    "side_effects": {
        "network_access": False,
        "remote_writes": False,
    },
}
print(json.dumps(data, ensure_ascii=False, indent=2))
PY
)"

markdown_report="$(python3 - <<'PY' "$json_report"
import json
import sys

data = json.loads(sys.argv[1])
print(f"""# Gate Policy Exception

## Result

- Status: {data['status']}
- Issue: {data['issue']}
- Run ID: {data['run_id']}
- Scope: {data['scope']}
- Gate policy result: {data['gate_policy_result']}
- Approved by: {data['approved_by']}
- Expires: {data['expires']}
- Network access: false
- Remote writes: false

## Reason

{data['reason']}

## Notes

- This exception is local evidence only.
- It does not approve remote writeback.
- It should be reviewed before the expiration date.
""")
PY
)"

mkdir -p "$(dirname "$json_output_file")" "$(dirname "$output_file")"
printf '%s\n' "$json_report" > "$json_output_file"
printf '%s' "$markdown_report" > "$output_file"
echo "gate_policy_exception_json: $json_output_file"
echo "gate_policy_exception_report: $output_file"
