#!/usr/bin/env bash
set -euo pipefail

show_help() {
  cat <<'HELP'
Usage: scripts/multica-loop.sh --issue FUZ-xxx --repo <repo> [--task-type <type>] [--skip-gate-policy] [--write-comment --approved-by <who>] [--write-status --approved-by <who>] [--write-metadata --metadata-approved-by <who>]

Multica ↔ ai-loop wrapper:
  1. Fetch a Multica issue
  2. Materialize a local task file
  3. Run ai-loop dry-run
  4. Generate local evidence and an optional Multica comment

Options:
  --issue           Multica issue identifier, required
  --repo            Target repository for ai-loop, required
  --task-dir        Local task directory, default: tasks
  --run-id          Explicit ai-loop run id, optional
  --task-type       Optional task type override for gate-policy-check
  --task-tier       L0 | L1 | L2 | L3 | L4 | auto for execution timebox, default auto
  --started-at      Execution start timestamp for audited elapsed time, default script start
  --completed-at    Execution completion timestamp, default before continuation gate
  --elapsed-minutes Manual fallback only when timestamps are unavailable
  --skip-gate-policy
                    Do not generate gate-policy-check.md/json
  --write-comment   Post the generated Multica comment after dry-run
  --write-status    Sync issue status after dry-run using policy mapping
  --write-metadata  Sync allowlisted issue metadata through scripts/metadata-writeback.sh
  --approved-by     Human approver name, required with --write-comment or --write-status
  --metadata-approved-by
                    Human approver name, required with --write-metadata; overrides --approved-by for metadata
  --metadata-key    Metadata key to write (default: pipeline_status)
  --status-policy   conservative | validation | no-status (default: conservative)
  --policy-help     Explain status policies and exit without network access
  -h, --help        Show this help
HELP
}

show_policy_help() {
  cat <<'HELP'
Status policies:

  conservative
    Default. A dry-run PASSED result maps to todo because it proves only
    orchestration readiness, not business completion.

  validation
    For validating the bridge or wrapper itself. A dry-run PASSED result can
    map to in_review when humans agree the validation task is complete.

  no-status
    Observation mode. No status write target is produced; stage reports record
    the mapped status as none.

Remote write rules:

  - Comments are written only with --write-comment and --approved-by.
  - Status is written only with --write-status and --approved-by.
  - Metadata is written only with --write-metadata and --metadata-approved-by.
  - All requested writes pass scripts/approval-boundary.sh before the write call.
  - no-status prevents status writes even when --write-status is present.
  - Remote writes still require explicit human approval outside this script.
HELP
}

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

issue_id=""
repo=""
task_dir="tasks"
run_id=""
write_comment="false"
write_status="false"
write_metadata="false"
approved_by=""
metadata_approved_by=""
metadata_key="pipeline_status"
status_policy="conservative"
task_type=""
task_tier="auto"
elapsed_minutes="0"
started_at="$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
completed_at=""
gate_policy="true"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --issue)
      issue_id="${2:-}"; shift 2 ;;
    --repo)
      repo="${2:-}"; shift 2 ;;
    --task-dir)
      task_dir="${2:-}"; shift 2 ;;
    --run-id)
      run_id="${2:-}"; shift 2 ;;
    --task-type)
      task_type="${2:-}"; shift 2 ;;
    --task-tier)
      task_tier="${2:-}"; shift 2 ;;
    --started-at)
      started_at="${2:-}"; shift 2 ;;
    --completed-at)
      completed_at="${2:-}"; shift 2 ;;
    --elapsed-minutes)
      elapsed_minutes="${2:-}"; shift 2 ;;
    --skip-gate-policy)
      gate_policy="false"; shift ;;
    --write-comment)
      write_comment="true"; shift ;;
    --write-status)
      write_status="true"; shift ;;
    --write-metadata)
      write_metadata="true"; shift ;;
    --approved-by)
      approved_by="${2:-}"; shift 2 ;;
    --metadata-approved-by)
      metadata_approved_by="${2:-}"; shift 2 ;;
    --metadata-key)
      metadata_key="${2:-}"; shift 2 ;;
    --status-policy)
      status_policy="${2:-}"; shift 2 ;;
    --policy-help)
      show_policy_help; exit 0 ;;
    -h|--help)
      show_help; exit 0 ;;
    *)
      echo "Unknown argument: $1" >&2
      show_help
      exit 2 ;;
  esac
