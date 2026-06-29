#!/usr/bin/env bash
set -euo pipefail

show_help() {
  cat <<'HELP'
Usage: scripts/sinan-capability-check.sh [options]

Validate the Sinan capability registry and optionally emit a Markdown summary.

Options:
  --registry <file>     Capability registry path, default config/sinan-capabilities.json
  --output <file>       Optional Markdown output path
  --json-output <file>  Optional JSON output path
  -h, --help            Show this help

This script is local-only. It reads files in the repository and never performs remote writes.
HELP
}

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
registry="config/sinan-capabilities.json"
output_file=""
json_output_file=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --registry)
      registry="${2:-}"; shift 2 ;;
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

cd "$ROOT_DIR"

json_report="$(python3 - <<'PY' "$registry"
import datetime as dt
import json
import sys
from pathlib import Path

registry_path = Path(sys.argv[1])
errors = []
checks = []

def add(name, status, detail=""):
    checks.append({"name": name, "status": status, "detail": detail})
    if status != "PASSED":
        errors.append(f"{name}: {detail}")

if not registry_path.is_file():
    raise SystemExit(f"Registry not found: {registry_path}")
try:
    registry = json.loads(registry_path.read_text(encoding="utf-8"))
except json.JSONDecodeError as exc:
    raise SystemExit(f"Invalid registry JSON: {exc}")

capabilities = registry.get("capabilities")
add("schema_version", "PASSED" if registry.get("schema_version") == 1 else "FAILED", str(registry.get("schema_version")))
add("capabilities_array", "PASSED" if isinstance(capabilities, list) and capabilities else "FAILED", "non-empty list required")

seen_ids = set()
rows = []
required_fields = ["id", "name", "status", "entrypoints", "evidence_outputs", "docs", "verification", "side_effect_policy"]
for item in capabilities or []:
    cap_id = item.get("id", "")
    prefix = f"capability:{cap_id or '<missing>'}"
    missing_fields = [field for field in required_fields if field not in item or item.get(field) in (None, "", [])]
    if "entrypoints" in missing_fields and item.get("external_tools"):
        missing_fields.remove("entrypoints")
    add(f"{prefix}:required_fields", "PASSED" if not missing_fields else "FAILED", ", ".join(missing_fields))
    add(f"{prefix}:unique_id", "PASSED" if cap_id and cap_id not in seen_ids else "FAILED", cap_id)
    if cap_id:
        seen_ids.add(cap_id)
    entrypoints = item.get("entrypoints") or []
    external_tools = item.get("external_tools") or []
    docs = item.get("docs") or []
    configs = item.get("configs") or []
    entry_missing = [path for path in entrypoints if not Path(path).is_file()]
    docs_missing = [path for path in docs if not Path(path).is_file()]
    configs_missing = [path for path in configs if not Path(path).is_file()]
    external_missing = []
    for path in external_tools:
        expanded = Path(path).expanduser()
        if not expanded.exists():
            external_missing.append(path)
    add(f"{prefix}:entrypoints_exist", "PASSED" if not entry_missing else "FAILED", ", ".join(entry_missing))
    add(f"{prefix}:external_tools_exist", "PASSED" if not external_missing else "FAILED", ", ".join(external_missing))
    add(f"{prefix}:docs_exist", "PASSED" if not docs_missing else "FAILED", ", ".join(docs_missing))
    add(f"{prefix}:configs_exist", "PASSED" if not configs_missing else "FAILED", ", ".join(configs_missing))
    rows.append({
        "id": cap_id,
        "name": item.get("name"),
        "status": item.get("status"),
        "phase": item.get("phase"),
        "entrypoints": entrypoints,
        "external_tools": external_tools,
        "configs": configs,
        "evidence_outputs": item.get("evidence_outputs") or [],
        "verification": item.get("verification") or [],
        "docs": docs,
        "side_effect_policy": item.get("side_effect_policy"),
    })

failed_checks = [check for check in checks if check["status"] != "PASSED"]
report = {
    "schema_version": 1,
    "generated_at": dt.datetime.now(dt.timezone.utc).replace(microsecond=0).isoformat().replace("+00:00", "Z"),
    "registry": str(registry_path),
    "capability_count": len(capabilities or []),
    "failed_checks": len(failed_checks),
    "result": "PASSED" if not failed_checks else "FAILED",
    "checks": checks,
    "capabilities": rows,
}
print(json.dumps(report, ensure_ascii=False, indent=2))
PY
)"

markdown_report="$(python3 - <<'PY' "$json_report"
import json
import sys
report = json.loads(sys.argv[1])
def md_cell(value):
    text = str(value or "")
    return text.replace("|", "-").replace("<", "&lt;").replace(">", "&gt;")
def md_list(values):
    return "<br>".join(md_cell(value) for value in (values or []))
print(f"""# Sinan Capability Check

## Summary

- Generated at: {report['generated_at']}
- Registry: {report['registry']}
- Capability count: {report['capability_count']}
- Failed checks: {report['failed_checks']}
- Result: {report['result']}

## Capabilities

| ID | Name | Status | Phase | Entrypoints | Configs | Evidence Outputs | External Tools | Verification | Docs |
|---|---|---|---|---|---|---|---|---|---|""")
for item in report["capabilities"]:
    entrypoints = md_list(item.get("entrypoints") or [])
    configs = md_list(item.get("configs") or [])
    evidence_outputs = md_list(item.get("evidence_outputs") or [])
    external_tools = md_list(item.get("external_tools") or [])
    verification = md_list(item.get("verification") or [])
    docs = md_list(item.get("docs") or [])
    print(f"| {md_cell(item.get('id'))} | {md_cell(item.get('name'))} | {md_cell(item.get('status'))} | {md_cell(item.get('phase') or '')} | {entrypoints} | {configs} | {evidence_outputs} | {external_tools} | {verification} | {docs} |")
print("\n## Failed Checks\n")
failed = [check for check in report["checks"] if check["status"] != "PASSED"]
if failed:
    for check in failed:
        print(f"- {check['name']}: {check.get('detail') or 'failed'}")
else:
    print("- none")
PY
)"

if [[ -n "$json_output_file" ]]; then
  mkdir -p "$(dirname "$json_output_file")"
  printf '%s\n' "$json_report" > "$json_output_file"
  echo "capability_json: $json_output_file"
fi
if [[ -n "$output_file" ]]; then
  mkdir -p "$(dirname "$output_file")"
  printf '%s\n' "$markdown_report" > "$output_file"
  echo "capability_report: $output_file"
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
