#!/usr/bin/env bash
set -euo pipefail

show_help() {
  cat <<'HELP'
Usage: scripts/extract-experience.sh --run-id <run-id> [options]

Extract a project-memory experience draft from run evidence.

Options:
  --run-id <run-id>       Run identifier, required
  --output <file>         Write Markdown experience draft to file
  --json-output <file>    Write structured metadata JSON to file
  --promote-to-memory     Generate local memory case draft and index entry proposal; dry-run only
  --memory-output <file>  Write promoted memory case Markdown draft
  --index-entry-output <file>
                         Write proposed memory/index.json case entry
  --ai-model <model>      AI model: llama3 | gpt-4 | none (default: none)
  -h, --help              Show this help

This script is local-only. It reads run evidence and never performs external writes.
HELP
}

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

run_id=""
output_file=""
json_output_file=""
promote_to_memory="false"
memory_output_file=""
index_entry_output_file=""
ai_model="none"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --run-id)
      run_id="${2:-}"; shift 2 ;;
    --output)
      output_file="${2:-}"; shift 2 ;;
    --json-output)
      json_output_file="${2:-}"; shift 2 ;;
    --promote-to-memory)
      promote_to_memory="true"; shift ;;
    --memory-output)
      memory_output_file="${2:-}"; shift 2 ;;
    --index-entry-output)
      index_entry_output_file="${2:-}"; shift 2 ;;
    --ai-model)
      ai_model="${2:-}"; shift 2 ;;
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

run_dir="$ROOT_DIR/runs/$run_id"
if [[ ! -d "$run_dir" ]]; then
  echo "Run directory not found: $run_dir" >&2
  exit 1
fi

if [[ "$ai_model" != "none" ]]; then
  echo "Warning: AI model not implemented yet, using deterministic template" >&2
fi

if [[ "$promote_to_memory" == "true" ]]; then
  if [[ -z "$memory_output_file" ]]; then
    memory_output_file="$run_dir/memory-case-draft.md"
  fi
  if [[ -z "$index_entry_output_file" ]]; then
    index_entry_output_file="$run_dir/memory-index-entry-draft.json"
  fi
fi

json_report="$(python3 - <<'PY' "$run_id" "$run_dir"
import datetime as dt
import json
import re
import sys
from pathlib import Path

run_id, run_dir_text = sys.argv[1:]
run_dir = Path(run_dir_text)
issue_match = re.match(r"^([A-Z]+-[0-9]+)", run_id)
issue = issue_match.group(1) if issue_match else "unknown"

def read_excerpt(path, head=30, tail=15, fallback=""):
    file_path = run_dir / path
    if not file_path.is_file():
        return fallback
    lines = file_path.read_text(encoding="utf-8", errors="replace").splitlines()
    return "\n".join(lines[:head][-tail:]) or fallback

def artifact(path):
    file_path = run_dir / path
    return str(file_path) if file_path.is_file() and file_path.stat().st_size > 0 else None

verification_text = (run_dir / "verification-report.md").read_text(encoding="utf-8", errors="replace") if (run_dir / "verification-report.md").is_file() else ""
passed = [line for line in verification_text.splitlines() if "PASSED" in line][:5]
failed = [line for line in verification_text.splitlines() if "FAILED" in line][:3]
source_artifacts = [value for value in [
    artifact("summary.md"),
    artifact("stage-report.md"),
    artifact("verification-report.md"),
    artifact("evidence-summary.json"),
    artifact("north-star-execution-report.md"),
    artifact("phase-cd-execution-report.md"),
    artifact("organization-policy-report.json"),
    artifact("memory-quality-report.json"),
] if value]
report = {
    "schema_version": 1,
    "generated_at": dt.datetime.now(dt.timezone.utc).replace(microsecond=0).isoformat().replace("+00:00", "Z"),
    "issue": issue,
    "run_id": run_id,
    "review_state": "draft",
    "status": "draft",
    "tags": ["experience", "evidence", "sinan", "project-memory"],
    "source_artifacts": source_artifacts,
    "problem_excerpt": read_excerpt("summary.md", fallback="(未找到 summary.md)"),
    "solution_excerpt": read_excerpt("stage-report.md", fallback="(未找到 stage-report.md)"),
    "what_worked": passed or ["(暂无验证通过项)"],
    "what_failed": failed or ["(暂无验证失败项)"],
    "reusable_patterns": read_excerpt("patch-summary.md", head=20, tail=10, fallback="(未找到 patch-summary 或 commit message)"),
    "human_review_required": True,
    "recommended_memory_path": f"memory/cases/{issue}-experience-draft.md" if issue != "unknown" else "memory/cases/experience-draft.md",
    "recommended_case_id": f"CASE-{issue}-EXPERIENCE-DRAFT" if issue != "unknown" else "CASE-EXPERIENCE-DRAFT",
}
print(json.dumps(report, ensure_ascii=False, indent=2))
PY
)"

