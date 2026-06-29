#!/usr/bin/env bash
set -euo pipefail

show_help() {
  cat <<'HELP'
Usage: scripts/memory-quality-check.sh [options]

Validate project memory index quality and file references.

Options:
  --policy <file>       Policy file, default config/project-memory-policy.json
  --output <file>       Optional Markdown output path
  --json-output <file>  Optional JSON output path
  -h, --help            Show this help

This script is local-only. It reads memory files and never performs external writes.
HELP
}

policy_file="config/project-memory-policy.json"
output_file=""
json_output_file=""

while [[ $# -gt 0 ]]; do
  case "$1" in
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

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

json_report="$(python3 - <<'PY' "$policy_file"
import datetime as dt
import json
import re
import sys
from pathlib import Path

policy_path = Path(sys.argv[1])
checks = []
findings = []

def add(name, status, detail=""):
    checks.append({"name": name, "status": status, "detail": detail})
    if status != "PASSED":
        findings.append({"name": name, "status": status, "detail": detail})

if not policy_path.is_file():
    raise SystemExit(f"Policy not found: {policy_path}")
policy = json.loads(policy_path.read_text(encoding="utf-8"))
index_path = Path(policy.get("index_file", "memory/index.json"))
add("policy_schema", "PASSED" if policy.get("schema_version") == 1 else "FAILED", str(policy.get("schema_version")))
add("index_exists", "PASSED" if index_path.is_file() else "FAILED", str(index_path))
try:
    index = json.loads(index_path.read_text(encoding="utf-8")) if index_path.is_file() else {}
    add("index_json", "PASSED", str(index_path))
except json.JSONDecodeError as exc:
    index = {}
    add("index_json", "FAILED", str(exc))

add("index_schema", "PASSED" if index.get("schema_version") == 1 else "FAILED", str(index.get("schema_version")))
required_arrays = policy.get("required_top_level_arrays") or []
required_fields = policy.get("required_fields_by_type") or {}
allowed_decision_status = set(policy.get("allowed_decision_status") or [])
allowed_pitfall_severity = set(policy.get("allowed_pitfall_severity") or [])
allowed_review_state = set(policy.get("allowed_review_state") or [])
sensitive_patterns = [re.compile(pattern) for pattern in policy.get("sensitive_patterns") or []]

entry_count = 0
missing_files = []
missing_fields = []
empty_tags = []
invalid_values = []
sensitive_hits = []

for array_name in required_arrays:
    entries = index.get(array_name)
    add(f"array:{array_name}", "PASSED" if isinstance(entries, list) else "FAILED", "array required")
    if not isinstance(entries, list):
        continue
    for entry in entries:
        entry_count += 1
        entry_id = entry.get("id") or "<missing-id>"
        for field in required_fields.get(array_name, []):
            if field not in entry or entry.get(field) in (None, "", []):
                missing_fields.append(f"{array_name}:{entry_id}:{field}")
        tags = entry.get("tags")
        if not isinstance(tags, list) or not tags:
            empty_tags.append(f"{array_name}:{entry_id}")
        if array_name == "decisions" and allowed_decision_status and entry.get("status") not in allowed_decision_status:
            invalid_values.append(f"decisions:{entry_id}:status={entry.get('status')}")
        if array_name == "pitfalls" and allowed_pitfall_severity and entry.get("severity") not in allowed_pitfall_severity:
            invalid_values.append(f"pitfalls:{entry_id}:severity={entry.get('severity')}")
        if array_name == "cases" and allowed_review_state and entry.get("review_state") not in allowed_review_state:
            invalid_values.append(f"cases:{entry_id}:review_state={entry.get('review_state')}")
        file_value = entry.get("file")
        if file_value:
            path = Path(policy.get("memory_dir", "memory")) / file_value
            if not path.is_file() or path.stat().st_size == 0:
                missing_files.append(str(path))
            elif sensitive_patterns:
                text = path.read_text(encoding="utf-8", errors="replace")
                for pattern in sensitive_patterns:
                    if pattern.search(text):
                        sensitive_hits.append(f"{path}:{pattern.pattern}")

add("entry_count", "PASSED" if entry_count > 0 else "FAILED", str(entry_count))
add("required_fields", "PASSED" if not missing_fields else "FAILED", ", ".join(missing_fields[:20]))
add("referenced_files", "PASSED" if not missing_files else "FAILED", ", ".join(missing_files[:20]))
add("tags", "PASSED" if not empty_tags else "FAILED", ", ".join(empty_tags[:20]))
add("enum_values", "PASSED" if not invalid_values else "FAILED", ", ".join(invalid_values[:20]))
add("sensitive_scan", "PASSED" if not sensitive_hits else "FAILED", ", ".join(sensitive_hits[:20]))

report = {
    "schema_version": 1,
    "generated_at": dt.datetime.now(dt.timezone.utc).replace(microsecond=0).isoformat().replace("+00:00", "Z"),
    "policy": str(policy_path),
    "index": str(index_path),
    "entry_count": entry_count,
    "failed_checks": sum(1 for check in checks if check["status"] != "PASSED"),
    "result": "PASSED" if all(check["status"] == "PASSED" for check in checks) else "FAILED",
    "checks": checks,
    "findings": findings,
}
print(json.dumps(report, ensure_ascii=False, indent=2))
PY
)"

markdown_report="$(python3 - <<'PY' "$json_report"
import json
import sys
report = json.loads(sys.argv[1])
print(f"""# Project Memory Quality Check

## Summary

- Generated at: {report['generated_at']}
- Policy: {report['policy']}
- Index: {report['index']}
- Entry count: {report['entry_count']}
- Failed checks: {report['failed_checks']}
- Result: {report['result']}

## Checks

| Check | Status | Detail |
|---|---|---|""")
for check in report["checks"]:
    detail = str(check.get("detail") or "").replace("|", "-")
    print(f"| {check['name']} | {check['status']} | {detail} |")
PY
)"

if [[ -n "$json_output_file" ]]; then
  mkdir -p "$(dirname "$json_output_file")"
  printf '%s\n' "$json_report" > "$json_output_file"
  echo "memory_quality_json: $json_output_file"
fi
if [[ -n "$output_file" ]]; then
  mkdir -p "$(dirname "$output_file")"
  printf '%s\n' "$markdown_report" > "$output_file"
  echo "memory_quality_report: $output_file"
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
