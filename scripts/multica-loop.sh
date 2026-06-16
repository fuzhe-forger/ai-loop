#!/usr/bin/env bash
set -euo pipefail

show_help() {
  cat <<'HELP'
Usage: scripts/multica-loop.sh --issue FUZ-xxx --repo <repo> [--write-comment] [--write-status]

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
  --write-comment   Post the generated Multica comment after dry-run
  --write-status    Sync issue status after dry-run using policy mapping
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

  - Comments are written only with --write-comment.
  - Status is written only with --write-status.
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
status_policy="conservative"

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
    --write-comment)
      write_comment="true"; shift ;;
    --write-status)
      write_status="true"; shift ;;
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
mkdir -p "$(dirname "$comment_path")"
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
REPORT

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

## Summary

See: ${summary_path}

## Loop State Recommendation

- State: ${loop_suggested_state}
- Next actor: ${loop_next_actor}
- Reason: ${loop_state_reason}
- State evidence: ${state_markdown_path}
- Metadata draft: ${metadata_markdown_path}
COMMENT

comment_written="false"
status_written="false"
status_write_value=""
write_failed="false"
write_error_path="runs/${actual_run_id}/multica-write-error.log"

if [[ "$write_comment" == "true" ]]; then
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
    status_write_value="$next_status"
    if multica issue status "$issue_id" "$next_status" --output json >/dev/null 2>>"$write_error_path"; then
      status_written="true"
    else
      status_written="failed"
      write_failed="true"
    fi
  fi
fi

write_error_log=""
if [[ -s "$write_error_path" ]]; then
  write_error_log="$write_error_path"
fi

cat > "$stage_report_path" <<REPORT
# Multica Loop Stage Report

## Input

- Issue: ${issue_key}
- Title: ${issue_title}
- Repo: ${repo}
- Run ID: ${actual_run_id}

## Output

- Task: ${task_path}
- Summary: ${summary_path}
- Comment draft: ${comment_path}
- State evaluation: ${state_json_path}
- Metadata draft: ${metadata_json_path}
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
- Write error log: ${write_error_log}

## Next Step

If remote writes are approved later, the generated comment draft can be posted and the issue status can be synchronized.
REPORT

echo "comment_written: ${comment_written}"
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