done

if [[ -z "$issue_id" || -z "$repo" ]]; then
  echo "--issue and --repo are required" >&2
  show_help
  exit 2
fi

case "$status_policy" in
  conservative|validation|no-status) ;;
  *)
    echo "Invalid --status-policy: $status_policy" >&2
    exit 2 ;;
esac
case "$task_tier" in
  L0|L1|L2|L3|L4|auto) ;;
  *)
    echo "Invalid --task-tier: $task_tier" >&2
    exit 2 ;;
esac
if ! [[ "$elapsed_minutes" =~ ^[0-9]+$ ]]; then
  echo "--elapsed-minutes must be a non-negative integer" >&2
  exit 2
fi

if [[ "$write_comment" == "true" && -z "$approved_by" ]]; then
  echo "--approved-by is required with --write-comment" >&2
  exit 2
fi

if [[ "$write_status" == "true" && "$status_policy" != "no-status" && -z "$approved_by" ]]; then
  echo "--approved-by is required with --write-status unless --status-policy no-status is used" >&2
  exit 2
fi

if [[ "$write_metadata" == "true" && -z "$metadata_approved_by" && -n "$approved_by" ]]; then
  metadata_approved_by="$approved_by"
fi

if [[ "$write_metadata" == "true" && -z "$metadata_approved_by" ]]; then
  echo "--metadata-approved-by is required with --write-metadata" >&2
  exit 2
fi

mkdir -p "$task_dir"

cd "$ROOT_DIR"

tmp_issue="$(mktemp)"
trap 'rm -f "$tmp_issue"' EXIT
multica issue get "$issue_id" --output json > "$tmp_issue"

issue_key="$(python3 - <<'PY' "$tmp_issue"
import json, sys
issue = json.loads(open(sys.argv[1], encoding='utf-8').read())
print(issue.get('identifier') or f'FUZ-{issue.get("number","")}' or '')
PY
)"
issue_title="$(python3 - <<'PY' "$tmp_issue"
import json, sys
issue = json.loads(open(sys.argv[1], encoding='utf-8').read())
print(issue.get('title', ''))
PY
)"
issue_desc="$(python3 - <<'PY' "$tmp_issue"
import json, sys
issue = json.loads(open(sys.argv[1], encoding='utf-8').read())
print(issue.get('description', ''))
PY
)"

classification_path="$task_dir/${issue_key}-classification.json"
./scripts/classify-task.sh \
  --issue "$issue_key" \
  --input "$tmp_issue" \
  --output "$classification_path" \
  --ai-model none >/dev/null

task_path="$task_dir/${issue_key}.md"
cat > "$task_path" <<TASK
# ${issue_key} ${issue_title}

## 原始需求

${issue_desc}

## 目标

将该 Multica issue 转成本地 ai-loop 任务，先进行 dry-run 验证，再根据 summary 生成 comment 草稿。

## 验收

- 生成本地 task.md
- 成功运行 ai-loop dry-run
- 生成 summary.md
- 生成 multica-comment.md
- 默认不写回 Multica

## 安全边界

- 不自动改 issue 状态
- 不自动回写 comment
- 不自动 push / commit / MR
- 不访问生产系统
TASK

if [[ -z "$run_id" ]]; then
  run_id="${issue_key}-$(date +%Y%m%d-%H%M%S)"
fi

run_output="$(./bin/ai-loop run --repo "$repo" --task "$task_path" --dry-run --run-id "$run_id")"
actual_run_id="$(printf '%s\n' "$run_output" | awk -F': ' '/^run_id:/ {print $2; exit}')"
if [[ -z "$actual_run_id" ]]; then
  actual_run_id="$run_id"
fi

