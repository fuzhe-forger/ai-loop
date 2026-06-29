#!/usr/bin/env bash
set -euo pipefail

show_help() {
  cat <<'HELP'
Usage: scripts/recommend-memory.sh --query <text> [options]

Recommend relevant project memory for a task description.

Options:
  --query <text>        Query text (task description), required
  --memory-dir <dir>    Memory directory (default: memory/)
  --output <file>       Write JSON recommendation to file
  --markdown <file>     Write Markdown recommendation to file
  --limit <n>           Max results total (default: 5)
  --ai-model <model>    AI model: llama3 | gpt-4 | none (default: none)
  -h, --help            Show this help

This script is local-only. It reads memory files and never performs external writes.
HELP
}

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

query=""
memory_dir="$ROOT_DIR/memory"
output_file=""
markdown_file=""
limit=5
ai_model="none"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --query)
      query="${2:-}"; shift 2 ;;
    --memory-dir)
      memory_dir="${2:-}"; shift 2 ;;
    --output)
      output_file="${2:-}"; shift 2 ;;
    --markdown)
      markdown_file="${2:-}"; shift 2 ;;
    --limit)
      limit="${2:-}"; shift 2 ;;
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

if [[ -z "$query" ]]; then
  echo "--query is required" >&2
  show_help
  exit 2
fi
if ! [[ "$limit" =~ ^[0-9]+$ ]] || [[ "$limit" -lt 1 ]]; then
  echo "--limit must be a positive integer" >&2
  exit 2
fi
if [[ "$ai_model" != "none" ]]; then
  echo "Warning: AI model not implemented yet, using deterministic heuristic" >&2
fi

json_report="$(python3 - "$query" "$memory_dir" "$limit" <<'PY'
import datetime as dt
import json
import re
import sys
from pathlib import Path

query, memory_dir, limit_raw = sys.argv[1:]
memory_path = Path(memory_dir)
index_path = memory_path / "index.json"
limit = int(limit_raw)
if not index_path.is_file():
    raise SystemExit(f"Memory index not found: {index_path}")
index = json.loads(index_path.read_text(encoding="utf-8"))

words = [word.lower() for word in re.findall(r"[\w\u4e00-\u9fff]+", query) if len(word) >= 2]
if not words:
    words = [query.lower()]

sections = [
    ("constraints", "constraint"),
    ("decisions", "decision"),
    ("pitfalls", "pitfall"),
    ("preferences", "preference"),
    ("cases", "case"),
    ("templates", "template"),
]
recommendations = []
for array_name, memory_type in sections:
    for entry in index.get(array_name) or []:
        tags = entry.get("tags") or []
        rel_file = entry.get("file") or ""
        abs_file = memory_path / rel_file if rel_file else None
        text_parts = [
            str(entry.get("id") or entry.get("category") or ""),
            str(entry.get("title") or ""),
            str(entry.get("issue") or ""),
            " ".join(str(tag) for tag in tags),
        ]
        file_excerpt = ""
        if abs_file and abs_file.is_file():
            file_text = abs_file.read_text(encoding="utf-8", errors="replace")
            text_parts.append(file_text[:8000])
            for line in file_text.splitlines():
                lower_line = line.lower()
                if any(word in lower_line for word in words):
                    file_excerpt = line.strip()[:220]
                    break
        haystack = "\n".join(text_parts).lower()
        matched = sorted({word for word in words if word in haystack})
        if not matched:
            continue
        tag_hits = [tag for tag in tags if any(word in str(tag).lower() for word in words)]
        title_hit = any(word in str(entry.get("title") or "").lower() for word in words)
        score = min(1.0, 0.35 + 0.18 * len(matched) + 0.12 * len(tag_hits) + (0.15 if title_hit else 0.0))
        ref = entry.get("id") or entry.get("category") or rel_file
        reason_bits = [f"matched: {', '.join(matched[:6])}"]
        if tag_hits:
            reason_bits.append(f"tag hit: {', '.join(tag_hits[:4])}")
        if title_hit:
            reason_bits.append("title hit")
        recommendations.append({
            "type": memory_type,
            "id": ref,
            "title": entry.get("title") or entry.get("category") or ref,
            "confidence": round(score, 2),
            "reason": "; ".join(reason_bits),
            "path": str((Path("memory") / rel_file).as_posix()) if rel_file else None,
            "tags": tags,
            "review_state": entry.get("review_state") or entry.get("status"),
            "excerpt": file_excerpt,
        })

recommendations.sort(key=lambda item: (-item["confidence"], item["type"], str(item["id"])))
recommendations = recommendations[:limit]
report = {
    "schema_version": 1,
    "generated_at": dt.datetime.now(dt.timezone.utc).replace(microsecond=0).isoformat().replace("+00:00", "Z"),
    "query": query,
    "memory_dir": str(memory_path),
    "method": "deterministic_keyword_overlap",
    "limit": limit,
    "recommendations": recommendations,
    "suggested_reading": [item["path"] for item in recommendations if item.get("path")],
    "result": "PASSED",
    "remote_writes": False,
}
print(json.dumps(report, ensure_ascii=False, indent=2))
PY
)"

markdown_report="$(python3 - "$json_report" <<'PY'
import json
import sys
report = json.loads(sys.argv[1])
print(f"""# Project Memory Recommendations

## Summary

- Generated at: {report['generated_at']}
- Query: {report['query']}
- Method: {report['method']}
- Result: {report['result']}
- Remote writes: false

## Recommendations

| Type | ID | Confidence | Reason | Path |
|---|---|---:|---|---|""")
for item in report["recommendations"]:
    reason = str(item.get("reason") or "").replace("|", "-")
    print(f"| {item.get('type')} | {item.get('id')} | {item.get('confidence')} | {reason} | {item.get('path') or ''} |")
if not report["recommendations"]:
    print("| none | none | 0 | no keyword overlap |  |")
PY
)"

if [[ -n "$output_file" ]]; then
  mkdir -p "$(dirname "$output_file")"
  printf '%s\n' "$json_report" > "$output_file"
  echo "memory_recommendations_json: $output_file"
fi
if [[ -n "$markdown_file" ]]; then
  mkdir -p "$(dirname "$markdown_file")"
  printf '%s\n' "$markdown_report" > "$markdown_file"
  echo "memory_recommendations_markdown: $markdown_file"
fi
if [[ -z "$output_file" && -z "$markdown_file" ]]; then
  printf '%s\n' "$json_report"
fi
