#!/usr/bin/env bash
set -euo pipefail

show_help() {
  cat <<'HELP'
Usage: scripts/sinan-flow-advisor.sh --task <task-file> [options]

Suggest Sinan flow tier, gates, approvals, estimate bucket, and next minimum
acceptable slice from a local task file. Local-only advisory; never executes work.

Options:
  --task <file>        Task/request file, required
  --output <file>      Optional Markdown output path
  --json-output <file> Optional JSON output path
  -h, --help           Show help
HELP
}

task_file=""
output_file=""
json_output_file=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --task) task_file="${2:-}"; shift 2 ;;
    --output) output_file="${2:-}"; shift 2 ;;
    --json-output) json_output_file="${2:-}"; shift 2 ;;
    -h|--help) show_help; exit 0 ;;
    *) echo "Unknown argument: $1" >&2; show_help; exit 2 ;;
  esac
done
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"
if [[ -z "$task_file" || ! -f "$task_file" ]]; then
  echo "--task must point to an existing file" >&2
  show_help
  exit 2
fi
json_report="$(python3 - <<'PY' "$task_file"
import datetime as dt, json, re, sys
from pathlib import Path
p=Path(sys.argv[1])
text=p.read_text(encoding='utf-8', errors='ignore')
low=text.lower()
side_effect_terms=['飞书','multica','push','deploy','部署','生产','delete','删除','权限','remote','写回']
negative_side_effect_markers=[
    '不执行', '不涉及', '不触发', '不访问', '不调用', '不需要', '禁止', '不得', '无外部', '无需',
    'no ', 'without ', 'never ', 'not ', 'do not ', 'does not ', 'local-only'
]
code_terms=['script','脚本','代码','实现','新增','修改','fix','bug']
doc_terms=['文档','方案','报告','manual','roadmap','docs']
large_terms=['2.0','全部','完整','上百','持续','loop','平台']
def negated(term):
    term_low = term.lower()
    for line in text.splitlines():
        line_low = line.lower()
        idx = line_low.find(term_low)
        if idx < 0:
            continue
        before = line_low[:idx]
        if any(marker in before for marker in negative_side_effect_markers):
            return True
        near = line_low[max(0, idx-24):idx+len(term_low)+24]
        if any(marker in near for marker in negative_side_effect_markers):
            return True
    return False
external=[t for t in side_effect_terms if (t in low or t in text) and not negated(t)]
code=any(t in low or t in text for t in code_terms)
doc=any(t in low or t in text for t in doc_terms)
large=any(t in low or t in text for t in large_terms)
if external:
    tier='L4'
    risk='high'
elif large and code:
    tier='L3'
    risk='medium'
elif code:
    tier='L2'
    risk='medium'
elif doc:
    tier='L1'
    risk='low'
else:
    tier='L1'
    risk='low'
required_gates=['requirement','deliverable']
if tier in ['L2','L3','L4']:
    required_gates.insert(1,'design')
if tier == 'L4':
    required_gates.append('approval-boundary')
estimate={'L1':'5-20m','L2':'20-60m','L3':'60-180m','L4':'requires approval + timebox'}[tier]
flow={
 'L1':['clarify acceptance','edit local docs','verify references','closeout'],
 'L2':['clarify acceptance','design patch','edit local scripts/docs','run targeted tests','closeout'],
 'L3':['split into slices','run preflight','execute one slice','verify','update queue','continue or stop'],
 'L4':['list side effects','request approval','dry-run','execute approved action','readback','closeout'],
}[tier]
report={
 'schema_version':1,
 'generated_at':dt.datetime.now(dt.timezone.utc).replace(microsecond=0).isoformat().replace('+00:00','Z'),
 'task_file':str(p),
 'tier':tier,
 'risk':risk,
 'external_side_effect_terms':external,
 'required_gates':required_gates,
 'estimate_bucket':estimate,
 'recommended_flow':flow,
 'next_minimum_slice': flow[0] if flow else 'clarify acceptance',
 'auto_execute_allowed': tier != 'L4',
 'human_approval_required': tier == 'L4',
 'notes':['Advisory only; human can override.', 'Remote writes/deploy/production always require explicit approval.']
}
print(json.dumps(report, ensure_ascii=False, indent=2))
PY
)"
markdown_report="$(python3 - <<'PY' "$json_report"
import json, sys
r=json.loads(sys.argv[1])
print('# Sinan Flow Advice')
print()
print(f"- Task: `{r['task_file']}`")
print(f"- Tier: {r['tier']}")
print(f"- Risk: {r['risk']}")
print(f"- Estimate: {r['estimate_bucket']}")
print(f"- Human approval required: {r['human_approval_required']}")
print()
print('## Required Gates')
for g in r['required_gates']:
    print(f"- {g}")
print()
print('## Recommended Flow')
for i, step in enumerate(r['recommended_flow'], 1):
    print(f"{i}. {step}")
print()
print('## Next Minimum Slice')
print(r['next_minimum_slice'])
PY
)"
if [[ -n "$output_file" ]]; then mkdir -p "$(dirname "$output_file")"; printf '%s\n' "$markdown_report" > "$output_file"; echo "flow_advice: $output_file"; else printf '%s\n' "$markdown_report"; fi
if [[ -n "$json_output_file" ]]; then mkdir -p "$(dirname "$json_output_file")"; printf '%s\n' "$json_report" > "$json_output_file"; echo "flow_advice_json: $json_output_file"; fi
