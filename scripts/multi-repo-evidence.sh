#!/usr/bin/env bash
set -euo pipefail

show_help() {
  cat <<'HELP'
Usage: scripts/multi-repo-evidence.sh --run-id <run-id> --repo <path> [--repo <path> ...] [options]

Collect local-only cross-repo evidence: path, branch, HEAD, status, changed files.
Never fetches, pushes, or modifies repos.

Options:
  --run-id <run-id>      Run id for report metadata, required
  --repo <path>          Repo path, repeatable
  --output <file>        Optional Markdown output
  --json-output <file>   Optional JSON output
  -h, --help             Show help
HELP
}
run_id=""; output_file=""; json_output_file=""; repos=()
while [[ $# -gt 0 ]]; do
  case "$1" in
    --run-id) run_id="${2:-}"; shift 2 ;;
    --repo) repos+=("${2:-}"); shift 2 ;;
    --output) output_file="${2:-}"; shift 2 ;;
    --json-output) json_output_file="${2:-}"; shift 2 ;;
    -h|--help) show_help; exit 0 ;;
    *) echo "Unknown argument: $1" >&2; show_help; exit 2 ;;
  esac
done
if [[ -z "$run_id" || ${#repos[@]} -eq 0 ]]; then echo "--run-id and at least one --repo are required" >&2; show_help; exit 2; fi
json_report="$(python3 - <<'PY' "$run_id" "${repos[@]}"
import datetime as dt, json, subprocess, sys
from pathlib import Path
run_id=sys.argv[1]; repos=sys.argv[2:]
def git(repo,*args):
    try: return subprocess.check_output(['git','-C',repo,*args], text=True, stderr=subprocess.DEVNULL).strip()
    except Exception: return ''
rows=[]
for repo in repos:
    p=Path(repo).expanduser().resolve()
    is_git=(p/'.git').exists() or bool(git(str(p),'rev-parse','--git-dir'))
    branch=git(str(p),'branch','--show-current') if is_git else ''
    head=git(str(p),'rev-parse','--short','HEAD') if is_git else ''
    status=git(str(p),'status','--short') if is_git else ''
    changed=[line[3:] if len(line)>3 else line for line in status.splitlines() if line.strip()]
    rows.append({'name':p.name,'path':str(p),'is_git':is_git,'branch':branch,'git_head':head,'status_short':status,'changed_files':changed,'verification':[],'side_effects':'local-only'})
report={'schema_version':1,'run_id':run_id,'generated_at':dt.datetime.now(dt.timezone.utc).replace(microsecond=0).isoformat().replace('+00:00','Z'),'repos':rows,'approval_required':False,'notes':['local-only inventory; no fetch/push/deploy performed']}
print(json.dumps(report, ensure_ascii=False, indent=2))
PY
)"
markdown_report="$(python3 - <<'PY' "$json_report"
import json, sys
r=json.loads(sys.argv[1])
print('# Multi-repo Evidence')
print()
print(f"- Run ID: `{r['run_id']}`")
print(f"- Approval required: {r['approval_required']}")
print()
print('| Repo | Path | Git | Branch | HEAD | Changed files |')
print('|---|---|---|---|---|---:|')
for repo in r['repos']:
    print(f"| {repo['name']} | `{repo['path']}` | {repo['is_git']} | {repo['branch']} | {repo['git_head']} | {len(repo['changed_files'])} |")
PY
)"
if [[ -n "$output_file" ]]; then mkdir -p "$(dirname "$output_file")"; printf '%s\n' "$markdown_report" > "$output_file"; echo "multi_repo_evidence: $output_file"; else printf '%s\n' "$markdown_report"; fi
if [[ -n "$json_output_file" ]]; then mkdir -p "$(dirname "$json_output_file")"; printf '%s\n' "$json_report" > "$json_output_file"; echo "multi_repo_evidence_json: $json_output_file"; fi