summary_path="runs/${actual_run_id}/summary.md"
comment_path="runs/${actual_run_id}/multica-comment.md"
stage_report_path="runs/${actual_run_id}/stage-report.md"
writeback_summary_path="runs/${actual_run_id}/writeback-summary.md"
classification_run_path="runs/${actual_run_id}/classification.json"
requirement_gate_path="runs/${actual_run_id}/requirement-gate.md"
clarification_path="runs/${actual_run_id}/clarification.md"
clarification_gate_path="runs/${actual_run_id}/clarification-gate.md"
deliverable_gate_path="runs/${actual_run_id}/deliverable-gate.md"
gate_policy_markdown_path="runs/${actual_run_id}/gate-policy-check.md"
gate_policy_json_path="runs/${actual_run_id}/gate-policy-check.json"
execution_preflight_path="runs/${actual_run_id}/execution-preflight.md"
execution_preflight_json_path="runs/${actual_run_id}/execution-preflight.json"
continuation_gate_path="runs/${actual_run_id}/continuation-gate.md"
continuation_gate_json_path="runs/${actual_run_id}/continuation-gate.json"
execution_time_contract_path="runs/${actual_run_id}/execution-time-contract.md"
execution_time_contract_json_path="runs/${actual_run_id}/execution-time-contract.json"
time_calibration_path="runs/${actual_run_id}/time-estimation-calibration.md"
time_calibration_json_path="runs/${actual_run_id}/time-estimation-calibration.json"
mkdir -p "$(dirname "$comment_path")"
cp "$classification_path" "$classification_run_path"
preflight_args=(
  --issue "$issue_key"
  --task "$task_path"
  --repo "$repo"
  --run-id "$actual_run_id"
  --task-tier "$task_tier"
  --output "$execution_preflight_path"
  --json-output "$execution_preflight_json_path"
)
if [[ -n "$task_type" ]]; then
  preflight_args+=(--task-type "$task_type")
fi
if [[ "$write_comment" == "true" || "$write_status" == "true" || "$write_metadata" == "true" ]]; then
  preflight_args+=(--allow-multica-write)
fi
./scripts/loop-execution-preflight.sh "${preflight_args[@]}" >/dev/null
cat > "$comment_path" <<COMMENT
# Multica Comment Draft

- Issue: ${issue_key}
- Title: ${issue_title}
- AI Loop Run: ${actual_run_id}
- Mode: dry-run
- Result: generated locally; remote writes require explicit flags

## Summary

See: ${summary_path}
COMMENT

loop_status="$(python3 - <<'PY' "runs/${actual_run_id}/run.json"
import json, sys
run = json.loads(open(sys.argv[1], encoding='utf-8').read())
print(run.get('status', ''))
PY
)"
error_code="$(python3 - <<'PY' "runs/${actual_run_id}/run.json"
import json, sys
run = json.loads(open(sys.argv[1], encoding='utf-8').read())
print(run.get('error_code') or '')
PY
)"

next_status="blocked"
status_reason="unhandled loop result; conservative fallback"
if [[ "$status_policy" == "no-status" ]]; then
  next_status="none"
  status_reason="status writes disabled by policy"
else
  case "$loop_status:$error_code:$status_policy" in
    PASSED::validation)
      next_status="in_review"
      status_reason="validation policy treats dry-run pass as bridge verification evidence"
      ;;
    PASSED::conservative)
      next_status="todo"
      status_reason="dry-run pass proves orchestration only, not business completion"
      ;;
    *:FAILED_CONFIG:*)
      status_reason="configuration failure requires manual correction"
      ;;
    *:FAILED_WORKSPACE:*)
      status_reason="workspace or repository preparation failed"
      ;;
    *:FAILED_AGENT_EXIT:*)
      status_reason="agent execution exited unsuccessfully"
      ;;
    *:FAILED_VERIFY:*)
      status_reason="verification failed and needs a fix or human decision"
      ;;
    *:FAILED_SAFETY:*)
      status_reason="safety gate failed and requires human intervention"
      ;;
    *::*)
      status_reason="loop did not pass; blocked for review"
      ;;
  esac
