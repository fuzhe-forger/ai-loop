#!/usr/bin/env bash
set -euo pipefail

show_help() {
  cat <<'HELP'
Usage: scripts/onboarding-drill-check.sh [options]

Validate local outputs from the Sinan onboarding drill. No network, no external writes.

Options:
  --run-id <run-id>       Optional run id; defaults outputs under runs/<run-id>/
  --drill-dir <dir>       Directory containing drill outputs, default runs/onboarding
  --output <file>         Optional Markdown output path
  --json-output <file>    Optional JSON output path
  --allow-missing-verify  Do not require legacy verification.md for lightweight drills
  -h, --help              Show this help

Expected outputs are capability.md/json, flow-advice.md/json, and either
sinan-doctor.md/json or verification.md unless --allow-missing-verify is used.
HELP
}

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
run_id=""
drill_dir="runs/onboarding"
output_file=""
json_output_file=""
allow_missing_verify=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --run-id)
      run_id="${2:-}"; shift 2 ;;
    --drill-dir)
      drill_dir="${2:-}"; shift 2 ;;
    --output)
      output_file="${2:-}"; shift 2 ;;
    --json-output)
      json_output_file="${2:-}"; shift 2 ;;
    --allow-missing-verify)
      allow_missing_verify=1; shift ;;
    -h|--help)
      show_help; exit 0 ;;
    *)
      echo "Unknown argument: $1" >&2
      show_help
      exit 2 ;;
  esac
done

cd "$ROOT_DIR"

if [[ -n "$run_id" ]]; then
  [[ -n "$output_file" ]] || output_file="runs/$run_id/onboarding-drill-check.md"
  [[ -n "$json_output_file" ]] || json_output_file="runs/$run_id/onboarding-drill-check.json"
fi

json_report="$(python3 - <<'PY' "$drill_dir" "$allow_missing_verify" "$run_id"
import datetime as dt
import json
import sys
from pathlib import Path

drill_dir = Path(sys.argv[1])
allow_missing_verify = sys.argv[2] == "1"
run_id = sys.argv[3] or None
checks = []

def add(name, ok, detail="", category="outputs"):
    checks.append({
        "category": category,
        "name": name,
        "status": "PASSED" if ok else "FAILED",
        "detail": detail,
    })

def require_file(name, rel, category="outputs"):
    path = drill_dir / rel
    ok = path.is_file() and path.stat().st_size > 0
    add(name, ok, str(path), category)
    return path if ok else None

def validate_json(name, rel):
    path = drill_dir / rel
    if not path.is_file():
        add(name, False, f"missing: {path}", "json")
        return None
    try:
        data = json.loads(path.read_text(encoding="utf-8"))
    except Exception as exc:
        add(name, False, f"{path}: {exc}", "json")
        return None
    result = data.get("result")
    ok = result in (None, "PASSED")
    add(name, ok, f"{path}; result={result or 'n/a'}", "json")
    return data

add("drill_directory_exists", drill_dir.is_dir(), str(drill_dir), "environment")
add(
    "side_effect_boundary",
    True,
    "read local drill outputs and write optional report only; no external systems touched",
    "safety",
)

require_file("capability_report", "capability.md")
capability_data = validate_json("capability_json", "capability.json")
require_file("flow_advice_report", "flow-advice.md")
flow_data = validate_json("flow_advice_json", "flow-advice.json")

doctor_md = drill_dir / "sinan-doctor.md"
doctor_json = drill_dir / "sinan-doctor.json"
verification_md = drill_dir / "verification.md"
has_doctor = doctor_md.is_file() and doctor_json.is_file()
has_legacy_verify = verification_md.is_file() and verification_md.stat().st_size > 0

add(
    "readiness_check_present",
    has_doctor or has_legacy_verify or allow_missing_verify,
    "sinan-doctor.md/json preferred; verification.md legacy accepted; lightweight bypass enabled" if allow_missing_verify else "need sinan-doctor.md/json or verification.md",
)

if has_doctor:
    require_file("sinan_doctor_report", "sinan-doctor.md")
    validate_json("sinan_doctor_json", "sinan-doctor.json")
elif has_legacy_verify:
    require_file("legacy_verification_report", "verification.md")
else:
    add(
        "legacy_verification_report",
        allow_missing_verify,
        "missing but allowed" if allow_missing_verify else str(verification_md),
    )

if capability_data is not None:
    add(
        "capability_result_passed",
        capability_data.get("result") == "PASSED",
        f"result={capability_data.get('result')}",
        "acceptance",
    )
if flow_data is not None:
    add(
        "flow_advice_local_or_approved",
        not flow_data.get("human_approval_required", False),
        f"tier={flow_data.get('tier')}, approval={flow_data.get('human_approval_required')}",
        "acceptance",
    )

failed = [check for check in checks if check["status"] != "PASSED"]
report = {
    "schema_version": 1,
    "generated_at": dt.datetime.now(dt.timezone.utc).replace(microsecond=0).isoformat().replace("+00:00", "Z"),
    "run_id": run_id,
    "drill_dir": str(drill_dir),
    "result": "PASSED" if not failed else "FAILED",
    "failed_checks": len(failed),
    "allow_missing_verify": allow_missing_verify,
    "side_effects": "local-only output validation; no network, remote Git, deploy, delete, or external write",
    "checks": checks,
}
print(json.dumps(report, ensure_ascii=False, indent=2))
PY
)"

markdown_report="$(python3 - <<'PY' "$json_report"
import json
import sys

report = json.loads(sys.argv[1])

def md_cell(value):
    return str(value or "").replace("|", "-").replace("<", "&lt;").replace(">", "&gt;")

print("# Sinan Onboarding Drill Check")
print()
print(f"- Run ID: `{report.get('run_id') or 'n/a'}`")
print(f"- Drill dir: `{report['drill_dir']}`")
print(f"- Result: {report['result']}")
print(f"- Failed checks: {report['failed_checks']}")
print(f"- Side effects: {report['side_effects']}")
print(f"- Allow missing legacy verification: {report['allow_missing_verify']}")
print()
print("| Category | Check | Result | Detail |")
print("|---|---|---|---|")
for check in report["checks"]:
    print(
        f"| {md_cell(check['category'])} | {md_cell(check['name'])} | "
        f"{md_cell(check['status'])} | {md_cell(check.get('detail', ''))} |"
    )
PY
)"

if [[ -n "$output_file" ]]; then
  mkdir -p "$(dirname "$output_file")"
  printf '%s\n' "$markdown_report" > "$output_file"
  echo "onboarding_drill_check: $output_file"
else
  printf '%s\n' "$markdown_report"
fi

if [[ -n "$json_output_file" ]]; then
  mkdir -p "$(dirname "$json_output_file")"
  printf '%s\n' "$json_report" > "$json_output_file"
  echo "onboarding_drill_check_json: $json_output_file"
fi

result="$(python3 - <<'PY' "$json_report"
import json
import sys
print(json.loads(sys.argv[1])["result"])
PY
)"
[[ "$result" == "PASSED" ]]
