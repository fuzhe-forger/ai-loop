#!/usr/bin/env bash
set -euo pipefail
show_help(){ cat <<'HELP'
Usage: scripts/external-adapter-check.sh --target <name> [--schema <file>] [--readback <file>] [--output <file>] [--json-output <file>]

Local-only precheck for external adapter writeback/readback artifacts. Does not call external systems.
HELP
}
target=""; schema=""; readback=""; output_file=""; json_output_file=""
while [[ $# -gt 0 ]]; do case "$1" in --target) target="${2:-}"; shift 2;; --schema) schema="${2:-}"; shift 2;; --readback) readback="${2:-}"; shift 2;; --output) output_file="${2:-}"; shift 2;; --json-output) json_output_file="${2:-}"; shift 2;; -h|--help) show_help; exit 0;; *) echo "Unknown argument: $1" >&2; show_help; exit 2;; esac; done
[[ -n "$target" ]] || { echo "--target required" >&2; show_help; exit 2; }
json_report="$(python3 - <<'PY' "$target" "$schema" "$readback"
import datetime as dt, json, sys
from pathlib import Path
target,schema,readback=sys.argv[1:]
checks=[]
def add(name, ok, detail=''):
    checks.append({'name':name,'status':'PASSED' if ok else 'FAILED','detail':detail})
add('target_present', bool(target), target)
for label,path in [('schema',schema),('readback',readback)]:
    if path:
        p=Path(path); ok=p.is_file(); detail=path
        if ok and p.suffix=='.json':
            try: json.loads(p.read_text()); detail+=' parses'
            except Exception as e: ok=False; detail=str(e)
        add(f'{label}_file', ok, detail)
result='PASSED' if all(c['status']=='PASSED' for c in checks) else 'FAILED'
print(json.dumps({'schema_version':1,'generated_at':dt.datetime.now(dt.timezone.utc).replace(microsecond=0).isoformat().replace('+00:00','Z'),'target':target,'result':result,'checks':checks,'side_effects':'none'}, ensure_ascii=False, indent=2))
PY
)"
markdown_report="$(python3 - <<'PY' "$json_report"
import json, sys
r=json.loads(sys.argv[1])
print('# External Adapter Check')
print(); print(f"- Target: {r['target']}"); print(f"- Result: {r['result']}"); print('- Side effects: none'); print(); print('| Check | Result | Detail |'); print('|---|---|---|')
for c in r['checks']: print(f"| {c['name']} | {c['status']} | {c['detail']} |")
PY
)"
if [[ -n "$output_file" ]]; then mkdir -p "$(dirname "$output_file")"; printf '%s\n' "$markdown_report" > "$output_file"; echo "external_adapter_check: $output_file"; else printf '%s\n' "$markdown_report"; fi
if [[ -n "$json_output_file" ]]; then mkdir -p "$(dirname "$json_output_file")"; printf '%s\n' "$json_report" > "$json_output_file"; echo "external_adapter_check_json: $json_output_file"; fi
