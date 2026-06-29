#!/usr/bin/env bash
set -euo pipefail

show_help() {
  cat <<'HELP'
Usage: scripts/sinan-doctor.sh [options]

Run local Sinan onboarding readiness checks. No network, no external writes.

Options:
  --run-id <run-id>    Optional run id; defaults outputs under runs/<run-id>/
  --output <file>      Optional Markdown output path
  --json-output <file> Optional JSON output path
  -h, --help           Show this help

Checks include local entrypoints, JSON config parsing, unified CLI commands,
skill files, onboarding docs, capability registry health, and memory quality.
HELP
}

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
run_id=""
output_file=""
json_output_file=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --run-id)
      run_id="${2:-}"; shift 2 ;;
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

tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT

if [[ -n "$run_id" ]]; then
  artifacts_dir="runs/$run_id/sinan-doctor"
  mkdir -p "$artifacts_dir"
  [[ -n "$output_file" ]] || output_file="runs/$run_id/sinan-doctor.md"
  [[ -n "$json_output_file" ]] || json_output_file="runs/$run_id/sinan-doctor.json"
else
  artifacts_dir="$tmp_dir/sinan-doctor"
  mkdir -p "$artifacts_dir"
fi

capability_md="$artifacts_dir/capability-check.md"
capability_json="$artifacts_dir/capability-check.json"
memory_md="$artifacts_dir/memory-quality.md"
memory_json="$artifacts_dir/memory-quality.json"
help_output="$artifacts_dir/sinan-help.txt"

capability_exit=0
if "$ROOT_DIR/scripts/sinan-capability-check.sh" \
  --output "$capability_md" \
  --json-output "$capability_json" \
  > "$artifacts_dir/capability-check.stdout" \
  2> "$artifacts_dir/capability-check.stderr"; then
  capability_exit=0
else
  capability_exit=$?
fi

memory_exit=0
if "$ROOT_DIR/scripts/memory-quality-check.sh" \
  --output "$memory_md" \
  --json-output "$memory_json" \
  > "$artifacts_dir/memory-quality.stdout" \
  2> "$artifacts_dir/memory-quality.stderr"; then
  memory_exit=0
else
  memory_exit=$?
fi

help_exit=0
if "$ROOT_DIR/scripts/sinan.sh" help > "$help_output" 2> "$artifacts_dir/sinan-help.stderr"; then
  help_exit=0
else
  help_exit=$?
fi

json_report="$(python3 - <<'PY' "$ROOT_DIR" "$run_id" "$capability_json" "$capability_exit" "$memory_json" "$memory_exit" "$help_output" "$help_exit"
import datetime as dt
import json
import os
import shutil
import sys
from pathlib import Path

root = Path(sys.argv[1])
run_id = sys.argv[2]
capability_json = Path(sys.argv[3])
capability_exit = int(sys.argv[4])
memory_json = Path(sys.argv[5])
memory_exit = int(sys.argv[6])
help_output = Path(sys.argv[7])
help_exit = int(sys.argv[8])

checks = []

def add(name, ok, detail="", category="readiness"):
    checks.append({
        "category": category,
        "name": name,
        "status": "PASSED" if ok else "FAILED",
        "detail": detail,
    })

def load_json(path):
    try:
        return json.loads(path.read_text(encoding="utf-8")), ""
    except Exception as exc:
        return None, str(exc)

add("repo_root", (root / ".git").is_dir(), str(root), "environment")
add("bash_available", bool(shutil.which("bash")), shutil.which("bash") or "missing", "environment")
add("python3_available", bool(shutil.which("python3")), shutil.which("python3") or "missing", "environment")
add(
    "side_effect_boundary",
    True,
    "local reads plus report artifacts only; no network, remote Git, deploy, delete, or permission change",
    "safety",
)
add(
    "external_credentials_required",
    True,
    "none; Feishu/Multica/Git remote credentials are not required for this doctor",
    "safety",
)

core_scripts = [
    "scripts/sinan.sh",
    "scripts/sinan-capability-check.sh",
    "scripts/sinan-v2-acceptance.sh",
    "scripts/sinan-flow-advisor.sh",
    "scripts/sinan-ops-dashboard.sh",
    "scripts/token-efficiency-audit.sh",
    "scripts/execution-timer.sh",
    "scripts/loop-execution-preflight.sh",
    "scripts/writeback-gate.sh",
    "scripts/collect-evidence.sh",
    "scripts/verify-toolchain.sh",
    "scripts/memory-quality-check.sh",
    "scripts/memory-query.sh",
    "scripts/recommend-memory.sh",
    "scripts/extract-experience.sh",
    "scripts/memory-review-state.sh",
    "scripts/memory-promote-draft.sh",
    "scripts/phase-d-closeout.sh",
    "scripts/phase-d-closeout-check.sh",
    "scripts/sinan-doctor.sh",
]
missing_scripts = [path for path in core_scripts if not (root / path).is_file()]
not_executable = [path for path in core_scripts if (root / path).is_file() and not os.access(root / path, os.X_OK)]
add("core_scripts_exist", not missing_scripts, ", ".join(missing_scripts), "entrypoints")
add("core_scripts_executable", not not_executable, ", ".join(not_executable), "entrypoints")

