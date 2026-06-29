#!/usr/bin/env bash
set -euo pipefail
show_help(){ cat <<'HELP'
Usage: scripts/sinan-ops-dashboard.sh [--pattern <glob>] [--output <file>] [--json-output <file>]

Generate local ops dashboard from run artifacts: timing, verification, writeback, token audit presence.
HELP
}
pattern="*"; output_file=""; json_output_file=""
while [[ $# -gt 0 ]]; do case "$1" in --pattern) pattern="${2:-}"; shift 2;; --output) output_file="${2:-}"; shift 2;; --json-output) json_output_file="${2:-}"; shift 2;; -h|--help) show_help; exit 0;; *) echo "Unknown argument: $1" >&2; show_help; exit 2;; esac; done
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"; cd "$ROOT_DIR"
json_report="$(python3 - <<'PY' "$pattern"
import datetime as dt, glob, json
from pathlib import Path
pattern='runs/'+__import__('sys').argv[1]
runs=[]
for d in sorted(glob.glob(pattern)):
    p=Path(d)
    if not p.is_dir(): continue
    close=list(p.glob('*close*.json'))+list(p.glob('execution-time-contract*.json'))
    elapsed=[]
    for f in close:
        try:
            j=json.loads(f.read_text())
            v=j.get('elapsed_minutes') or j.get('time_closeout',{}).get('elapsed_minutes')
            if isinstance(v,(int,float)): elapsed.append(float(v))
        except Exception: pass
    runs.append({'run_id':p.name,'files':sum(1 for _ in p.rglob('*') if _.is_file()),'has_verification':(p/'verification-report.md').exists() or bool(list(p.glob('*verification*.md'))),'has_token_audit':(p/'token-efficiency-audit.md').exists() or (p/'token-efficiency-baseline.md').exists(),'elapsed_minutes':elapsed[-1] if elapsed else None})
vals=[r['elapsed_minutes'] for r in runs if r['elapsed_minutes'] is not None]
report={'schema_version':1,'generated_at':dt.datetime.now(dt.timezone.utc).replace(microsecond=0).isoformat().replace('+00:00','Z'),'pattern':pattern,'run_count':len(runs),'timed_run_count':len(vals),'avg_elapsed_minutes':round(sum(vals)/len(vals),1) if vals else None,'verification_count':sum(1 for r in runs if r['has_verification']),'token_audit_count':sum(1 for r in runs if r['has_token_audit']),'runs':runs[-50:]}
print(json.dumps(report, ensure_ascii=False, indent=2))
PY
)"
markdown_report="$(python3 - <<'PY' "$json_report"
import json, sys
r=json.loads(sys.argv[1])
print('# Sinan Ops Dashboard')
print()
print(f"- Pattern: `{r['pattern']}`")
print(f"- Runs: {r['run_count']}")
print(f"- Timed runs: {r['timed_run_count']}")
print(f"- Avg elapsed minutes: {r['avg_elapsed_minutes']}")
print(f"- Verification reports: {r['verification_count']}")
print(f"- Token audit reports: {r['token_audit_count']}")
print()
print('| Run | Files | Timed | Verification | Token audit |')
print('|---|---:|---:|---|---|')
for row in r['runs'][-20:]:
    print(f"| `{row['run_id']}` | {row['files']} | {row['elapsed_minutes']} | {row['has_verification']} | {row['has_token_audit']} |")
PY
)"
if [[ -n "$output_file" ]]; then mkdir -p "$(dirname "$output_file")"; printf '%s\n' "$markdown_report" > "$output_file"; echo "ops_dashboard: $output_file"; else printf '%s\n' "$markdown_report"; fi
if [[ -n "$json_output_file" ]]; then mkdir -p "$(dirname "$json_output_file")"; printf '%s\n' "$json_report" > "$json_output_file"; echo "ops_dashboard_json: $json_output_file"; fi
