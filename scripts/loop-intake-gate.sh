#!/usr/bin/env bash
set -euo pipefail

show_help() {
  cat <<'HELP'
Usage: scripts/loop-intake-gate.sh --issue <issue-id> --task <task.md> --repo <repo> [--check-remote] [--output <file>]

Validate that a task is ready to enter the local Multica Loop protocol.

Checks:
  - issue id is present and formatted
  - task file exists and references issue id
  - task has goal / acceptance / boundary sections
  - repo path exists and is a git worktree
  - optional: Multica issue exists remotely

Options:
  --issue         Multica issue identifier, required
  --task          Local task markdown file, required
  --repo          Target repository path, required
  --check-remote  Query Multica to confirm the issue exists
  --output        Optional markdown report output
  -h, --help      Show this help
HELP
}

issue_id=""
task_file=""
repo_path=""
check_remote="false"
output_file=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --issue)
      issue_id="${2:-}"; shift 2 ;;
    --task)
      task_file="${2:-}"; shift 2 ;;
    --repo)
      repo_path="${2:-}"; shift 2 ;;
    --check-remote)
      check_remote="true"; shift ;;
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

if [[ -z "$issue_id" || -z "$task_file" || -z "$repo_path" ]]; then
  echo "--issue, --task, and --repo are required" >&2
  show_help
  exit 2
fi

result="PASSED"
rows=""
notes=""

add_check() {
  local name="$1"
  local status="$2"
  local detail="$3"
  rows+="| ${name} | ${status} | ${detail} |"$'\n'
  if [[ "$status" == "FAILED" ]]; then
    result="FAILED"
  fi
}

if [[ "$issue_id" =~ ^[A-Z]+-[0-9]+$ ]]; then
  add_check "Issue ID format" "PASSED" "$issue_id"
else
  add_check "Issue ID format" "FAILED" "expected format like FUZ-554"
fi

if [[ -f "$task_file" && -s "$task_file" ]]; then
  add_check "Task file exists" "PASSED" "$task_file"
else
  add_check "Task file exists" "FAILED" "$task_file missing or empty"
fi

if [[ -f "$task_file" ]] && rg -q "$issue_id" "$task_file"; then
  add_check "Task references issue" "PASSED" "$issue_id"
else
  add_check "Task references issue" "FAILED" "task must mention $issue_id"
fi

if [[ -f "$task_file" ]] && rg -q "目标|Goal|Objective" "$task_file"; then
  add_check "Task has goal" "PASSED" "goal section found"
else
  add_check "Task has goal" "FAILED" "missing 目标/Goal/Objective"
fi

if [[ -f "$task_file" ]] && rg -q "验收|Acceptance|验证|Verification" "$task_file"; then
  add_check "Task has acceptance" "PASSED" "acceptance section found"
else
  add_check "Task has acceptance" "FAILED" "missing 验收/Acceptance/验证/Verification"
fi

if [[ -f "$task_file" ]] && rg -q "边界|约束|风险|Boundary|Constraint|Risk|Side effect|副作用" "$task_file"; then
  add_check "Task has boundary" "PASSED" "boundary/risk section found"
else
  add_check "Task has boundary" "FAILED" "missing boundary/risk/side-effect section"
fi

if [[ -d "$repo_path" ]]; then
  add_check "Repo path exists" "PASSED" "$repo_path"
else
  add_check "Repo path exists" "FAILED" "$repo_path missing"
fi

if [[ -d "$repo_path/.git" ]] || git -C "$repo_path" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  add_check "Repo is git worktree" "PASSED" "$repo_path"
else
  add_check "Repo is git worktree" "FAILED" "$repo_path is not a git worktree"
fi

if [[ "$check_remote" == "true" ]]; then
  if multica issue get "$issue_id" --output json >/tmp/loop-intake-gate-issue.json 2>/tmp/loop-intake-gate-issue.err; then
    remote_title="$(python3 - <<'PY' /tmp/loop-intake-gate-issue.json
import json, sys
with open(sys.argv[1], encoding='utf-8') as fh:
    issue = json.load(fh)
print(issue.get('title') or '')
PY
)"
    add_check "Remote Multica issue" "PASSED" "$remote_title"
  else
    add_check "Remote Multica issue" "FAILED" "multica issue get failed"
  fi
else
  add_check "Remote Multica issue" "SKIPPED" "use --check-remote to verify"
fi

if [[ "$result" == "PASSED" ]]; then
  notes="Task is ready to enter Loop."
else
  notes="Task is not ready. Fix failed checks before Loop execution."
fi

report="# Loop Intake Gate: ${issue_id}

## Result

- Result: ${result}
- Task: ${task_file}
- Repo: ${repo_path}
- Remote check: ${check_remote}

## Checks

| Check | Result | Detail |
|---|---|---|
${rows}
## Notes

${notes}
"

if [[ -n "$output_file" ]]; then
  printf '%s' "$report" > "$output_file"
  echo "intake_gate_report: $output_file"
else
  printf '%s' "$report"
fi

if [[ "$result" != "PASSED" ]]; then
  exit 1
fi
