#!/usr/bin/env bash
set -euo pipefail

show_help() {
  cat <<'HELP'
Usage: scripts/organization-policy-report.sh --issue <issue-id> --run-id <run-id> [options]

Generate a local Phase C organization policy report.

Options:
  --issue <issue-id>       Issue identifier, required
  --run-id <run-id>        Run directory under runs/, required
  --policy <file>          Policy file, default config/organization-policy.json
  --output <file>          Optional Markdown output path
  --json-output <file>     Optional JSON output path
  -h, --help               Show this help

This script is local-only. It reads local policy/run evidence and never performs remote writes.
HELP
}

issue=""
run_id=""
policy_file="config/organization-policy.json"
output_file=""
json_output_file=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --issue)
      issue="${2:-}"; shift 2 ;;
    --run-id)
      run_id="${2:-}"; shift 2 ;;
    --policy)
      policy_file="${2:-}"; shift 2 ;;
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

if [[ -z "$issue" || -z "$run_id" ]]; then
  echo "--issue and --run-id are required" >&2
  show_help
  exit 2
fi

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"
run_dir="runs/$run_id"
if [[ ! -d "$run_dir" ]]; then
  echo "Run directory not found: $run_dir" >&2
  exit 1
fi

json_report="$(python3 - <<'PY' "$issue" "$run_id" "$policy_file" "$run_dir"
import datetime as dt
import json
import sys
from pathlib import Path

issue, run_id, policy_file, run_dir_text = sys.argv[1:]
run_dir = Path(run_dir_text)
policy_path = Path(policy_file)
policy = json.loads(policy_path.read_text(encoding="utf-8"))
checks = []

def present(path):
    return path.is_file() and path.stat().st_size > 0

def add(name, status, detail=""):
    checks.append({"name": name, "status": status, "detail": detail})

add("policy_schema", "PASSED" if policy.get("schema_version") == 1 else "FAILED", str(policy.get("schema_version")))
module_reports = []
for module_id, module in (policy.get("modules") or {}).items():
    entrypoints = module.get("entrypoints") or []
    missing = [path for path in entrypoints if not Path(path).is_file()]
    status = "PASSED" if not missing else "FAILED"
    add(f"module:{module_id}:entrypoints", status, ", ".join(missing))
    module_reports.append({
        "id": module_id,
        "required_fields": module.get("required_fields") or [],
        "entrypoints": entrypoints,
        "missing_entrypoints": missing,
        "status": status,
    })

artifact_expectations = {
    "routing": [run_dir / "classification.json"],
    "policy": [run_dir / "gate-policy-check.json", run_dir / "execution-preflight.json"],
    "side_effect_gate": [run_dir / "approval-boundary-comment.md", run_dir / "approval-boundary-metadata.md"],
    "review_orchestration": [run_dir / "evidence-summary.json", run_dir / "review-packet.md", run_dir / "verification-report.md"],
}
contract_expectations = {
    "routing": [run_dir / "route-result.json", run_dir / "classification.json"],
    "policy": [run_dir / "gate-policy-check.json"],
    "side_effect_gate": [run_dir / "approval-boundary-comment.json", run_dir / "approval-boundary-status.json", run_dir / "approval-boundary-metadata.json"],
    "review_orchestration": [run_dir / "state-evaluation.json", run_dir / "review-packet.md"],
}
for module_id, paths in artifact_expectations.items():
    available = [str(path) for path in paths if present(path)]
    missing = [str(path) for path in paths if not present(path)]
    status = "PASSED" if available else "WARN"
    add(f"module:{module_id}:evidence", status, "available=" + ", ".join(available) + (" missing=" + ", ".join(missing) if missing else ""))
    for item in module_reports:
        if item["id"] == module_id:
            item["available_evidence"] = available
            item["missing_evidence"] = missing

contracts = {}
for module_id, paths in contract_expectations.items():
    observed = []
    for path in paths:
        if not present(path):
            continue
        contract = None
        if path.suffix == ".json":
            try:
                contract = (json.loads(path.read_text(encoding="utf-8")) or {}).get("contract")
            except json.JSONDecodeError:
                contract = "invalid_json"
        observed.append({"path": str(path), "contract": contract})
    contracts[module_id] = observed

failed = [check for check in checks if check["status"] == "FAILED"]
report = {
    "schema_version": 1,
    "generated_at": dt.datetime.now(dt.timezone.utc).replace(microsecond=0).isoformat().replace("+00:00", "Z"),
    "issue": issue,
    "run_id": run_id,
    "policy": str(policy_path),
    "result": "PASSED" if not failed else "FAILED",
    "failed_checks": len(failed),
    "modules": module_reports,
    "contracts": contracts,
    "checks": checks,
    "remote_write_policy": (policy.get("result_policy") or {}).get("remote_write_policy"),
}
print(json.dumps(report, ensure_ascii=False, indent=2))
PY
)"

markdown_report="$(python3 - <<'PY' "$json_report"
import json
import sys
report = json.loads(sys.argv[1])
print(f"""# Organization Policy Report

## Summary

- Generated at: {report['generated_at']}
- Issue: {report['issue']}
- Run ID: {report['run_id']}
- Policy: {report['policy']}
- Result: {report['result']}
- Failed checks: {report['failed_checks']}
- Remote write policy: {report.get('remote_write_policy')}

## Modules

| Module | Status | Entrypoints | Evidence | Missing Evidence |
|---|---|---|---|---|""")
for module in report["modules"]:
    entrypoints = "<br>".join(module.get("entrypoints") or [])
    evidence = "<br>".join(module.get("available_evidence") or [])
    missing = "<br>".join(module.get("missing_evidence") or [])
    print(f"| {module['id']} | {module['status']} | {entrypoints} | {evidence} | {missing} |")
print("\n## Contracts\n")
print("| Module | Observed Contracts |")
print("|---|---|")
for module_id, observed in (report.get("contracts") or {}).items():
    value = "<br>".join(f"{item.get('contract') or 'legacy'} ({item.get('path')})" for item in observed) or "missing"
    print(f"| {module_id} | {value} |")
print("\n## Checks\n")
print("| Check | Status | Detail |")
print("|---|---|---|")
for check in report["checks"]:
    detail = str(check.get("detail") or "").replace("|", "-")
    print(f"| {check['name']} | {check['status']} | {detail} |")
PY
)"

if [[ -n "$json_output_file" ]]; then
  mkdir -p "$(dirname "$json_output_file")"
  printf '%s\n' "$json_report" > "$json_output_file"
  echo "organization_policy_json: $json_output_file"
fi
if [[ -n "$output_file" ]]; then
  mkdir -p "$(dirname "$output_file")"
  printf '%s\n' "$markdown_report" > "$output_file"
  echo "organization_policy_report: $output_file"
fi
if [[ -z "$json_output_file" && -z "$output_file" ]]; then
  printf '%s\n' "$markdown_report"
fi

python3 - <<'PY' "$json_report"
import json
import sys
report = json.loads(sys.argv[1])
if report.get("result") != "PASSED":
    raise SystemExit(1)
PY
