#!/usr/bin/env bash
set -euo pipefail

show_help() {
  cat <<'HELP'
Usage: scripts/token-efficiency-audit.sh --run-id <run-id> [options]

Audit local run artifacts for token-efficiency risks: large files, readback/fetch
snapshots, repeated paths/headings, and missing canonical summaries.

Options:
  --run-id <run-id>       Run directory under runs/, required unless --path used
  --path <dir>            Directory to audit, default runs/<run-id>
  --large-threshold <n>   Large file threshold in bytes, default 12000
  --output <file>         Optional Markdown output path
  --json-output <file>    Optional JSON output path
  -h, --help              Show help

Local-only. No network, no remote writes.
HELP
}

run_id=""
audit_path=""
large_threshold=12000
output_file=""
json_output_file=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --run-id) run_id="${2:-}"; shift 2 ;;
    --path) audit_path="${2:-}"; shift 2 ;;
    --large-threshold) large_threshold="${2:-}"; shift 2 ;;
    --output) output_file="${2:-}"; shift 2 ;;
    --json-output) json_output_file="${2:-}"; shift 2 ;;
    -h|--help) show_help; exit 0 ;;
    *) echo "Unknown argument: $1" >&2; show_help; exit 2 ;;
  esac
done

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

if [[ -z "$audit_path" ]]; then
  if [[ -z "$run_id" ]]; then
    echo "--run-id or --path is required" >&2
    show_help
    exit 2
  fi
  audit_path="runs/$run_id"
fi
if [[ ! -d "$audit_path" ]]; then
  echo "Audit path not found: $audit_path" >&2
  exit 1
fi

json_report="$(python3 - <<'PY' "$audit_path" "$large_threshold" "$run_id"
import datetime as dt
import json
import re
import sys
from pathlib import Path

audit_path = Path(sys.argv[1])
threshold = int(sys.argv[2])
run_id = sys.argv[3]
path_re = re.compile(r'(?:runs|docs|scripts|config|memory|tasks)/[A-Za-z0-9_./#:@%+=,-]+')
heading_re = re.compile(r'^(#{1,6})\s+(.+)$', re.M)
large = []
readbacks = []
repeated_paths = []
repeated_headings = []
files = []
for file in audit_path.rglob('*'):
    if not file.is_file():
        continue
    rel = str(file)
    size = file.stat().st_size
    files.append({'path': rel, 'size': size})
    if size >= threshold:
        large.append({'path': rel, 'size': size})
    lname = file.name.lower()
    if any(k in lname for k in ['readback', 'fetch', 'after']):
        readbacks.append({'path': rel, 'size': size})
    if file.suffix.lower() in {'.md', '.json', '.txt', '.log'} and size <= 200000:
        text = file.read_text(encoding='utf-8', errors='ignore')
        path_counts = {}
        for p in path_re.findall(text):
            path_counts[p] = path_counts.get(p, 0) + 1
        for p, count in path_counts.items():
            if count >= 6:
                repeated_paths.append({'file': rel, 'path': p, 'count': count})
        heading_counts = {}
        for _, h in heading_re.findall(text):
            heading_counts[h] = heading_counts.get(h, 0) + 1
        for h, count in heading_counts.items():
            if count >= 3:
                repeated_headings.append({'file': rel, 'heading': h, 'count': count})
files.sort(key=lambda x: x['size'], reverse=True)
large.sort(key=lambda x: x['size'], reverse=True)
readbacks.sort(key=lambda x: x['size'], reverse=True)
score = 100
score -= min(40, len(large) * 3)
score -= min(25, len(readbacks) * 2)
score -= min(20, len(repeated_paths))
score -= min(15, len(repeated_headings))
score = max(score, 0)
result = 'PASSED' if score >= 70 else 'WARN' if score >= 45 else 'FAILED'
report = {
    'schema_version': 1,
    'generated_at': dt.datetime.now(dt.timezone.utc).replace(microsecond=0).isoformat().replace('+00:00','Z'),
    'run_id': run_id,
    'audit_path': str(audit_path),
    'large_threshold': threshold,
    'file_count': len(files),
    'total_bytes': sum(item['size'] for item in files),
    'score': score,
    'result': result,
    'large_files': large[:50],
    'readback_like_files': readbacks[:50],
    'repeated_paths': repeated_paths[:50],
    'repeated_headings': repeated_headings[:50],
    'top_files': files[:20],
    'recommendations': [
        'Use rg/headings before reading files over threshold.',
        'Summarize readback/fetch JSON before loading details.',
        'Prefer evidence path references over full copies.',
        'Mark canonical snapshot in closeout for repeated external snapshots.'
    ]
}
print(json.dumps(report, ensure_ascii=False, indent=2))
PY
)"

markdown_report="$(python3 - <<'PY' "$json_report"
import json, sys
r=json.loads(sys.argv[1])
print('# Token Efficiency Audit')
print()
print(f"- Run ID: `{r.get('run_id') or '-'}`")
print(f"- Path: `{r['audit_path']}`")
print(f"- Result: {r['result']}")
print(f"- Score: {r['score']}")
print(f"- Files: {r['file_count']}")
print(f"- Total bytes: {r['total_bytes']}")
print()
print('## Top Files')
for item in r['top_files'][:10]:
    print(f"- `{item['path']}`: {item['size']} bytes")
print()
print('## Large Files')
for item in r['large_files'][:10]:
    print(f"- `{item['path']}`: {item['size']} bytes")
print()
print('## Readback/Fetch-like Files')
for item in r['readback_like_files'][:10]:
    print(f"- `{item['path']}`: {item['size']} bytes")
print()
print('## Repeated Paths')
for item in r['repeated_paths'][:10]:
    print(f"- `{item['path']}` in `{item['file']}`: {item['count']} times")
print()
print('## Recommendations')
for item in r['recommendations']:
    print(f"- {item}")
PY
)"

if [[ -n "$output_file" ]]; then
  mkdir -p "$(dirname "$output_file")"
  printf '%s\n' "$markdown_report" > "$output_file"
  echo "token_efficiency_audit: $output_file"
else
  printf '%s\n' "$markdown_report"
fi
if [[ -n "$json_output_file" ]]; then
  mkdir -p "$(dirname "$json_output_file")"
  printf '%s\n' "$json_report" > "$json_output_file"
  echo "token_efficiency_audit_json: $json_output_file"
fi