fi

cat > "$stage_report_path" <<REPORT
# Multica Loop Stage Report

## Input

- Issue: ${issue_key}
- Title: ${issue_title}
- Repo: ${repo}
- Run ID: ${actual_run_id}

## Purpose

- Goal: convert the Multica issue into a local ai-loop run, produce auditable evidence, and prepare a controlled writeback decision.
- Objective: keep the first pass local-first unless comment/status writeback is explicitly requested.

## Output

- Task: ${task_path}
- Summary: ${summary_path}
- Comment draft: ${comment_path}
- Loop status: ${loop_status}
- Error code: ${error_code}

## Status Mapping

- Status policy: ${status_policy}
- Mapped status: ${next_status}
- Mapping reason: ${status_reason}

## Remote Writes

- Pending final writeback decision: true

## Owner / Actor

- DRI: human requester
- Execution actor: ai-loop local agent
- Next actor: human

## Next Action

- Review generated evidence and decide whether to approve comment/status/metadata writeback separately.
REPORT

set +e
./scripts/requirement-gate.sh \
  --input "$task_path" \
  --issue "$issue_key" \
  --output "$requirement_gate_path" \
  --clarification-output "$clarification_path" >/dev/null 2>"runs/${actual_run_id}/requirement-gate.err"
requirement_gate_exit=$?
set -e
if [[ "$requirement_gate_exit" -eq 0 ]]; then
  rm -f "runs/${actual_run_id}/requirement-gate.err"
fi

if [[ -s "$clarification_path" ]]; then
  set +e
  ./scripts/clarification-gate.sh \
    --run-id "$actual_run_id" \
    --strict \
    --output "$clarification_gate_path" >/dev/null 2>"runs/${actual_run_id}/clarification-gate.err"
  clarification_gate_exit=$?
  set -e
  if [[ "$clarification_gate_exit" -eq 0 ]]; then
    rm -f "runs/${actual_run_id}/clarification-gate.err"
  fi
fi

set +e
./scripts/deliverable-gate.sh \
  --run-id "$actual_run_id" \
  --issue "$issue_key" \
  --output "$deliverable_gate_path" >/dev/null 2>"runs/${actual_run_id}/deliverable-gate.err"
deliverable_gate_exit=$?
set -e
if [[ "$deliverable_gate_exit" -eq 0 ]]; then
  rm -f "runs/${actual_run_id}/deliverable-gate.err"
fi

gate_policy_status="SKIPPED"
if [[ "$gate_policy" == "true" ]]; then
  gate_policy_args=(
    --issue "$issue_key"
    --run-id "$actual_run_id"
    --classification "$classification_run_path"
    --output "$gate_policy_markdown_path"
    --json-output "$gate_policy_json_path"
  )
  if [[ -n "$task_type" ]]; then
    gate_policy_args+=(--task-type "$task_type")
  fi
  set +e
  ./scripts/gate-policy-check.sh "${gate_policy_args[@]}" >/dev/null 2>"runs/${actual_run_id}/gate-policy-check.err"
  gate_policy_exit=$?
  set -e
  if [[ "$gate_policy_exit" -eq 0 ]]; then
    gate_policy_status="PASSED"
    rm -f "runs/${actual_run_id}/gate-policy-check.err"
  else
    gate_policy_status="FAILED"
  fi
fi

./scripts/evaluate-state.sh --issue "$issue_key" --run-id "$actual_run_id" --write-run >/dev/null
state_json_path="runs/${actual_run_id}/state-evaluation.json"
state_markdown_path="runs/${actual_run_id}/state-evaluation.md"
metadata_json_path="runs/${actual_run_id}/metadata-draft.json"
metadata_markdown_path="runs/${actual_run_id}/metadata-draft.md"
loop_suggested_state="$(python3 - <<'PY' "$state_json_path"
import json, sys
with open(sys.argv[1], encoding='utf-8') as fh:
    data = json.load(fh)
