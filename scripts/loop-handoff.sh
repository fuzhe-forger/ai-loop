#!/usr/bin/env bash
set -euo pipefail

show_help() {
  cat <<'HELP'
Usage: scripts/loop-handoff.sh --issue <issue> --run-id <run> --from-role <role> --to-role <role> --state <state> --next-action <text> [options]

Generate a standard Loop handoff message for agent collaboration.

Options:
  --issue <issue>       Issue id, required
  --run-id <run>        Run id, required
  --from-role <role>    sender role, required
  --to-role <role>      receiver role, required
  --state <state>       loop state, required
  --next-action <text>  next action, required
  --message-type <type> Message type: handoff | review | test | note (default: handoff)
  --side-effects <text> Side effects summary (default: none)
  --output <file>       Optional output file
  -h, --help            Show this help
HELP
}

issue_id=""
run_id=""
from_role=""
to_role=""
loop_state=""
next_action=""
message_type="handoff"
side_effects="none"
output_file=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --issue)
      issue_id="${2:-}"; shift 2 ;;
    --run-id)
      run_id="${2:-}"; shift 2 ;;
    --from-role)
      from_role="${2:-}"; shift 2 ;;
    --to-role)
      to_role="${2:-}"; shift 2 ;;
    --state)
      loop_state="${2:-}"; shift 2 ;;
    --next-action)
      next_action="${2:-}"; shift 2 ;;
    --message-type)
      message_type="${2:-}"; shift 2 ;;
    --side-effects)
      side_effects="${2:-}"; shift 2 ;;
    --output)
      output_file="${2:-}"; shift 2 ;;
    -h|--help)
      show_help; exit 0 ;;
    *)
      echo "Unknown argument: $1" >&2
      show_help
      exit 2 ;;
  esac
done

if [[ -z "$issue_id" || -z "$run_id" || -z "$from_role" || -z "$to_role" || -z "$loop_state" || -z "$next_action" ]]; then
  echo "--issue, --run-id, --from-role, --to-role, --state, and --next-action are required" >&2
  show_help
  exit 2
fi

actor_name() {
  case "$1" in
    scheduler) echo "黑墙" ;;
    execution_agent) echo "顾实" ;;
    reviewer) echo "裴衡" ;;
    tester) echo "测真" ;;
    scribe) echo "简辞" ;;
    human) echo "人类" ;;
    *) echo "$1" ;;
  esac
}

run_dir="runs/$run_id"
evidence_lines=""
for artifact in summary.md stage-report.md multica-comment.md review-packet.md state-evaluation.md metadata-draft.md verification-report.md writeback-summary.md; do
  if [[ -s "$run_dir/$artifact" ]]; then
    evidence_lines+="  - ${run_dir}/${artifact}"$'\n'
  fi
done
if [[ -z "$evidence_lines" ]]; then
  evidence_lines="  - (no evidence found under ${run_dir})"$'\n'
fi

from_actor="$(actor_name "$from_role")"
to_actor="$(actor_name "$to_role")"
timestamp="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

message="---
issue: ${issue_id}
run_id: ${run_id}
from_actor: ${from_actor}
from_role: ${from_role}
to_actor: ${to_actor}
to_role: ${to_role}
loop_state: ${loop_state}
message_type: ${message_type}
side_effects: ${side_effects}
generated_at: ${timestamp}
---

# Loop Handoff: ${from_actor} → ${to_actor}

## Context

- Issue: ${issue_id}
- Run ID: ${run_id}
- State: ${loop_state}
- Message type: ${message_type}
- Side effects: ${side_effects}

## Evidence

${evidence_lines}
## Next Action

${next_action}

## Protocol Notes

- This handoff is local-first and evidence-based.
- Remote side effects still require writeback gate and human approval.
- Receiver should update state/evidence before handing off again.
"

if [[ -n "$output_file" ]]; then
  printf '%s' "$message" > "$output_file"
  echo "loop_handoff: $output_file"
else
  printf '%s' "$message"
fi
