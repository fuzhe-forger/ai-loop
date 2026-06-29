#!/usr/bin/env bash
set -euo pipefail
show_help(){ cat <<'HELP'
Usage: scripts/sinan-v2-acceptance.sh --run-id <run-id> [--output <file>] [--json-output <file>]

Run local v2.0 acceptance checks. No network, no external writes.
HELP
}
run_id=""; output_file=""; json_output_file=""
while [[ $# -gt 0 ]]; do case "$1" in --run-id) run_id="${2:-}"; shift 2;; --output) output_file="${2:-}"; shift 2;; --json-output) json_output_file="${2:-}"; shift 2;; -h|--help) show_help; exit 0;; *) echo "Unknown argument: $1" >&2; show_help; exit 2;; esac; done
[[ -n "$run_id" ]] || { echo "--run-id required" >&2; show_help; exit 2; }
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"; cd "$ROOT_DIR"
json_report="$(python3 - <<'PY' "$run_id"
import datetime as dt, json, subprocess, sys
from pathlib import Path
run_id=sys.argv[1]
def exists(p): return Path(p).is_file() and Path(p).stat().st_size>0
checks=[
('product_manual', exists('docs/ai-work-orchestration/product/sinan-v1-product-manual.md')),
('roadmap', exists('docs/ai-work-orchestration/product/sinan-v1-to-v2-roadmap.md')),
('onboarding_drill', exists('docs/ai-work-orchestration/product/sinan-onboarding-drill.md')),
('token_efficiency', exists('docs/ai-work-orchestration/29-token-efficiency.md') and exists('scripts/token-efficiency-audit.sh')),
('flow_advisor', exists('scripts/sinan-flow-advisor.sh')),
('ops_dashboard', exists('scripts/sinan-ops-dashboard.sh')),
('multi_repo_evidence', exists('scripts/multi-repo-evidence.sh') and exists('docs/ai-work-orchestration/product/cross-repo-evidence-contract.md')),
('external_adapter_check', exists('scripts/external-adapter-check.sh')),
('v2_gap_audit', exists(f'runs/{run_id}/v2-gap-audit.md')),
('toolchain_verification', exists(f'runs/{run_id}/verification-toolchain-report.md') or exists('scripts/verify-toolchain.sh')),
]
rows=[{'id':n,'status':'PASSED' if ok else 'FAILED'} for n,ok in checks]
result='PASSED' if all(ok for _,ok in checks) else 'FAILED'
print(json.dumps({'schema_version':1,'generated_at':dt.datetime.now(dt.timezone.utc).replace(microsecond=0).isoformat().replace('+00:00','Z'),'run_id':run_id,'result':result,'checks':rows}, ensure_ascii=False, indent=2))
PY
)"
markdown_report="$(python3 - <<'PY' "$json_report"
import json, sys
r=json.loads(sys.argv[1])
print('# Sinan v2.0 Acceptance')
print(); print(f"- Run ID: `{r['run_id']}`"); print(f"- Result: {r['result']}"); print(); print('| Check | Result |'); print('|---|---|')
for c in r['checks']: print(f"| {c['id']} | {c['status']} |")
PY
)"
if [[ -n "$output_file" ]]; then mkdir -p "$(dirname "$output_file")"; printf '%s\n' "$markdown_report" > "$output_file"; echo "v2_acceptance: $output_file"; else printf '%s\n' "$markdown_report"; fi
if [[ -n "$json_output_file" ]]; then mkdir -p "$(dirname "$json_output_file")"; printf '%s\n' "$json_report" > "$json_output_file"; echo "v2_acceptance_json: $json_output_file"; fi
