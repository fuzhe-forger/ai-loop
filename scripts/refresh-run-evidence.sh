#!/usr/bin/env bash
set -euo pipefail

show_help() {
  cat <<'HELP'
Usage: scripts/refresh-run-evidence.sh --pattern <glob> [--issue <issue-id>] [--task-type <type>] [--skip-gate-policy] [--strict-gate-policy] [--output <file>]

Refresh local state evaluation, metadata draft, and gate-policy artifacts for matching run directories.

Options:
  --pattern  Glob pattern under runs/, for example 'FUZ-554*', required
  --issue    Optional issue identifier, for example FUZ-554
  --task-type
             Optional task type override for all matched runs
  --skip-gate-policy
             Do not generate gate-policy-check.md/json
  --strict-gate-policy
             Exit non-zero if any generated gate policy check fails
  --output   Optional Markdown report path
  -h, --help Show this help

This script is local-only. It writes only under matching runs/ directories and never writes Multica.
HELP
}

pattern=""
issue=""
output=""
task_type=""
gate_policy="true"
strict_gate_policy="false"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --pattern)
      pattern="${2:-}"; shift 2 ;;
    --issue)
      issue="${2:-}"; shift 2 ;;
    --task-type)
      task_type="${2:-}"; shift 2 ;;
    --skip-gate-policy)
      gate_policy="false"; shift ;;
    --strict-gate-policy)
      strict_gate_policy="true"; shift ;;
    --output)
      output="${2:-}"; shift 2 ;;
    -h|--help)
      show_help; exit 0 ;;
    *)
      echo "Unknown argument: $1" >&2
      show_help
      exit 2 ;;
  esac
done

if [[ -z "$pattern" ]]; then
  echo "--pattern is required" >&2
  show_help
  exit 2
fi

shopt -s nullglob
run_dirs=(runs/$pattern)
shopt -u nullglob

if [[ ${#run_dirs[@]} -eq 0 ]]; then
  echo "No run directories matched: runs/$pattern" >&2
  exit 1
fi

generated_at="$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
rows="| Run | State | Metadata | Gate Policy | Suggested State | Remote Write Done |
|---|---|---|---|---|---|
"
refreshed_count=0
gate_policy_fail_count=0

for run_dir in "${run_dirs[@]}"; do
  if [[ ! -d "$run_dir" ]]; then
    continue
  fi
  run_id="$(basename "$run_dir")"
  run_issue="$issue"
  if [[ -z "$run_issue" ]]; then
    run_issue="$(printf '%s\n' "$run_id" | grep -Eo '^[A-Z]+-[0-9]+' || true)"
    if [[ ! "$run_issue" =~ ^[A-Z]+-[0-9]+$ ]]; then
      run_issue="unknown"
    fi
  fi

  gate_policy_status="SKIPPED"
  if [[ "$gate_policy" == "true" ]]; then
    gate_policy_args=(
      --issue "$run_issue"
      --run-id "$run_id"
      --output "$run_dir/gate-policy-check.md"
      --json-output "$run_dir/gate-policy-check.json"
    )
    if [[ -n "$task_type" ]]; then
      gate_policy_args+=(--task-type "$task_type")
    elif [[ -s "$run_dir/classification.json" ]]; then
      gate_policy_args+=(--classification "$run_dir/classification.json")
    fi

    set +e
    ./scripts/gate-policy-check.sh "${gate_policy_args[@]}" >/dev/null 2>"$run_dir/gate-policy-check.err"
    gate_policy_exit=$?
    set -e
    if [[ "$gate_policy_exit" -eq 0 ]]; then
      gate_policy_status="PASSED"
      rm -f "$run_dir/gate-policy-check.err"
    else
      gate_policy_status="FAILED"
      gate_policy_fail_count=$((gate_policy_fail_count + 1))
    fi
	fi

	if [[ -s "$run_dir/writeback-summary.md" ]]; then
	  ./scripts/writeback-summary-json.sh \
	    --issue "$run_issue" \
	    --run-id "$run_id" \
	    --output "$run_dir/writeback-summary.json" >/dev/null || true
	fi

	./scripts/evaluate-state.sh --issue "$run_issue" --run-id "$run_id" --write-run >/dev/null
	./scripts/metadata-draft.sh \
    --issue "$run_issue" \
    --run-id "$run_id" \
    --output "$run_dir/metadata-draft.json" \
    --markdown "$run_dir/metadata-draft.md" >/dev/null

  suggested_state="$(python3 - <<'PY' "$run_dir/state-evaluation.json"
import json
import sys
with open(sys.argv[1], encoding="utf-8") as fh:
    data = json.load(fh)
print(data.get("to") or "unknown")
PY
)"
  remote_write_done="$(python3 - <<'PY' "$run_dir/state-evaluation.json"
import json
import sys
with open(sys.argv[1], encoding="utf-8") as fh:
    data = json.load(fh)
print(data.get("checks", {}).get("remote_write_completed") or "unknown")
PY
)"

  refreshed_count=$((refreshed_count + 1))
  rows+="| ${run_id} | yes | yes | ${gate_policy_status} | ${suggested_state} | ${remote_write_done} |
"
done

report="# Run Evidence Refresh

## Metadata

- Generated at: ${generated_at}
- Pattern: runs/${pattern}
- Issue override: ${issue:-none}
- Task type override: ${task_type:-none}
- Gate policy generated: ${gate_policy}
- Strict gate policy: ${strict_gate_policy}
- Gate policy failures: ${gate_policy_fail_count}
- Refreshed runs: ${refreshed_count}
- Remote writes: false

## Runs

${rows}
"

if [[ -n "$output" ]]; then
  mkdir -p "$(dirname "$output")"
  printf '%s' "$report" > "$output"
  echo "refresh_report: $output"
else
  printf '%s' "$report"
fi

if [[ "$strict_gate_policy" == "true" && "$gate_policy_fail_count" -gt 0 ]]; then
  exit 1
fi