print(data.get('to') or 'unknown')
PY
)"
loop_next_actor="$(python3 - <<'PY' "$state_json_path"
import json, sys
with open(sys.argv[1], encoding='utf-8') as fh:
    data = json.load(fh)
print(data.get('required_next_actor') or 'unknown')
PY
)"
loop_state_reason="$(python3 - <<'PY' "$state_json_path"
import json, sys
with open(sys.argv[1], encoding='utf-8') as fh:
    data = json.load(fh)
print(data.get('reason') or 'unknown')
PY
)"
./scripts/metadata-draft.sh \
  --issue "$issue_key" \
  --run-id "$actual_run_id" \
  --output "$metadata_json_path" \
  --markdown "$metadata_markdown_path" >/dev/null

cat > "$comment_path" <<COMMENT
# Multica Comment Draft

- Issue: ${issue_key}
- Title: ${issue_title}
- AI Loop Run: ${actual_run_id}
- Mode: dry-run
- Result: generated locally; remote writes require explicit flags
- Suggested Loop state: ${loop_suggested_state}
- Next actor: ${loop_next_actor}
- Metadata draft: ${metadata_markdown_path}
- Classification: ${classification_run_path}
- Gate policy: ${gate_policy_status} (${gate_policy_markdown_path})

## Summary

See: ${summary_path}

## Loop State Recommendation

- State: ${loop_suggested_state}
- Next actor: ${loop_next_actor}
- Reason: ${loop_state_reason}
- State evidence: ${state_markdown_path}
- Metadata draft: ${metadata_markdown_path}
- Classification: ${classification_run_path}
- Gate policy: ${gate_policy_status} (${gate_policy_markdown_path})
- Execution preflight: ${execution_preflight_path}
- Continuation gate: ${continuation_gate_path}
COMMENT

comment_written="false"
status_written="false"
status_write_value=""
metadata_written="false"
metadata_write_value="not-implemented"
metadata_write_report="runs/${actual_run_id}/metadata-writeback.md"
metadata_write_json="runs/${actual_run_id}/metadata-writeback.json"
approval_comment_report="runs/${actual_run_id}/approval-boundary-comment.md"
approval_comment_json="runs/${actual_run_id}/approval-boundary-comment.json"
approval_status_report="runs/${actual_run_id}/approval-boundary-status.md"
approval_status_json="runs/${actual_run_id}/approval-boundary-status.json"
approval_metadata_report="runs/${actual_run_id}/approval-boundary-metadata.md"
approval_metadata_json="runs/${actual_run_id}/approval-boundary-metadata.json"
write_failed="false"
write_error_path="runs/${actual_run_id}/multica-write-error.log"

if [[ "$write_comment" == "true" ]]; then
  ./scripts/approval-boundary.sh \
    --action multica-comment \
    --issue "$issue_id" \
    --run-id "$actual_run_id" \
    --approved-by "$approved_by" \
    --output "$approval_comment_report" \
    --json-output "$approval_comment_json" >/dev/null
  if multica issue comment add "$issue_id" --content-file "$comment_path" --output json >/dev/null 2>"$write_error_path"; then
    comment_written="true"
  else
    comment_written="failed"
    write_failed="true"
  fi
else
  comment_written="false"
fi

if [[ "$write_status" == "true" ]]; then
  if [[ "$status_policy" == "no-status" ]]; then
    status_written="false"
    status_write_value="policy=no-status"
  else
    ./scripts/approval-boundary.sh \
      --action multica-status \
      --issue "$issue_id" \
      --run-id "$actual_run_id" \
      --approved-by "$approved_by" \
      --output "$approval_status_report" \
      --json-output "$approval_status_json" >/dev/null
    status_write_value="$next_status"
    if multica issue status "$issue_id" "$next_status" --output json >/dev/null 2>>"$write_error_path"; then
      status_written="true"
    else
      status_written="failed"
      write_failed="true"
    fi
  fi
fi

