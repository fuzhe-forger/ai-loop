#!/usr/bin/env bash
set -euo pipefail

show_help() {
  cat <<'HELP'
Usage: scripts/memory-promote-draft.sh --case-draft <file> --index-entry <file> [options]

Validate and optionally promote a memory case draft into memory/ and memory/index.json.

Options:
  --case-draft <file>   Memory case Markdown draft, required
  --index-entry <file>  Proposed memory/index.json case entry, required
  --policy <file>       Policy file, default config/project-memory-policy.json
  --index <file>        Memory index file, default from policy
  --execute             Copy the case draft and append the index entry; default is dry-run
  --output <file>       Optional Markdown output path
  --json-output <file>  Optional JSON output path
  -h, --help            Show this help

This script is local-only. By default it performs a dry-run and never writes.
HELP
}

case_draft=""
index_entry=""
policy_file="config/project-memory-policy.json"
index_file=""
execute="false"
output_file=""
json_output_file=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --case-draft)
      case_draft="${2:-}"; shift 2 ;;
    --index-entry)
      index_entry="${2:-}"; shift 2 ;;
    --policy)
      policy_file="${2:-}"; shift 2 ;;
    --index)
      index_file="${2:-}"; shift 2 ;;
    --execute)
      execute="true"; shift ;;
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

if [[ -z "$case_draft" || -z "$index_entry" ]]; then
  echo "--case-draft and --index-entry are required" >&2
  show_help
  exit 2
fi

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

json_report="$(python3 - <<'PY' "$case_draft" "$index_entry" "$policy_file" "$index_file" "$execute"
import datetime as dt
import json
import re
import shutil
import sys
from pathlib import Path

case_draft_text, index_entry_text, policy_file, index_file, execute_text = sys.argv[1:]
execute = execute_text == "true"
case_draft = Path(case_draft_text)
entry_path = Path(index_entry_text)
policy_path = Path(policy_file)
policy = json.loads(policy_path.read_text(encoding="utf-8"))
index_path = Path(index_file or policy.get("index_file", "memory/index.json"))
memory_dir = Path(policy.get("memory_dir", "memory"))
index = json.loads(index_path.read_text(encoding="utf-8"))
entry = json.loads(entry_path.read_text(encoding="utf-8"))
checks = []

def add(name, status, detail=""):
    checks.append({"name": name, "status": status, "detail": detail})

def inside_memory(path):
    try:
        path.resolve().relative_to(memory_dir.resolve())
        return True
    except ValueError:
        return False

case_id = entry.get("id")
file_value = entry.get("file") or ""
target_path = memory_dir / file_value
existing_ids = {item.get("id") for item in index.get("cases") or []}
existing_files = {item.get("file") for item in index.get("cases") or []}
allowed_review_state = set(policy.get("allowed_review_state") or [])
required_fields = (policy.get("required_fields_by_type") or {}).get("cases") or []

add("case_draft_exists", "PASSED" if case_draft.is_file() and case_draft.stat().st_size > 0 else "FAILED", str(case_draft))
add("entry_json", "PASSED" if isinstance(entry, dict) else "FAILED", str(entry_path))
missing_fields = [field for field in required_fields if not entry.get(field)]
add("required_fields", "PASSED" if not missing_fields else "FAILED", ", ".join(missing_fields))
add("review_state", "PASSED" if entry.get("review_state") in allowed_review_state else "FAILED", str(entry.get("review_state")))
add("case_id_unique", "PASSED" if case_id and case_id not in existing_ids else "FAILED", str(case_id))
add("case_file_unique", "PASSED" if file_value and file_value not in existing_files else "FAILED", file_value)
add("target_under_memory", "PASSED" if file_value and inside_memory(target_path) else "FAILED", str(target_path))
add("target_missing", "PASSED" if not target_path.exists() else "FAILED", str(target_path))
if case_draft.is_file() and case_id:
    draft_text = case_draft.read_text(encoding="utf-8", errors="replace")
    add("draft_mentions_case_id", "PASSED" if case_id in draft_text else "FAILED", case_id)
else:
    add("draft_mentions_case_id", "FAILED", case_id or "<missing>")
for pattern in policy.get("sensitive_patterns") or []:
    if case_draft.is_file() and re.search(pattern, case_draft.read_text(encoding="utf-8", errors="replace")):
        add("sensitive_scan", "FAILED", pattern)
        break
else:
    add("sensitive_scan", "PASSED", "")

failed = [check for check in checks if check["status"] != "PASSED"]
result = "PASSED" if not failed else "FAILED"
changed = False
if execute and result == "PASSED":
    target_path.parent.mkdir(parents=True, exist_ok=True)
    shutil.copyfile(case_draft, target_path)
    index.setdefault("cases", []).append(entry)
    index["updated_at"] = dt.datetime.now(dt.timezone.utc).replace(microsecond=0).isoformat().replace("+00:00", "Z")
    index_path.write_text(json.dumps(index, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    changed = True

report = {
    "schema_version": 1,
    "generated_at": dt.datetime.now(dt.timezone.utc).replace(microsecond=0).isoformat().replace("+00:00", "Z"),
    "policy": str(policy_path),
    "index": str(index_path),
    "case_draft": str(case_draft),
    "index_entry": str(entry_path),
    "case_id": case_id,
    "target_path": str(target_path),
    "execute": execute,
    "changed": changed,
    "result": result,
    "failed_checks": len(failed),
    "checks": checks,
    "side_effects": [str(target_path), str(index_path)] if changed else [],
}
print(json.dumps(report, ensure_ascii=False, indent=2))
if result != "PASSED":
    raise SystemExit(1)
PY
)"

markdown_report="$(python3 - <<'PY' "$json_report"
import json
import sys
report = json.loads(sys.argv[1])
print(f"""# Memory Promote Draft Gate

## Summary

- Generated at: {report['generated_at']}
- Policy: {report['policy']}
- Index: {report['index']}
- Case draft: {report['case_draft']}
- Index entry: {report['index_entry']}
- Case ID: {report['case_id']}
- Target path: {report['target_path']}
- Execute: {str(report['execute']).lower()}
- Changed: {str(report['changed']).lower()}
- Result: {report['result']}
- Failed checks: {report['failed_checks']}

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
  echo "memory_promote_json: $json_output_file"
fi
if [[ -n "$output_file" ]]; then
  mkdir -p "$(dirname "$output_file")"
  printf '%s\n' "$markdown_report" > "$output_file"
  echo "memory_promote_report: $output_file"
fi
if [[ -z "$json_output_file" && -z "$output_file" ]]; then
  printf '%s\n' "$markdown_report"
fi
