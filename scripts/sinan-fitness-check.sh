#!/usr/bin/env bash
set -euo pipefail

show_help() {
  cat <<'HELP'
Usage: scripts/sinan-fitness-check.sh --run-id <run-id> [options]

Generate a repeatable Sinan fitness report across capability, evidence, memory,
organization policy, timing guard, and verification health.

Options:
  --run-id <run-id>      Run directory under runs/, required
  --config <file>        Fitness check config, default config/sinan-fitness-checks.json
  --output <file>        Optional Markdown output path
  --json-output <file>   Optional JSON output path
  -h, --help             Show this help

This script is local-only. It reads local artifacts and never performs external writes.
HELP
}

run_id=""
config_file="config/sinan-fitness-checks.json"
output_file=""
json_output_file=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --run-id)
      run_id="${2:-}"; shift 2 ;;
    --config)
      config_file="${2:-}"; shift 2 ;;
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

if [[ -z "$run_id" ]]; then
  echo "--run-id is required" >&2
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

json_report="$(python3 - <<'PY' "$run_id" "$config_file"
import datetime as dt
import json
import sys
from pathlib import Path

run_id, config_file = sys.argv[1:]
config_path = Path(config_file)
if not config_path.is_file():
    raise SystemExit(f"Config not found: {config_path}")
config = json.loads(config_path.read_text(encoding="utf-8"))


def replace_run_id(value):
    return str(value).replace("<run-id>", run_id)


def load_json(path):
    path = Path(path)
    if not path.is_file() or path.stat().st_size == 0:
        return None
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except json.JSONDecodeError:
        return None


def get_path(data, path_items):
    current = data
    for item in path_items:
        if not isinstance(current, dict) or item not in current:
            return None
        current = current[item]
    return current


def artifact_present(summary, key):
    artifact = ((summary or {}).get("artifacts") or {}).get(key) or {}
    return artifact.get("present") is True

rows = []
total_weight = 0
passed_weight = 0
category_status = {}
for check in config.get("checks") or []:
    check_id = check.get("id")
    category = check.get("category") or "uncategorized"
    weight = int(check.get("weight") or 0)
    total_weight += weight
    check_type = check.get("type")
    path = replace_run_id(check.get("path") or "")
    status = "FAILED"
    detail = ""
    if check_type == "file_present":
        present = Path(path).is_file() and Path(path).stat().st_size > 0
        status = "PASSED" if present else "FAILED"
        detail = path
    elif check_type in {"json_result", "json_in"}:
        data = load_json(path)
        value = get_path(data, check.get("json_path") or []) if data is not None else None
        if check_type == "json_result":
            expected = check.get("expected")
            status = "PASSED" if value == expected else "FAILED"
            detail = f"{path}: {value!r} expected {expected!r}"
        else:
            expected_any = check.get("expected_any") or []
            status = "PASSED" if value in expected_any else "FAILED"
            detail = f"{path}: {value!r} expected_any {expected_any!r}"
    elif check_type == "artifact_present":
        data = load_json(path)
        missing = [key for key in check.get("artifact_keys") or [] if not artifact_present(data, key)]
        status = "PASSED" if not missing else "FAILED"
        detail = f"missing={', '.join(missing)}" if missing else "all artifacts present"
    else:
        status = "FAILED"
        detail = f"unknown check type: {check_type}"
    if status == "PASSED":
        passed_weight += weight
    category_status.setdefault(category, {"passed": 0, "total": 0, "failed_checks": []})
    category_status[category]["total"] += weight
    if status == "PASSED":
        category_status[category]["passed"] += weight
    else:
        category_status[category]["failed_checks"].append(check_id)
    rows.append({
        "id": check_id,
        "category": category,
        "title": check.get("title"),
        "type": check_type,
        "path": path,
        "weight": weight,
        "status": status,
        "detail": detail,
    })

score = round((passed_weight / total_weight) * 100, 1) if total_weight else 0.0
policy = config.get("score_policy") or {}
required_categories = set(policy.get("required_categories") or [])
missing_categories = sorted(category for category in required_categories if category not in category_status)
failed_required_categories = sorted(
    category for category in required_categories
    if category in category_status and category_status[category]["failed_checks"]
)
if score >= float(policy.get("pass_score", 85)) and not missing_categories and not failed_required_categories:
    result = "PASSED"
elif score >= float(policy.get("warn_score", 70)):
    result = "WARN"
else:
    result = "FAILED"
report = {
    "schema_version": 1,
    "generated_at": dt.datetime.now(dt.timezone.utc).replace(microsecond=0).isoformat().replace("+00:00", "Z"),
    "run_id": run_id,
    "config": str(config_path),
    "score": score,
    "passed_weight": passed_weight,
    "total_weight": total_weight,
    "result": result,
    "missing_required_categories": missing_categories,
    "failed_required_categories": failed_required_categories,
    "categories": category_status,
    "checks": rows,
    "remote_writes": False,
}
print(json.dumps(report, ensure_ascii=False, indent=2))
PY
)"

markdown_report="$(python3 - <<'PY' "$json_report"
import json
import sys
report = json.loads(sys.argv[1])
print(f"""# Sinan Fitness Check

## Summary

- Generated at: {report['generated_at']}
- Run ID: {report['run_id']}
- Config: {report['config']}
- Result: {report['result']}
- Score: {report['score']}
- Passed weight: {report['passed_weight']} / {report['total_weight']}
- Remote writes: false

## Categories

| Category | Passed Weight | Total Weight | Failed Checks |
|---|---:|---:|---|
""")
for category, data in report["categories"].items():
    failed = ", ".join(data.get("failed_checks") or []) or "none"
    print(f"| {category} | {data.get('passed', 0)} | {data.get('total', 0)} | {failed} |")
print("""
## Checks

| ID | Category | Status | Weight | Title | Detail |
|---|---|---|---:|---|---|
""")
for check in report["checks"]:
    detail = str(check.get("detail") or "").replace("|", "-")
    title = str(check.get("title") or "").replace("|", "-")
    print(f"| {check['id']} | {check['category']} | {check['status']} | {check['weight']} | {title} | {detail} |")
print("""
## Next Actions

- FAILED: repair required categories before broadening automation.
- WARN: continue only with explicit risk notes.
- PASSED: system is fit for the next local Sinan slice.
""")
PY
)"

if [[ -n "$json_output_file" ]]; then
  mkdir -p "$(dirname "$json_output_file")"
  printf '%s\n' "$json_report" > "$json_output_file"
  echo "sinan_fitness_json: $json_output_file"
fi
if [[ -n "$output_file" ]]; then
  mkdir -p "$(dirname "$output_file")"
  printf '%s\n' "$markdown_report" > "$output_file"
  echo "sinan_fitness_report: $output_file"
fi
if [[ -z "$json_output_file" && -z "$output_file" ]]; then
  printf '%s\n' "$markdown_report"
fi

result="$(python3 - <<'PY' "$json_report"
import json
import sys
print(json.loads(sys.argv[1])["result"])
PY
)"
if [[ "$result" == "FAILED" ]]; then
  exit 1
fi
