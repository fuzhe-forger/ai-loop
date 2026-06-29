#!/usr/bin/env bash
set -euo pipefail

show_help() {
  cat <<'HELP'
Usage: scripts/archive-run-artifacts.sh --run-id <run-id> [options]

List or archive temporary smoke/stale/verify artifacts under a run directory.

Options:
  --run-id <run-id>      Run identifier, required
  --dry-run              Print candidates only, default true
  --apply                Move candidates into runs/<run-id>/archive/tmp-artifacts/
  --output <file>        Optional Markdown report
  --json-output <file>   Optional JSON report
  -h, --help             Show this help

This script is local-only. It never deletes artifacts; --apply moves them into an archive folder.
HELP
}

run_id=""
dry_run="true"
output_file=""
json_output_file=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --run-id) run_id="${2:-}"; shift 2 ;;
    --dry-run) dry_run="true"; shift ;;
    --apply) dry_run="false"; shift ;;
    --output) output_file="${2:-}"; shift 2 ;;
    --json-output) json_output_file="${2:-}"; shift 2 ;;
    -h|--help) show_help; exit 0 ;;
    *) echo "Unknown argument: $1" >&2; show_help; exit 2 ;;
  esac
done

if [[ -z "$run_id" ]]; then
  echo "--run-id is required" >&2
  show_help
  exit 2
fi

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
run_dir="$ROOT_DIR/runs/$run_id"
if [[ ! -d "$run_dir" ]]; then
  echo "Run directory not found: $run_dir" >&2
  exit 1
fi

json_report="$(python3 - "$run_dir" "$run_id" "$dry_run" <<'PY'
import datetime as dt
import json
import shutil
import sys
from pathlib import Path

run_dir = Path(sys.argv[1])
run_id = sys.argv[2]
dry_run = sys.argv[3] == "true"
patterns = [
    "execution-time-contract-verify-*.md",
    "execution-time-contract-verify-*.json",
    "timers/verify-*.start.json",
    "execution-time-contract-verify-stale-*.md",
    "execution-time-contract-verify-stale-*.json",
    "timers/verify-stale-*.start.json",
    "*smoke*.tmp",
]
candidates = []
for pattern in patterns:
    for path in sorted(run_dir.glob(pattern)):
        if path.is_file():
            candidates.append(path)
archive_dir = run_dir / "archive" / "tmp-artifacts"
moved = []
if not dry_run and candidates:
    archive_dir.mkdir(parents=True, exist_ok=True)
    for path in candidates:
        target = archive_dir / path.relative_to(run_dir).as_posix().replace("/", "__")
        shutil.move(str(path), str(target))
        moved.append(str(target.relative_to(run_dir)))
report = {
    "schema_version": 1,
    "generated_at": dt.datetime.now(dt.timezone.utc).replace(microsecond=0).isoformat().replace("+00:00", "Z"),
    "run_id": run_id,
    "dry_run": dry_run,
    "candidate_count": len(candidates),
    "candidates": [str(path.relative_to(run_dir)) for path in candidates],
    "archive_dir": str(archive_dir.relative_to(run_dir)),
    "moved": moved,
    "result": "PASSED",
}
print(json.dumps(report, ensure_ascii=False, indent=2))
PY
)"

markdown_report="$(python3 - "$json_report" <<'PY'
import json
import sys
report = json.loads(sys.argv[1])
items = "\n".join(f"- {item}" for item in report["candidates"]) or "- none"
moved = "\n".join(f"- {item}" for item in report["moved"]) or "- none"
print(f"""# Archive Run Artifacts

## Summary

- Result: {report['result']}
- Run ID: {report['run_id']}
- Dry run: {str(report['dry_run']).lower()}
- Candidate count: {report['candidate_count']}
- Archive dir: {report['archive_dir']}

## Candidates

{items}

## Moved

{moved}
""")
PY
)"

if [[ -n "$json_output_file" ]]; then
  mkdir -p "$(dirname "$json_output_file")"
  printf '%s\n' "$json_report" > "$json_output_file"
  echo "archive_json: $json_output_file"
fi
if [[ -n "$output_file" ]]; then
  mkdir -p "$(dirname "$output_file")"
  printf '%s\n' "$markdown_report" > "$output_file"
  echo "archive_report: $output_file"
fi
if [[ -z "$output_file" && -z "$json_output_file" ]]; then
  printf '%s\n' "$markdown_report"
fi