if [[ "$write_metadata" == "true" ]]; then
  ./scripts/approval-boundary.sh \
    --action multica-metadata \
    --issue "$issue_id" \
    --run-id "$actual_run_id" \
    --approved-by "$metadata_approved_by" \
    --output "$approval_metadata_report" \
    --json-output "$approval_metadata_json" >/dev/null
  if ./scripts/metadata-writeback.sh \
    --issue "$issue_id" \
    --run-id "$actual_run_id" \
    --key "$metadata_key" \
    --approved-by "$metadata_approved_by" \
    --write \
    --output "$metadata_write_report" \
    --json-output "$metadata_write_json" >/dev/null 2>>"$write_error_path"; then
    metadata_written="true"
    metadata_write_value="${metadata_key}=$(python3 - <<'PY' "$metadata_write_json"
import json, sys
with open(sys.argv[1], encoding='utf-8') as fh:
    data = json.load(fh)
print(data.get('metadata', {}).get('value', 'unknown'))
PY
)"
  else
    metadata_written="failed"
    metadata_write_value="${metadata_key}=failed"
    write_failed="true"
  fi
else
  ./scripts/metadata-writeback.sh \
    --issue "$issue_id" \
    --run-id "$actual_run_id" \
    --key "$metadata_key" \
    --output "$metadata_write_report" \
    --json-output "$metadata_write_json" >/dev/null
fi

./scripts/loop-continuation-gate.sh \
  --issue "$issue_key" \
  --run-id "$actual_run_id" \
  --task-tier "$task_tier" \
  --started-at "$started_at" \
  --completed-at "${completed_at:-$(date -u '+%Y-%m-%dT%H:%M:%SZ')}" \
  --elapsed-minutes "$elapsed_minutes" \
  --stage multica-loop \
  --output "$continuation_gate_path" \
  --json-output "$continuation_gate_json_path" >/dev/null

estimated_minutes="$(python3 - <<'PY' "$continuation_gate_json_path"
import json, sys
with open(sys.argv[1], encoding='utf-8') as fh:
    data = json.load(fh)
print(data.get('estimated_minutes') or 0)
PY
)"
completed_for_contract="$(python3 - <<'PY' "$continuation_gate_json_path"
import json, sys
with open(sys.argv[1], encoding='utf-8') as fh:
    data = json.load(fh)
print(data.get('completed_at') or '')
PY
)"
if [[ -n "$completed_for_contract" ]]; then
  ./scripts/execution-time-contract.sh \
    --estimate-minutes "$estimated_minutes" \
    --basis "multica-loop task-tier ${task_tier}" \
    --started-at "$started_at" \
    --completed-at "$completed_for_contract" \
    --stop-condition "multica-loop continuation gate and calibration completed" \
    --output "$execution_time_contract_path" \
    --json-output "$execution_time_contract_json_path" >/dev/null
fi

./scripts/time-estimation-calibration.sh \
  --pattern "$actual_run_id" \
  --output "$time_calibration_path" \
  --json-output "$time_calibration_json_path" >/dev/null

continuation_decision="$(python3 - <<'PY' "$continuation_gate_json_path"
import json, sys
with open(sys.argv[1], encoding='utf-8') as fh:
    data = json.load(fh)
print(data.get('decision') or 'UNKNOWN')
PY
)"

write_error_log=""
if [[ -s "$write_error_path" ]]; then
  write_error_log="$write_error_path"
fi

cat > "$writeback_summary_path" <<WRITEBACK
# Multica Loop Writeback Summary

## Scope

- Issue: ${issue_key}
- Run ID: ${actual_run_id}
- Comment draft: ${comment_path}
- Metadata draft: ${metadata_json_path}

## Remote Write Requests

- Write comment requested: ${write_comment}
- Write status requested: ${write_status}
- Write metadata requested: ${write_metadata}

## Remote Write Results

- Comment written: ${comment_written}
- Status written: ${status_written}
- Status write value: ${status_write_value}
- Metadata written: ${metadata_written}
- Metadata write value: ${metadata_write_value}
- Metadata writeback report: ${metadata_write_report}
- Metadata writeback JSON: ${metadata_write_json}
- Metadata approved by: ${metadata_approved_by:-not-provided}
- Approval boundary comment: ${approval_comment_report}
- Approval boundary status: ${approval_status_report}
- Approval boundary metadata: ${approval_metadata_report}
- Write error log: ${write_error_log}

