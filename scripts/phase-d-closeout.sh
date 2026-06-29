#!/usr/bin/env bash
set -euo pipefail

show_help() {
  cat <<'HELP'
Usage: scripts/phase-d-closeout.sh --run-id <source-run-id> [options]

Generate a local Phase D project-memory closeout package for a run.

Options:
  --run-id <id>        Source run to extract experience from, required
  --output-dir <dir>   Output directory, default runs/<run-id>/phase-d-closeout
  --output <file>      Optional Markdown summary output path
  --json-output <file> Optional JSON summary output path
  -h, --help           Show this help

This script is local-only. It generates draft evidence and does not promote memory.
HELP
}

source_run_id=""
output_dir=""
output_file=""
json_output_file=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --run-id)
      source_run_id="${2:-}"; shift 2 ;;
    --output-dir)
      output_dir="${2:-}"; shift 2 ;;
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

if [[ -z "$source_run_id" ]]; then
  echo "--run-id is required" >&2
  show_help
  exit 2
fi

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

source_run_dir="runs/$source_run_id"
if [[ ! -d "$source_run_dir" ]]; then
  echo "Run directory not found: $source_run_dir" >&2
  exit 1
fi
if [[ -z "$output_dir" ]]; then
  output_dir="$source_run_dir/phase-d-closeout"
fi
mkdir -p "$output_dir"
if [[ -z "$output_file" ]]; then
  output_file="$output_dir/phase-d-closeout.md"
fi
if [[ -z "$json_output_file" ]]; then
  json_output_file="$output_dir/phase-d-closeout.json"
fi

experience_md="$output_dir/experience-draft.md"
experience_json="$output_dir/experience-draft.json"
case_draft="$output_dir/memory-case-draft.md"
index_entry="$output_dir/memory-index-entry-draft.json"
promote_md="$output_dir/memory-promote-dry-run.md"
promote_json="$output_dir/memory-promote-dry-run.json"
quality_md="$output_dir/memory-quality.md"
quality_json="$output_dir/memory-quality.json"

./scripts/extract-experience.sh \
  --run-id "$source_run_id" \
  --output "$experience_md" \
  --json-output "$experience_json" \
  --promote-to-memory \
  --memory-output "$case_draft" \
  --index-entry-output "$index_entry" \
  > "$output_dir/extract-experience.log"

./scripts/memory-promote-draft.sh \
  --case-draft "$case_draft" \
  --index-entry "$index_entry" \
  --output "$promote_md" \
  --json-output "$promote_json" \
  > "$output_dir/memory-promote-dry-run.log"

./scripts/memory-quality-check.sh \
  --output "$quality_md" \
  --json-output "$quality_json" \
  > "$output_dir/memory-quality.log"

json_report="$(python3 - <<'PY' "$source_run_id" "$output_dir" "$experience_json" "$index_entry" "$promote_json" "$quality_json"
import datetime as dt
import json
import sys
from pathlib import Path

source_run_id, output_dir, experience_json, index_entry, promote_json, quality_json = sys.argv[1:]
experience = json.loads(Path(experience_json).read_text(encoding="utf-8"))
entry = json.loads(Path(index_entry).read_text(encoding="utf-8"))
promote = json.loads(Path(promote_json).read_text(encoding="utf-8"))
quality = json.loads(Path(quality_json).read_text(encoding="utf-8"))
review_command = f"scripts/memory-review-state.sh --case-id {entry.get('id')} --from draft --to reviewed"
execute_command = f"scripts/memory-promote-draft.sh --case-draft {Path(output_dir) / 'memory-case-draft.md'} --index-entry {Path(output_dir) / 'memory-index-entry-draft.json'} --execute"
result = "PASSED" if promote.get("result") == "PASSED" and quality.get("result") == "PASSED" else "FAILED"
report = {
    "schema_version": 1,
    "generated_at": dt.datetime.now(dt.timezone.utc).replace(microsecond=0).isoformat().replace("+00:00", "Z"),
    "source_run_id": source_run_id,
    "output_dir": output_dir,
    "case_id": entry.get("id"),
    "case_file": entry.get("file"),
    "review_state": entry.get("review_state"),
    "experience_json": experience_json,
    "memory_case_draft": str(Path(output_dir) / "memory-case-draft.md"),
    "memory_index_entry": index_entry,
    "memory_promote_dry_run": promote_json,
    "memory_quality": quality_json,
    "review_command": review_command,
    "execute_command": execute_command,
    "result": result,
    "side_effects": [],
    "human_review_required": experience.get("human_review_required"),
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
print(f"""# Phase D Project Memory Closeout

## Summary

- Generated at: {report['generated_at']}
- Source run: {report['source_run_id']}
- Output dir: {report['output_dir']}
- Result: {report['result']}
- Side effects: none
- Human review required: {str(report['human_review_required']).lower()}

## Proposed Memory Case

- Case ID: {report['case_id']}
- Case file: {report['case_file']}
- Review state: {report['review_state']}

## Evidence

- Experience JSON: `{report['experience_json']}`
- Memory case draft: `{report['memory_case_draft']}`
- Memory index entry: `{report['memory_index_entry']}`
- Promote dry-run: `{report['memory_promote_dry_run']}`
- Memory quality: `{report['memory_quality']}`

## Next Commands

Review draft first:

```bash
{report['review_command']}
```

Promote only after human review:

```bash
{report['execute_command']}
```
""")
PY
)"

printf '%s\n' "$json_report" > "$json_output_file"
printf '%s\n' "$markdown_report" > "$output_file"
echo "phase_d_closeout_json: $json_output_file"
echo "phase_d_closeout_report: $output_file"