help_text = help_output.read_text(encoding="utf-8") if help_output.is_file() else ""
required_commands = [
    "capability-check",
    "fitness-check",
    "flow-advisor",
    "doctor",
    "memory-promote-draft",
    "memory-review-state",
    "token-audit",
    "ops-dashboard",
    "phase-d-closeout",
    "phase-d-closeout-check",
    "v2-acceptance",
]
missing_commands = [cmd for cmd in required_commands if cmd not in help_text]
add("sinan_help_runs", help_exit == 0, f"exit={help_exit}", "entrypoints")
add("sinan_subcommands_listed", not missing_commands, ", ".join(missing_commands), "entrypoints")

json_paths = sorted((root / "config").glob("*.json"))
memory_index = root / "memory/index.json"
if memory_index.is_file():
    json_paths.append(memory_index)
invalid_json = []
for path in json_paths:
    try:
        json.loads(path.read_text(encoding="utf-8"))
    except Exception as exc:
        invalid_json.append(f"{path.relative_to(root)}: {exc}")
add("json_files_parse", not invalid_json, f"checked={len(json_paths)}" if not invalid_json else "; ".join(invalid_json), "configs")

skill_files = [
    "/home/user/.codex/skills/sinan/SKILL.md",
    "/home/user/.codex/skills/ponytail-cn/SKILL.md",
    "/home/user/AGENTS.md",
    "/home/user/.codex/RTK.md",
]
missing_skills = [path for path in skill_files if not Path(path).is_file()]
add("local_skill_files_present", not missing_skills, ", ".join(missing_skills), "skills")

docs = [
    "docs/ai-work-orchestration/README.md",
    "docs/ai-work-orchestration/product/sinan-v1-product-manual.md",
    "docs/ai-work-orchestration/product/sinan-onboarding-drill.md",
]
missing_docs = [path for path in docs if not (root / path).is_file()]
add("onboarding_docs_present", not missing_docs, ", ".join(missing_docs), "docs")

capability_report, capability_error = load_json(capability_json)
capability_result = capability_report.get("result") if isinstance(capability_report, dict) else None
add(
    "capability_registry_check",
    capability_exit == 0 and capability_result == "PASSED",
    f"exit={capability_exit}, result={capability_result or capability_error}",
    "validation",
)

memory_report, memory_error = load_json(memory_json)
memory_result = memory_report.get("result") if isinstance(memory_report, dict) else None
add(
    "memory_quality_check",
    memory_exit == 0 and memory_result == "PASSED",
    f"exit={memory_exit}, result={memory_result or memory_error}",
    "validation",
)

failed = [check for check in checks if check["status"] != "PASSED"]
report = {
    "schema_version": 1,
    "generated_at": dt.datetime.now(dt.timezone.utc).replace(microsecond=0).isoformat().replace("+00:00", "Z"),
    "run_id": run_id or None,
    "result": "PASSED" if not failed else "FAILED",
    "failed_checks": len(failed),
    "side_effects": "local-only report artifacts; no external calls or writes",
    "required_external_credentials": [],
    "artifacts": {
        "capability_check_json": str(capability_json),
        "memory_quality_json": str(memory_json),
        "sinan_help": str(help_output),
    },
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

print("# Sinan Doctor")
print()
print(f"- Run ID: `{report.get('run_id') or 'n/a'}`")
print(f"- Result: {report['result']}")
print(f"- Failed checks: {report['failed_checks']}")
print(f"- Side effects: {report['side_effects']}")
print("- Required external credentials: none")
print()
print("## Checks")
print()
print("| Category | Check | Result | Detail |")
print("|---|---|---|---|")
for check in report["checks"]:
    print(
        f"| {md_cell(check['category'])} | {md_cell(check['name'])} | "
        f"{md_cell(check['status'])} | {md_cell(check.get('detail', ''))} |"
    )
print()
print("## Artifacts")
print()
for name, path in report["artifacts"].items():
    print(f"- `{name}`: `{path}`")
PY
)"

if [[ -n "$output_file" ]]; then
  mkdir -p "$(dirname "$output_file")"
  printf '%s\n' "$markdown_report" > "$output_file"
  echo "sinan_doctor: $output_file"
else
  printf '%s\n' "$markdown_report"
fi

if [[ -n "$json_output_file" ]]; then
  mkdir -p "$(dirname "$json_output_file")"
  printf '%s\n' "$json_report" > "$json_output_file"
  echo "sinan_doctor_json: $json_output_file"
fi

result="$(python3 - <<'PY' "$json_report"
import json
import sys
print(json.loads(sys.argv[1])["result"])
PY
)"
[[ "$result" == "PASSED" ]]