markdown_report="$(python3 - <<'PY' "$json_report"
import json
import sys
report = json.loads(sys.argv[1])
print(f"""# 经验提取草稿

## Metadata

- Issue: {report['issue']}
- Run ID: {report['run_id']}
- Review state: {report['review_state']}
- Status: {report['status']}
- Tags: {', '.join(report['tags'])}
- Human review required: {str(report['human_review_required']).lower()}
- Recommended memory path: {report['recommended_memory_path']}

## Source Artifacts
""")
for path in report["source_artifacts"]:
    print(f"- {path}")
print(f"""
## 问题

{report['problem_excerpt']}

## 解决方案

{report['solution_excerpt']}

## 经验教训

### 做对了什么
""")
for item in report["what_worked"]:
    print(item)
print("\n### 踩过的坑\n")
for item in report["what_failed"]:
    print(item)
print(f"""
### 可复用模式

{report['reusable_patterns']}

## 建议补充

请人工复核并补充：

- [ ] 为什么选择这个方案？
- [ ] 有没有其他方案？
- [ ] 下次如何避免踩坑？
- [ ] 这个模式适用于哪些场景？

---

**提取方式**：模板  
**提取时间**：{report['generated_at']}
**需人工复核**：是
""")
PY
)"

if [[ -n "$json_output_file" ]]; then
  mkdir -p "$(dirname "$json_output_file")"
  printf '%s\n' "$json_report" > "$json_output_file"
  echo "experience_json: $json_output_file"
fi

if [[ -n "$output_file" ]]; then
  mkdir -p "$(dirname "$output_file")"
  printf '%s\n' "$markdown_report" > "$output_file"
  echo "experience_draft: $output_file"
fi

if [[ "$promote_to_memory" == "true" ]]; then
  memory_case_report="$(python3 - <<'PY' "$json_report"
import json
import sys
report = json.loads(sys.argv[1])
print(f"""# {report['issue']} 经验草稿

## Metadata

- Case ID: {report['recommended_case_id']}
- Issue: {report['issue']}
- Source run: {report['run_id']}
- Review state: draft
- Status: draft
- Tags: {', '.join(report['tags'])}
- Human review required: true

## Source Artifacts
""")
for path in report["source_artifacts"]:
    print(f"- `{path}`")
print(f"""
## Problem

{report['problem_excerpt']}

## Solution

{report['solution_excerpt']}

## What Worked
""")
for item in report["what_worked"]:
    print(f"- {item}")
print("\n## What Failed\n")
for item in report["what_failed"]:
    print(f"- {item}")
print(f"""
## Reusable Pattern

{report['reusable_patterns']}

## Review Checklist

- [ ] Confirm this belongs in project memory.
- [ ] Rewrite excerpts into durable lessons.
- [ ] Remove transient or sensitive details.
- [ ] Promote review_state with `scripts/memory-review-state.sh` after review.
""")
PY
)"
  index_entry_report="$(python3 - <<'PY' "$json_report"
import json
import sys
report = json.loads(sys.argv[1])
entry = {
    "id": report["recommended_case_id"],
    "issue": report["issue"],
    "title": f"{report['issue']} experience draft",
    "file": report["recommended_memory_path"].replace("memory/", "", 1),
    "tags": report["tags"],
    "review_state": "draft",
    "source_run": report["run_id"],
    "status": "draft",
}
print(json.dumps(entry, ensure_ascii=False, indent=2))
PY
)"
  mkdir -p "$(dirname "$memory_output_file")" "$(dirname "$index_entry_output_file")"
  printf '%s\n' "$memory_case_report" > "$memory_output_file"
  printf '%s\n' "$index_entry_report" > "$index_entry_output_file"
  echo "memory_case_draft: $memory_output_file"
  echo "memory_index_entry_draft: $index_entry_output_file"
  echo "memory_review_command: scripts/memory-review-state.sh --case-id $(python3 - <<'PY' "$json_report"
import json, sys
print(json.loads(sys.argv[1])["recommended_case_id"])
PY
) --from draft --to reviewed"
fi

if [[ -z "$json_output_file" && -z "$output_file" ]]; then
  printf '%s\n' "$markdown_report"
fi