## Policy Notes

- Comment, status, and metadata are separate remote side effects.
- Metadata remote write is controlled by scripts/metadata-writeback.sh and requires --write-metadata plus --metadata-approved-by.
- This summary is generated even when no remote writes are requested.
WRITEBACK

cat > "$stage_report_path" <<REPORT
# Multica Loop Stage Report

## Input

- Issue: ${issue_key}
- Title: ${issue_title}
- Repo: ${repo}
- Run ID: ${actual_run_id}

## Purpose

- Goal: convert the Multica issue into a local ai-loop run, produce auditable evidence, and prepare a controlled writeback decision.
- Objective: keep the first pass local-first unless comment/status/metadata writeback is explicitly requested.

## Output

- Task: ${task_path}
- Summary: ${summary_path}
- Comment draft: ${comment_path}
- State evaluation: ${state_json_path}
- Metadata draft: ${metadata_json_path}
- Classification: ${classification_run_path}
- Requirement gate: ${requirement_gate_path}
- Clarification: ${clarification_path}
- Clarification gate: ${clarification_gate_path}
- Deliverable gate: ${deliverable_gate_path}
- Gate policy check: ${gate_policy_markdown_path}
- Gate policy status: ${gate_policy_status}
- Execution preflight: ${execution_preflight_path}
- Continuation gate: ${continuation_gate_path}
- Continuation decision: ${continuation_decision}
- Execution time contract: ${execution_time_contract_path}
- Time estimation calibration: ${time_calibration_path}
- Writeback summary: ${writeback_summary_path}
- Loop status: ${loop_status}
- Error code: ${error_code}

## Loop State Recommendation

- Suggested state: ${loop_suggested_state}
- Next actor: ${loop_next_actor}
- Reason: ${loop_state_reason}

## Status Mapping

- Status policy: ${status_policy}
- Mapped status: ${next_status}
- Mapping reason: ${status_reason}

## Remote Writes

- Write comment requested: ${write_comment}
- Comment written: ${comment_written}
- Write status requested: ${write_status}
- Status written: ${status_written}
- Status write value: ${status_write_value}
- Write metadata requested: ${write_metadata}
- Metadata written: ${metadata_written}
- Metadata write value: ${metadata_write_value}
- Metadata writeback report: ${metadata_write_report}
- Metadata approved by: ${metadata_approved_by:-not-provided}
- Approval boundary comment: ${approval_comment_report}
- Approval boundary status: ${approval_status_report}
- Approval boundary metadata: ${approval_metadata_report}
- Write error log: ${write_error_log}

## Owner / Actor

- DRI: human requester
- Execution actor: ai-loop local agent
- Next actor: ${loop_next_actor}

## Next Step

Next action: review generated evidence, then approve any additional comment/status/metadata writeback separately.
REPORT

echo "comment_written: ${comment_written}"
echo "metadata_written: ${metadata_written}"
echo "metadata_writeback: ${metadata_write_report}"
if [[ -n "$status_write_value" ]]; then
  echo "status_written: ${status_write_value}"
else
  echo "status_written: ${status_written}"
fi
if [[ "$write_failed" == "true" ]]; then
  echo "write_error_log: ${write_error_path}"
  exit 1
fi

echo "issue: $issue_id"
echo "task: $task_path"
echo "run_id: $actual_run_id"
echo "summary: $summary_path"
echo "comment_draft: $comment_path"
echo "stage_report: $stage_report_path"
echo "writeback_summary: $writeback_summary_path"
echo "classification: $classification_run_path"
echo "gate_policy: $gate_policy_status"
echo "execution_preflight: $execution_preflight_path"
echo "continuation_gate: $continuation_gate_path"
echo "continuation_decision: $continuation_decision"
echo "execution_time_contract: $execution_time_contract_path"
echo "time_estimation_calibration: $time_calibration_path"
