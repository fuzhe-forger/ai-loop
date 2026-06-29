#!/usr/bin/env bash
set -euo pipefail

show_help() {
  cat <<'HELP'
Usage: scripts/verify-toolchain.sh [--case <case-id>] [--pattern <glob>] [--strict] [--state-gate] [--output <file>]

Run local-only smoke checks for the Multica × ai-loop helper scripts.

Options:
  --case     Case identifier, default: FUZ-554
  --pattern  Run glob pattern under runs/, default: '<case>*'
  --strict   Require every matched run to include core evidence files
  --state-gate
             Require every matched run to include state and metadata evidence
  --output   Optional file path to write the verification report
  --list-checks
             List the local smoke checks and exit without reading runs/
  -h, --help Show this help

This script is local-only. It does not read Multica and never performs remote writes.
HELP
}

show_checks() {
  cat <<'HELP'
# Toolchain Smoke Checks

- bash -n scripts/verify-toolchain.sh
- bash -n scripts/multica-loop.sh
- bash -n scripts/evidence-checklist.sh
- bash -n scripts/evidence-index.sh
- bash -n scripts/patch-summary.sh
- bash -n scripts/review-packet.sh
- bash -n scripts/collect-evidence.sh
- bash -n scripts/evaluate-state.sh
- bash -n scripts/metadata-draft.sh
- bash -n scripts/refresh-run-evidence.sh
- bash -n scripts/share-preflight.sh
- bash -n scripts/obsidian-sync.sh
- bash -n scripts/daily-ops-sync.sh
- bash -n scripts/route-actor.sh
- bash -n scripts/requirement-gate.sh
- bash -n scripts/clarification-gate.sh
- bash -n scripts/design-gate.sh
- bash -n scripts/deliverable-gate.sh
- bash -n scripts/gate-policy-check.sh
- bash -n scripts/gate-policy-exception.sh
- bash -n scripts/metadata-writeback.sh
- bash -n scripts/approval-boundary.sh
- bash -n scripts/smoke-multica-writeback.sh
- bash -n scripts/writeback-summary-json.sh
- bash -n scripts/golden-path-check.sh
- bash -n scripts/loop-execution-preflight.sh
- bash -n scripts/loop-closeout.sh
- bash -n scripts/loop-continuation-gate.sh
- bash -n scripts/time-estimation-calibration.sh
- bash -n scripts/execution-time-contract.sh
- bash -n scripts/sinan-capability-check.sh
- bash -n scripts/phase-i-task-queue.sh
- bash -n scripts/north-star-task-board.sh
- bash -n scripts/token-efficiency-audit.sh
- bash -n scripts/sinan-flow-advisor.sh
- bash -n scripts/multi-repo-evidence.sh
- bash -n scripts/sinan-ops-dashboard.sh
- bash -n scripts/external-adapter-check.sh
- bash -n scripts/sinan-v2-acceptance.sh
- bash -n scripts/sinan.sh
- python3 -m json.tool config/gate-policy.json
- python3 -m json.tool config/approval-boundary.json
- python3 -m json.tool config/timebox-policy.json
- python3 -m json.tool config/sinan-capabilities.json
- ./scripts/multica-loop.sh --policy-help
- ./scripts/multica-loop.sh --help
- ./scripts/multica-loop.sh --issue <case-id> --repo . --write-metadata
- ./scripts/classify-task.sh --issue <case-id> --ai-model none
- ./scripts/collect-evidence.sh --issue <case-id> --run-id <sample-run>
- ./scripts/evaluate-state.sh --issue <case-id> --run-id <sample-run>
- ./scripts/metadata-draft.sh --issue <case-id> --run-id <sample-run>
- ./scripts/refresh-run-evidence.sh --help
- ./scripts/refresh-run-evidence.sh --pattern <pattern> --skip-gate-policy
- ./scripts/share-preflight.sh --help
- obsidian-sync operation log guard
- ./scripts/route-actor.sh --next-actor reviewer
- ./scripts/requirement-gate.sh --help
- ./scripts/clarification-gate.sh --help
- ./scripts/design-gate.sh --help
- ./scripts/deliverable-gate.sh --help
- ./scripts/gate-policy-check.sh --help
- ./scripts/gate-policy-exception.sh --help
- ./scripts/metadata-writeback.sh --help
- ./scripts/approval-boundary.sh --help
- ./scripts/smoke-multica-writeback.sh --help
- ./scripts/smoke-multica-writeback.sh --issue <case-id>
- ./scripts/approval-boundary.sh --action verify
- ./scripts/approval-boundary.sh --action obsidian-sync
- ./scripts/approval-boundary.sh --action tool-install
- ./scripts/approval-boundary.sh --action codex-config
- ./scripts/writeback-summary-json.sh --help
- ./scripts/golden-path-check.sh --help
- ./scripts/metadata-writeback.sh --issue <case-id> --run-id <sample-run>
- ./scripts/writeback-summary-json.sh --issue <case-id> --run-id <sample-run>
- ./scripts/golden-path-check.sh --issue <case-id> --run-id <sample-run> --skip-obsidian
- ./scripts/patch-summary.sh --help
- ./scripts/evidence-checklist.sh --run-id <sample-run>
- ./scripts/evidence-index.sh --pattern <pattern>
- ./scripts/review-packet.sh --case <case-id> --pattern <pattern>
- ./scripts/loop-execution-preflight.sh --issue <case-id> --task tasks/<case-id>.md --repo .
- ./scripts/loop-closeout.sh --issue <case-id> --task tasks/<case-id>.md --repo . --run-id <sample-run>
- ./scripts/loop-continuation-gate.sh --issue <case-id> --run-id <sample-run>
- ./scripts/time-estimation-calibration.sh --pattern <pattern>
- ./scripts/execution-time-contract.sh --estimate-minutes 10-15
- ./scripts/sinan-capability-check.sh
- ./scripts/phase-i-task-queue.sh --run-id <sample-run> --target-minutes 30
- ./scripts/north-star-task-board.sh --run-id <sample-run> --target-minutes 30
- ./scripts/token-efficiency-audit.sh --run-id <sample-run>
- ./scripts/sinan-flow-advisor.sh --task tasks/sinan-v2-loop-20260624.md
- ./scripts/multi-repo-evidence.sh --run-id <sample-run> --repo .
- ./scripts/sinan-ops-dashboard.sh --pattern <pattern>
- ./scripts/external-adapter-check.sh --target local-smoke --schema config/approval-boundary.json
- ./scripts/sinan-v2-acceptance.sh --run-id <sample-run>
- ./scripts/verify-toolchain.sh --case <case-id> --pattern <pattern> --strict --state-gate

This list is local-only. It does not read Multica and never performs remote writes.
HELP
}

case_id="FUZ-554"
pattern=""
output=""
list_checks="false"
strict="false"
state_gate="false"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --case)
      case_id="${2:-}"; shift 2 ;;
    --pattern)
      pattern="${2:-}"; shift 2 ;;
    --output)
      output="${2:-}"; shift 2 ;;
    --strict)
      strict="true"; shift ;;
    --state-gate)
      state_gate="true"; shift ;;
    --list-checks)
      list_checks="true"; shift ;;
    -h|--help)
      show_help; exit 0 ;;
    *)
      echo "Unknown argument: $1" >&2
      show_help
      exit 2 ;;
  esac
done

if [[ -z "$pattern" ]]; then
  pattern="${case_id}*"
fi

if [[ "$list_checks" == "true" ]]; then
  show_checks
  exit 0
fi

first_run=""
shopt -s nullglob
run_dirs=(runs/$pattern)
shopt -u nullglob
if [[ ${#run_dirs[@]} -gt 0 ]]; then
  first_run="$(basename "${run_dirs[0]}")"
fi

if [[ -z "$first_run" ]]; then
  echo "No run directories matched: runs/$pattern" >&2
  exit 1
fi

verify_tmp_run="${case_id}-verify-smoke-$RANDOM-$(date -u +%s)"
verify_tmp_dir="runs/$verify_tmp_run"
cleanup_verify_tmp_run() {
  rm -rf "$verify_tmp_dir"
}
trap cleanup_verify_tmp_run EXIT
mkdir -p "$verify_tmp_dir"
cat > "$verify_tmp_dir/summary.md" <<EOF
# Verify smoke summary

Local smoke fixture for verify-toolchain. This run is temporary and removed on exit.
EOF
cat > "$verify_tmp_dir/stage-report.md" <<EOF
# Verify smoke stage report

Generated for local timer and fixture checks only.
EOF
cat > "$verify_tmp_dir/multica-comment.md" <<EOF
# Verify smoke comment

No remote write.
EOF
mkdir -p "$verify_tmp_dir/closeout" "$verify_tmp_dir/timers"
cat > "$verify_tmp_dir/verification-report.md" <<EOF
# Verify smoke verification report

Local smoke fixture only.

## Strict Evidence Gate

| Run | Result | Missing Core Evidence |
|---|---|---|
| ${verify_tmp_run} | PASSED | |

## State Metadata Gate

| Run | Result | Missing State Evidence |
|---|---|---|
| ${verify_tmp_run} | PASSED | |
EOF
cat > "$verify_tmp_dir/evidence-checklist.md" <<EOF
# Evidence Checklist

Smoke checklist.
EOF
cat > "$verify_tmp_dir/evidence-index.md" <<EOF
# Evidence Index

Smoke index.
EOF
cat > "$verify_tmp_dir/state-evaluation.json" <<EOF
{"schema_version":1,"to":"done","checks":{"remote_write_completed":"YES"}}
EOF
cat > "$verify_tmp_dir/metadata-draft.json" <<EOF
{"schema_version":1,"metadata":{"pipeline_status":"done","strict_gate":"PASSED"}}
EOF
cat > "$verify_tmp_dir/requirement-gate.md" <<EOF
# Requirement Gate

- Result: PASSED
EOF
cat > "$verify_tmp_dir/deliverable-gate.md" <<EOF
# Deliverable Gate

- Result: PASSED
EOF
cat > "$verify_tmp_dir/gate-policy-check.json" <<EOF
{"schema_version":1,"result":"PASSED","task_type":"documentation"}
EOF
cat > "$verify_tmp_dir/closeout/closeout-summary.md" <<EOF
# Verify smoke closeout

Acceptance met for local smoke fixture.
EOF
cat > "$verify_tmp_dir/writeback-summary.md" <<EOF
# Verify smoke writeback summary

- Comment written: true
- Metadata written: true
- Metadata write value: pipeline_status=done
- Status written: false
- Approval boundary comment: runs/${verify_tmp_run}/approval-boundary-comment.md
- Approval boundary metadata: runs/${verify_tmp_run}/approval-boundary-metadata.md
EOF
cat > "$verify_tmp_dir/writeback-summary.json" <<EOF
{"schema_version":1,"result":"PASSED","results":{"comment":true,"metadata":true,"status":false},"metadata":{"key":"pipeline_status","value":"done","approval_boundary":"runs/${verify_tmp_run}/approval-boundary-metadata.md"},"comment":{"approval_boundary":"runs/${verify_tmp_run}/approval-boundary-comment.md"},"approval_boundaries":{"comment":"runs/${verify_tmp_run}/approval-boundary-comment.md","metadata":"runs/${verify_tmp_run}/approval-boundary-metadata.md"}}
EOF
cat > "$verify_tmp_dir/approval-boundary-comment.md" <<EOF
# Approval Boundary Comment
EOF
cat > "$verify_tmp_dir/approval-boundary-metadata.md" <<EOF
# Approval Boundary Metadata
EOF
cat > "$verify_tmp_dir/multica-metadata-after.json" <<EOF
{"pipeline_status":"done"}
EOF
cat > "$verify_tmp_dir/multica-six-hour-final-issue-readback.json" <<EOF
{"status":"done","metadata":{"execution_package_status":"done"}}
EOF
cat > "$verify_tmp_dir/multica-six-hour-final-metadata-readback.json" <<EOF
{"execution_package_status":"done","pipeline_status":"done"}
EOF
cat > "$verify_tmp_dir/share-preflight-summary.json" <<EOF
{"schema_version":1,"result":"PASSED","snapshot":{"present":true}}
EOF
cat > "$verify_tmp_dir/sinan-capability-check.json" <<EOF
{"schema_version":1,"result":"PASSED"}
EOF
cat > "$verify_tmp_dir/memory-quality-report.json" <<EOF
{"schema_version":1,"result":"PASSED"}
EOF
cat > "$verify_tmp_dir/organization-policy-report.json" <<EOF
{"schema_version":1,"result":"PASSED"}
EOF
cat > "$verify_tmp_dir/timers/timer-guard.start.json" <<EOF
{"schema_version":1,"state":"closed"}
EOF
cat > "$verify_tmp_dir/timers/sinan-fitness.start.json" <<EOF
{"schema_version":1,"state":"started"}
EOF
cat > "$verify_tmp_dir/continuation-gate.json" <<EOF
{"schema_version":1,"decision":"ALLOW_STOP","within_one_minute":true,"absolute_error_minutes":0,"recommended_next_estimate_minutes":30}
EOF
cat > "$verify_tmp_dir/execution-time-contract.json" <<EOF
{"schema_version":1,"estimate_minutes":"30","basis":"verify smoke","started_at":"2026-06-26T00:00:00Z","completed_at":"2026-06-26T00:30:00Z","timing_source":"timestamp","elapsed_seconds":1800,"elapsed_minutes":30,"absolute_error_minutes":0,"within_one_minute":true,"variance_note":"within_estimate","next_estimate_minutes":30,"recommended_next_estimate_minutes":30}
EOF
cat > "$verify_tmp_dir/execution-time-contract.md" <<EOF
# Verify smoke execution time contract
EOF
cat > "$verify_tmp_dir/time-estimation-calibration.md" <<EOF
# Time estimation calibration
EOF
cat > "$verify_tmp_dir/time-estimation-calibration.json" <<EOF
{"schema_version":1,"result":"PASSED","recommended_next_estimate_minutes":30,"summary":{"trusted_measured_runs":1,"execution_time_contract_runs":1}}
EOF
cat > "$verify_tmp_dir/phase-i-task-queue.json" <<EOF
{"schema_version":1,"tasks":[]}
EOF
cat > "$verify_tmp_dir/phase-i-task-queue.md" <<EOF
# Phase I task queue
EOF
cat > "$verify_tmp_dir/north-star-task-board.json" <<EOF
{"schema_version":1,"tasks":[]}
EOF
cat > "$verify_tmp_dir/north-star-task-board.md" <<EOF
# North Star task board
EOF
cat > "$verify_tmp_dir/north-star-execution-report.md" <<EOF
# North Star execution report
EOF
cat > "$verify_tmp_dir/phase-cd-task-board.json" <<EOF
{"schema_version":1,"tasks":[]}
EOF
cat > "$verify_tmp_dir/phase-cd-task-board.md" <<EOF
# Phase C/D task board
EOF
cat > "$verify_tmp_dir/phase-cd-execution-report.md" <<EOF
# Phase C/D execution report
EOF
cat > "$verify_tmp_dir/memory-quality-report.md" <<EOF
# Memory quality report
EOF
cat > "$verify_tmp_dir/organization-policy-report.md" <<EOF
# Organization policy report
EOF
cat > "$verify_tmp_dir/experience-draft.json" <<EOF
{"schema_version":1,"result":"PASSED"}
EOF
cat > "$verify_tmp_dir/experience-draft.md" <<EOF
# Experience draft
EOF
cat > "$verify_tmp_dir/memory-review-state.json" <<EOF
{"schema_version":1,"result":"PASSED"}
EOF
cat > "$verify_tmp_dir/memory-review-state.md" <<EOF
# Memory review state
EOF
cat > "$verify_tmp_dir/phase-cd-next-task-board.json" <<EOF
{"schema_version":1,"tasks":[]}
EOF
cat > "$verify_tmp_dir/phase-cd-next-task-board.md" <<EOF
# Phase C/D next task board
EOF
cat > "$verify_tmp_dir/phase-cd-next-execution-report.md" <<EOF
# Phase C/D next execution report
EOF
cat > "$verify_tmp_dir/phase-cd-preflight-memory-state-task-board.json" <<EOF
{"schema_version":1,"tasks":[]}
EOF
cat > "$verify_tmp_dir/phase-cd-preflight-memory-state-task-board.md" <<EOF
# Phase C/D preflight memory-state task board
EOF
cat > "$verify_tmp_dir/phase-cd-preflight-memory-state-execution-report.md" <<EOF
# Phase C/D preflight memory-state execution report
EOF
cat > "$verify_tmp_dir/execution-time-contract-preflight-memory-state.json" <<EOF
{"schema_version":1,"within_one_minute":true}
EOF
cat > "$verify_tmp_dir/execution-time-contract-preflight-memory-state.md" <<EOF
# Execution time contract preflight memory-state
EOF
cat > "$verify_tmp_dir/execution-time-contract-timer-guard.json" <<EOF
{"schema_version":1,"within_one_minute":true}
EOF
cat > "$verify_tmp_dir/execution-time-contract-timer-guard.md" <<EOF
# Execution time contract timer guard
EOF
cat > "$verify_tmp_dir/timer-guard.marker" <<EOF
closed
EOF

reset_verify_fixture() {
  cat > "$verify_tmp_dir/state-evaluation.json" <<EOF
{"schema_version":1,"to":"done","checks":{"remote_write_completed":"YES"}}
EOF
  cat > "$verify_tmp_dir/metadata-draft.json" <<EOF
{"schema_version":1,"metadata":{"pipeline_status":"done","strict_gate":"PASSED"}}
EOF
  cat > "$verify_tmp_dir/gate-policy-check.json" <<EOF
{"schema_version":1,"result":"PASSED","task_type":"documentation"}
EOF
}

checks=()
check_fail_count=0
run_check() {
  local name="$1"
  shift
  if "$@" >/tmp/verify-toolchain.out 2>/tmp/verify-toolchain.err; then
    checks+=("| ${name} | PASSED | |")
  else
    local error
    error="$(cat /tmp/verify-toolchain.err /tmp/verify-toolchain.out 2>/dev/null | tr '\n' ' ' | sed 's/|/-/g')"
    checks+=("| ${name} | FAILED | ${error} |")
    check_fail_count=$((check_fail_count + 1))
  fi
}

run_check "bash -n scripts/verify-toolchain.sh" bash -n scripts/verify-toolchain.sh
run_check "bash -n scripts/multica-loop.sh" bash -n scripts/multica-loop.sh
run_check "bash -n scripts/evidence-checklist.sh" bash -n scripts/evidence-checklist.sh
run_check "bash -n scripts/evidence-index.sh" bash -n scripts/evidence-index.sh
run_check "bash -n scripts/patch-summary.sh" bash -n scripts/patch-summary.sh
run_check "bash -n scripts/review-packet.sh" bash -n scripts/review-packet.sh
run_check "bash -n scripts/collect-evidence.sh" bash -n scripts/collect-evidence.sh
run_check "bash -n scripts/evaluate-state.sh" bash -n scripts/evaluate-state.sh
run_check "bash -n scripts/metadata-draft.sh" bash -n scripts/metadata-draft.sh
run_check "bash -n scripts/refresh-run-evidence.sh" bash -n scripts/refresh-run-evidence.sh
run_check "bash -n scripts/share-preflight.sh" bash -n scripts/share-preflight.sh
run_check "bash -n scripts/obsidian-sync.sh" bash -n scripts/obsidian-sync.sh
run_check "bash -n scripts/daily-ops-sync.sh" bash -n scripts/daily-ops-sync.sh
run_check "bash -n scripts/route-actor.sh" bash -n scripts/route-actor.sh
run_check "bash -n scripts/requirement-gate.sh" bash -n scripts/requirement-gate.sh
run_check "bash -n scripts/clarification-gate.sh" bash -n scripts/clarification-gate.sh
run_check "bash -n scripts/design-gate.sh" bash -n scripts/design-gate.sh
run_check "bash -n scripts/deliverable-gate.sh" bash -n scripts/deliverable-gate.sh
run_check "bash -n scripts/gate-policy-check.sh" bash -n scripts/gate-policy-check.sh
run_check "bash -n scripts/gate-policy-exception.sh" bash -n scripts/gate-policy-exception.sh
run_check "bash -n scripts/metadata-writeback.sh" bash -n scripts/metadata-writeback.sh
run_check "bash -n scripts/approval-boundary.sh" bash -n scripts/approval-boundary.sh
run_check "bash -n scripts/smoke-multica-writeback.sh" bash -n scripts/smoke-multica-writeback.sh
run_check "bash -n scripts/writeback-summary-json.sh" bash -n scripts/writeback-summary-json.sh
run_check "bash -n scripts/golden-path-check.sh" bash -n scripts/golden-path-check.sh
run_check "bash -n scripts/loop-execution-preflight.sh" bash -n scripts/loop-execution-preflight.sh
run_check "bash -n scripts/loop-closeout.sh" bash -n scripts/loop-closeout.sh
run_check "bash -n scripts/loop-continuation-gate.sh" bash -n scripts/loop-continuation-gate.sh
run_check "bash -n scripts/time-estimation-calibration.sh" bash -n scripts/time-estimation-calibration.sh
run_check "bash -n scripts/archive-run-artifacts.sh" bash -n scripts/archive-run-artifacts.sh
run_check "bash -n scripts/execution-time-contract.sh" bash -n scripts/execution-time-contract.sh
run_check "bash -n scripts/execution-timer.sh" bash -n scripts/execution-timer.sh
run_check "bash -n scripts/sinan-capability-check.sh" bash -n scripts/sinan-capability-check.sh
run_check "bash -n scripts/sinan-fitness-check.sh" bash -n scripts/sinan-fitness-check.sh
run_check "bash -n scripts/intent-ambiguity-gate.sh" bash -n scripts/intent-ambiguity-gate.sh
run_check "bash -n scripts/phase-i-task-queue.sh" bash -n scripts/phase-i-task-queue.sh
run_check "bash -n scripts/north-star-task-board.sh" bash -n scripts/north-star-task-board.sh
run_check "bash -n scripts/token-efficiency-audit.sh" bash -n scripts/token-efficiency-audit.sh
run_check "bash -n scripts/sinan-flow-advisor.sh" bash -n scripts/sinan-flow-advisor.sh
run_check "bash -n scripts/multi-repo-evidence.sh" bash -n scripts/multi-repo-evidence.sh
run_check "bash -n scripts/sinan-ops-dashboard.sh" bash -n scripts/sinan-ops-dashboard.sh
run_check "bash -n scripts/external-adapter-check.sh" bash -n scripts/external-adapter-check.sh
run_check "bash -n scripts/sinan-v2-acceptance.sh" bash -n scripts/sinan-v2-acceptance.sh
run_check "bash -n scripts/sinan.sh" bash -n scripts/sinan.sh
run_check "gate-policy json" python3 -m json.tool config/gate-policy.json
run_check "sinan-version json" python3 -m json.tool config/sinan-version.json
run_check "sinan v1 release docs" bash -c '
  set -euo pipefail
  test -s docs/ai-work-orchestration/VERSION.md
  test -s docs/ai-work-orchestration/Known-Limits.md
  test -s docs/ai-work-orchestration/backlog-v1.1.md
  test -s docs/ai-work-orchestration/share/sinan-v1.0-release-notes.md
  test -s runs/v1.0-final/acceptance-report.md
  rg -q "v1.0" docs/ai-work-orchestration/VERSION.md
  rg -q "已知限制" docs/ai-work-orchestration/Known-Limits.md
  rg -q "Backlog" docs/ai-work-orchestration/backlog-v1.1.md
  rg -q "司南 v1.0" docs/ai-work-orchestration/share/sinan-v1.0-release-notes.md
  rg -q "Status: RELEASED" runs/v1.0-final/acceptance-report.md
  python3 - <<PY
import json
with open("config/sinan-version.json", encoding="utf-8") as fh:
    data = json.load(fh)
assert data["product"] == "司南"
assert data["version"] == "1.0.0"
assert data["status"] == "released"
assert "no_deploy_performed" in data["release_gates"]
PY
'
run_check "gate specs and fixtures" bash -c '
  set -euo pipefail
  test -s docs/ai-work-orchestration/gates/requirement-gate-spec.md
  test -s docs/ai-work-orchestration/gates/design-gate-spec.md
  test -s docs/ai-work-orchestration/gates/deliverable-gate-spec.md
  test -s memory/templates/requirement-clarification-template.md
  rg -q "Requirement Gate Spec" docs/ai-work-orchestration/gates/requirement-gate-spec.md
  rg -q "Design Gate Spec" docs/ai-work-orchestration/gates/design-gate-spec.md
  rg -q "Deliverable Gate Spec" docs/ai-work-orchestration/gates/deliverable-gate-spec.md
  rg -q "需求澄清模板" memory/templates/requirement-clarification-template.md
  ./scripts/requirement-gate.sh --input fixtures/gates/requirement-pass.md --issue FUZ-999 --output /tmp/requirement-gate-fixture-$1.md --clarification-output /tmp/requirement-clarification-fixture-$1.md >/tmp/requirement-gate-fixture-$1.out
  ./scripts/design-gate.sh --input fixtures/gates/design-pass.md --issue FUZ-999 --strict --output /tmp/design-gate-fixture-$1.md >/tmp/design-gate-fixture-$1.out
  ./scripts/deliverable-gate.sh --input fixtures/gates/deliverable-pass.md --issue FUZ-999 --output /tmp/deliverable-gate-fixture-$1.md >/tmp/deliverable-gate-fixture-$1.out
  rg -q "Result: PASSED" /tmp/requirement-gate-fixture-$1.md
  rg -q "Score: 100/100" /tmp/requirement-gate-fixture-$1.md
  rg -q "Result: PASSED" /tmp/design-gate-fixture-$1.md
  rg -q "Score: 100/100" /tmp/design-gate-fixture-$1.md
  rg -q "Result: PASSED" /tmp/deliverable-gate-fixture-$1.md
  rg -q "Score: 100/100" /tmp/deliverable-gate-fixture-$1.md
' _ "$case_id"
run_check "approval-boundary json" python3 -m json.tool config/approval-boundary.json
run_check "timebox-policy json" python3 -m json.tool config/timebox-policy.json
run_check "sinan-capabilities json" python3 -m json.tool config/sinan-capabilities.json
run_check "sinan v2 local docs" bash -c '
  set -euo pipefail
  test -s docs/ai-work-orchestration/product/sinan-v1-to-v2-roadmap.md
  test -s docs/ai-work-orchestration/product/sinan-onboarding-drill.md
  test -s docs/ai-work-orchestration/product/cross-repo-evidence-contract.md
  test -s docs/ai-work-orchestration/29-token-efficiency.md
  test -s memory/templates/token-efficient-handoff-template.md
  rg -q "本地验收套件" docs/ai-work-orchestration/product/sinan-v1-to-v2-roadmap.md
  rg -q "30 分钟" docs/ai-work-orchestration/product/sinan-onboarding-drill.md
  rg -q "Multi-repo" docs/ai-work-orchestration/product/cross-repo-evidence-contract.md || rg -q "多仓库" docs/ai-work-orchestration/product/cross-repo-evidence-contract.md
  rg -q "Token 使用率治理" docs/ai-work-orchestration/29-token-efficiency.md
  rg -q "不要重复读取" memory/templates/token-efficient-handoff-template.md
'
run_check "evidence-artifacts json" python3 -m json.tool config/evidence-artifacts.json
run_check "sinan-fitness-checks json" python3 -m json.tool config/sinan-fitness-checks.json
run_check "intent-ambiguity-policy json" python3 -m json.tool config/intent-ambiguity-policy.json
run_check "north-star-tasks json" python3 -m json.tool config/north-star-tasks.json
run_check "phase-cd-tasks json" python3 -m json.tool config/phase-cd-tasks.json
run_check "project-memory-policy json" python3 -m json.tool config/project-memory-policy.json
run_check "organization-policy json" python3 -m json.tool config/organization-policy.json
run_check "routing-policy json" python3 -m json.tool config/routing-policy.json
run_check "phase-cd-next-tasks json" python3 -m json.tool config/phase-cd-next-tasks.json
run_check "bash -n scripts/memory-quality-check.sh" bash -n scripts/memory-quality-check.sh
run_check "bash -n scripts/organization-policy-report.sh" bash -n scripts/organization-policy-report.sh
run_check "sinan-capability-check" ./scripts/sinan-capability-check.sh --output "/tmp/sinan-capability-check-${case_id}.md" --json-output "/tmp/sinan-capability-check-${case_id}.json"
run_check "north-star redirected" bash -c '
  set -euo pipefail
  rg -q "2026-06 重定向：近期北极星" docs/ai-work-orchestration/09-north-star.md
  rg -q "Phase I：可验收结果与时间校准" docs/ai-work-orchestration/09-north-star.md
  rg -q "within_one_minute" docs/ai-work-orchestration/09-north-star.md
  rg -q "不做自动 reviewer" docs/ai-work-orchestration/09-north-star.md
  rg -q "09-north-star.md#2026-06-重定向近期北极星" docs/ai-work-orchestration/README.md
'
run_check "phase i timing docs" bash -c '
  set -euo pipefail
  rg -q -- "--task-type documentation" docs/ai-work-orchestration/share/time-estimation-calibration-guide.md
  rg -q "absolute_error_minutes" docs/ai-work-orchestration/share/time-estimation-calibration-guide.md
  rg -q "within_one_minute" docs/ai-work-orchestration/share/time-estimation-calibration-guide.md
  rg -q "one_minute_hit_rate" docs/ai-work-orchestration/share/time-estimation-calibration-guide.md
  rg -q -- "--task-type <type>" docs/ai-work-orchestration/share/sinan-continuous-execution-guide.md
  rg -q "absolute_error_minutes" docs/ai-work-orchestration/share/sinan-continuous-execution-guide.md
  rg -q "长循环进展压缩" docs/ai-work-orchestration/share/sinan-continuous-execution-guide.md
  rg -F -q "短句 + 证据优先" docs/ai-work-orchestration/share/sinan-continuous-execution-guide.md
  rg -q "open_minutes" docs/ai-work-orchestration/share/sinan-continuous-execution-guide.md
  rg -q "done_minutes" docs/ai-work-orchestration/share/sinan-continuous-execution-guide.md
  rg -q "task_quantity_first_calibration_second" docs/ai-work-orchestration/share/sinan-continuous-execution-guide.md
  rg -q "calibrated_estimate_minutes" docs/ai-work-orchestration/share/sinan-continuous-execution-guide.md
'
run_check "sinan-capability-check assertions" python3 - <<'PY' "/tmp/sinan-capability-check-${case_id}.json"
import json
import sys
with open(sys.argv[1], encoding="utf-8") as fh:
    data = json.load(fh)
assert data["result"] == "PASSED"
assert data["failed_checks"] == 0
ids = {item["id"] for item in data["capabilities"]}
assert "trusted_timing_calibration" in ids
assert "token_output_compression" in ids
assert "controlled_writeback" in ids
assert "obsidian_knowledge_sync" in ids
trusted = next(item for item in data["capabilities"] if item["id"] == "trusted_timing_calibration")
assert "docs/ai-work-orchestration/25-execution-time-contract.md" in trusted["docs"]
assert "scripts/execution-time-contract.sh" in trusted["entrypoints"]
compression = next(item for item in data["capabilities"] if item["id"] == "token_output_compression")
assert "~/.agents/skills/caveman/SKILL.md" in compression["external_tools"]
assert "~/.agents/skills/cavecrew/SKILL.md" in compression["external_tools"]
evidence = next(item for item in data["capabilities"] if item["id"] == "evidence_closeout")
assert "scripts/phase-i-task-queue.sh" in evidence["entrypoints"]
assert "runs/<run-id>/phase-i-task-queue.md" in evidence["evidence_outputs"]
assert "runs/<run-id>/phase-i-task-queue.json" in evidence["evidence_outputs"]
assert "scripts/phase-i-task-queue.sh --run-id <run-id> --target-minutes 30" in evidence["verification"]
phase_c = next(item for item in data["capabilities"] if item["id"] == "phase_c_organization_layer")
assert "docs/ai-work-orchestration/28-organization-contracts.md" in phase_c["docs"]
assert "config/routing-policy.json" in phase_c["configs"]
ids = {item["id"] for item in data["capabilities"]}
assert "token_efficiency_governance" in ids
assert "adaptive_flow_advisor" in ids
assert "v2_acceptance_platformization" in ids
PY
run_check "sinan v2 smoke" bash -c '
  set -euo pipefail
  tmp_run="$1-v2-smoke"
  tmp_dir="runs/${tmp_run}"
  rm -rf "$tmp_dir"
  mkdir -p "$tmp_dir"
  cat > "$tmp_dir/summary.md" <<MD
# v2 Smoke Summary

Local-only v2 smoke run.
MD
  cat > "$tmp_dir/v2-gap-audit.md" <<MD
# v2 Gap Audit

Local-only smoke gap audit.
MD
  ./scripts/token-efficiency-audit.sh --run-id "$tmp_run" --output "/tmp/token-audit-$1.md" --json-output "/tmp/token-audit-$1.json" >/tmp/token-audit-$1.out
  ./scripts/sinan-flow-advisor.sh --task tasks/sinan-v2-loop-20260624.md --output "/tmp/flow-advice-$1.md" --json-output "/tmp/flow-advice-$1.json" >/tmp/flow-advice-$1.out
  ./scripts/multi-repo-evidence.sh --run-id "$tmp_run" --repo . --output "/tmp/multi-repo-$1.md" --json-output "/tmp/multi-repo-$1.json" >/tmp/multi-repo-$1.out
  ./scripts/sinan-ops-dashboard.sh --pattern "${tmp_run}" --output "/tmp/ops-dashboard-$1.md" --json-output "/tmp/ops-dashboard-$1.json" >/tmp/ops-dashboard-$1.out
  ./scripts/external-adapter-check.sh --target local-smoke --schema config/approval-boundary.json --readback "/tmp/token-audit-$1.json" --output "/tmp/external-adapter-$1.md" --json-output "/tmp/external-adapter-$1.json" >/tmp/external-adapter-$1.out
  ./scripts/sinan-v2-acceptance.sh --run-id "$tmp_run" --output "/tmp/v2-acceptance-$1.md" --json-output "/tmp/v2-acceptance-$1.json" >/tmp/v2-acceptance-$1.out
  ./scripts/sinan.sh flow-advisor --task tasks/sinan-v2-loop-20260624.md >/tmp/sinan-cli-flow-$1.out
  python3 - <<PY "/tmp/token-audit-$1.json" "/tmp/flow-advice-$1.json" "/tmp/multi-repo-$1.json" "/tmp/ops-dashboard-$1.json" "/tmp/external-adapter-$1.json" "/tmp/v2-acceptance-$1.json"
import json
import sys
token, flow, multi, ops, adapter, accept = [json.load(open(path, encoding="utf-8")) for path in sys.argv[1:]]
assert token["result"] in {"PASSED", "WARN", "FAILED"}
assert flow["tier"] in {"L1", "L2", "L3", "L4"}
assert multi["repos"] and multi["approval_required"] is False
assert ops["run_count"] >= 1
assert adapter["result"] == "PASSED"
assert accept["result"] == "PASSED"
PY
  rg -q "Sinan Flow Advice" /tmp/sinan-cli-flow-$1.out
  rm -rf "$tmp_dir"
' _ "$case_id"
run_check "sinan-capability-check markdown escaping" bash -c '
  set -euo pipefail
  registry="/tmp/sinan-capability-escaping-$1.json"
  cat > "$registry" <<JSON
{
  "schema_version": 1,
  "capabilities": [
    {
      "id": "escape_probe",
      "name": "Escape <Probe>",
      "status": "ready|active",
      "phase": "Phase <X>",
      "entrypoints": ["scripts/verify-toolchain.sh"],
      "external_tools": ["~/.agents/skills/caveman/SKILL.md"],
      "configs": [],
      "evidence_outputs": ["path<a|b>"],
      "docs": ["docs/ai-work-orchestration/README.md"],
      "verification": ["echo a|b"],
      "side_effect_policy": "policy <safe>|local"
    }
  ]
}
JSON
  ./scripts/sinan-capability-check.sh --registry "$registry" --output "/tmp/sinan-capability-escaping-$1.md" --json-output "/tmp/sinan-capability-escaping-$1.json" >/dev/null
  python3 - <<PY "/tmp/sinan-capability-escaping-$1.json"
import json
import sys
with open(sys.argv[1], encoding="utf-8") as fh:
    data = json.load(fh)
assert data["result"] == "PASSED"
PY
  rg -q "Escape &lt;Probe&gt;" "/tmp/sinan-capability-escaping-$1.md"
  rg -q "ready-active" "/tmp/sinan-capability-escaping-$1.md"
  rg -q "echo a-b" "/tmp/sinan-capability-escaping-$1.md"
  ! rg -F -q "ready|active" "/tmp/sinan-capability-escaping-$1.md"
  ! rg -F -q "echo a|b" "/tmp/sinan-capability-escaping-$1.md"
' _ "$case_id"
run_check "phase-i-task-queue" ./scripts/phase-i-task-queue.sh --run-id "$first_run" --target-minutes 30 --output "/tmp/phase-i-task-queue-${case_id}.md" --json-output "/tmp/phase-i-task-queue-${case_id}.json"
run_check "single-task smoke fixture" bash -c '
  set -euo pipefail
  smoke_run="$1-smoke-fixture"
  smoke_dir="runs/$smoke_run"
  rm -rf "$smoke_dir"
  mkdir -p "$smoke_dir"
  cat > "$smoke_dir/summary.md" <<MD
# Smoke Summary

Minimal local fixture for plan/run/evidence/review/writeback gate.
MD
  cat > "$smoke_dir/stage-report.md" <<MD
# Smoke Stage Report

Local-only smoke fixture.
MD
  cat > "$smoke_dir/multica-comment.md" <<MD
# Smoke Comment

No remote write.
MD
  cat > "$smoke_dir/state-evaluation.json" <<JSON
{"schema_version":1,"to":"review","required_next_actor":"reviewer","checks":{}}
JSON
  cat > "$smoke_dir/metadata-draft.json" <<JSON
{"schema_version":1,"metadata":{"key":"smoke","value":"ready"}}
JSON
  ./scripts/collect-evidence.sh --issue "$1" --run-id "$smoke_run" --output "/tmp/smoke-evidence-$1.json" --markdown "/tmp/smoke-evidence-$1.md" >/tmp/smoke-evidence-$1.out || true
  ./scripts/review-packet.sh --case "$1" --pattern "$smoke_run" --output "/tmp/smoke-review-$1.md" >/tmp/smoke-review-$1.out
  if ./scripts/writeback-gate.sh --issue "$1" --run-id "$smoke_run" --type comment --output "/tmp/smoke-writeback-no-$1.json" >/tmp/smoke-writeback-no-$1.out; then
    rm -rf "$smoke_dir"
    exit 1
  fi
  ./scripts/writeback-gate.sh --issue "$1" --run-id "$smoke_run" --type comment --approved-by smoke --output "/tmp/smoke-writeback-yes-$1.json" >/tmp/smoke-writeback-yes-$1.out
  python3 - <<PY "/tmp/smoke-writeback-yes-$1.json"
import json
import sys
data = json.load(open(sys.argv[1], encoding="utf-8"))
assert data["allowed"] is True
assert data["readback"]["required_after_write"] is True
PY
  rm -rf "$smoke_dir"
' _ "$case_id" "$first_run"
run_check "phase-i-task-queue assertions" python3 - <<'PY' "/tmp/phase-i-task-queue-${case_id}.json"
import json
import sys
with open(sys.argv[1], encoding="utf-8") as fh:
    data = json.load(fh)
assert data["target_minutes"] == 30
assert data["planned_minutes"] <= 30
assert data["planned_minutes"] >= 25
assert "open_minutes" in data
assert "done_minutes" in data
assert data["open_minutes"] >= 25
assert data["open_candidates"] >= 1
assert data["queue"]
ids = {item["id"] for item in data["queue"]}
candidate_ids = set(data["candidate_ids"])
assert "final-evidence-sync" in ids
assert "obsidian-generated-readback" in ids
assert "evidence-queue-readback" in candidate_ids
assert "strict-regression-recheck" in candidate_ids
assert "generated-index-readback" in candidate_ids
assert all("status" in item and "status_reason" in item for item in data["queue"])
assert any(item["status"] == "todo" for item in data["queue"])
assert data["candidates_seen"] >= len(data["queue"])
PY
run_check "north-star-task-board" ./scripts/north-star-task-board.sh --run-id "$first_run" --target-minutes 30 --output "/tmp/north-star-task-board-${case_id}.md" --json-output "/tmp/north-star-task-board-${case_id}.json"
run_check "north-star-task-board assertions" python3 - <<'PY' "/tmp/north-star-task-board-${case_id}.json"
import json
import sys
with open(sys.argv[1], encoding="utf-8") as fh:
    data = json.load(fh)
assert data["target_minutes"] == 30
assert data["estimation_model"]["rule"] == "task_quantity_first_calibration_second"
assert data["summary"]["total_tasks"] >= 8
assert data["summary"]["calibrated_open_minutes"] >= 0
assert data["tasks"]
for row in data["tasks"]:
    assert "raw_estimate_minutes" in row
    assert "calibrated_estimate_minutes" in row
    assert "calibration_bucket" in row
    assert "calibration_confidence" in row
assert any(row["id"] == "NST-002" for row in data["tasks"])
PY
run_check "phase-cd-task-board" ./scripts/north-star-task-board.sh --run-id "$first_run" --tasks config/phase-cd-tasks.json --target-minutes 30 --output "/tmp/phase-cd-task-board-${case_id}.md" --json-output "/tmp/phase-cd-task-board-${case_id}.json"
run_check "phase-cd-task-board assertions" python3 - <<'PY' "/tmp/phase-cd-task-board-${case_id}.json"
import json
import sys
with open(sys.argv[1], encoding="utf-8") as fh:
    data = json.load(fh)
assert data["summary"]["total_tasks"] >= 9
assert any(row["id"] == "CD-001" for row in data["tasks"])
assert any(row["id"] == "CD-006" for row in data["tasks"])
for row in data["tasks"]:
    assert "raw_estimate_minutes" in row
    assert "calibrated_estimate_minutes" in row
PY
run_check "memory-quality-check" ./scripts/memory-quality-check.sh --output "/tmp/memory-quality-${case_id}.md" --json-output "/tmp/memory-quality-${case_id}.json"
run_check "memory-quality assertions" python3 - <<'PY' "/tmp/memory-quality-${case_id}.json"
import json
import sys
with open(sys.argv[1], encoding="utf-8") as fh:
    data = json.load(fh)
assert data["result"] == "PASSED"
assert data["entry_count"] > 0
assert data["failed_checks"] == 0
PY
run_check "memory-query tag search" bash -c '
  set -euo pipefail
  ./scripts/memory-query.sh --tag timing >/tmp/memory-query-tag-$1.out
  rg -q "CASE-FUZ-554-NORTH-STAR-TASK-BOARD" /tmp/memory-query-tag-$1.out
  rg -q "Review state: accepted" /tmp/memory-query-tag-$1.out
' _ "$case_id"
run_check "recommend-memory schema" bash -c '
  set -euo pipefail
  ./scripts/recommend-memory.sh --query "north-star timing evidence sinan" --output "/tmp/recommend-memory-$1.json" --markdown "/tmp/recommend-memory-$1.md" --limit 3 >/tmp/recommend-memory-$1.out
  python3 - <<PY "/tmp/recommend-memory-$1.json"
import json
import sys
with open(sys.argv[1], encoding="utf-8") as fh:
    data = json.load(fh)
assert data["schema_version"] == 1
assert data["result"] == "PASSED"
assert data["remote_writes"] is False
assert data["recommendations"]
first = data["recommendations"][0]
assert {"type", "id", "confidence", "reason", "path"}.issubset(first)
assert first["id"] == "CASE-FUZ-554-NORTH-STAR-TASK-BOARD"
PY
' _ "$case_id"
run_check "memory-review-state help" ./scripts/memory-review-state.sh --help
run_check "execution-timer smoke" bash -c '
  set -euo pipefail
  timer_name="verify-timer-$2"
  rm -f "runs/$1/timers/${timer_name}.start.json" "runs/$1/execution-time-contract-${timer_name}.md" "runs/$1/execution-time-contract-${timer_name}.json"
  ./scripts/execution-timer.sh start --run-id "$1" --name "$timer_name" --estimate-minutes 1-2 --basis "verify timer smoke" --task-type local_script_patch --stop-condition "timer smoke verified" >/tmp/execution-timer-start-$2.out
  ./scripts/execution-timer.sh close --run-id "$1" --name "$timer_name" --max-age-minutes 5 >/tmp/execution-timer-close-$2.out
  python3 - <<PY "runs/$1/execution-time-contract-${timer_name}.json" "runs/$1/timers/${timer_name}.start.json"
import json
import sys
contract = json.load(open(sys.argv[1], encoding="utf-8"))
marker = json.load(open(sys.argv[2], encoding="utf-8"))
assert marker["state"] == "closed"
assert contract["estimate_minutes"] == "1-2"
assert contract["elapsed_seconds"] is not None
PY
' _ "$verify_tmp_run" "$case_id"
run_check "execution-timer stale guard" bash -c '
  set -euo pipefail
  timer_name="verify-stale-$2"
  marker="runs/$1/timers/${timer_name}.start.json"
  mkdir -p "runs/$1/timers"
  python3 - <<PY "$marker" "$1" "$timer_name"
import datetime as dt
import json
import sys
from pathlib import Path
path, run_id, name = sys.argv[1:]
started = (dt.datetime.now(dt.timezone.utc) - dt.timedelta(minutes=10)).replace(microsecond=0).isoformat().replace("+00:00", "Z")
data = {"schema_version": 1, "run_id": run_id, "name": name, "estimate_minutes": "1", "basis": "stale", "task_type": "local_script_patch", "stop_condition": "stale guard", "started_at": started, "state": "started"}
Path(path).write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
PY
  if ./scripts/execution-timer.sh close --run-id "$1" --name "$timer_name" --max-age-minutes 1 >/tmp/execution-timer-stale-$2.out 2>/tmp/execution-timer-stale-$2.err; then
    exit 1
  fi
  rg -q "Timer marker is stale" /tmp/execution-timer-stale-$2.err
' _ "$verify_tmp_run" "$case_id"
run_check "memory-review-state transition" bash -c '
  set -euo pipefail
  temp_index=$(mktemp)
  python3 - <<PY memory/index.json "$temp_index"
import json
import sys
from pathlib import Path
source, target = sys.argv[1:]
data = json.loads(Path(source).read_text(encoding="utf-8"))
for item in data.get("cases", []):
    if item.get("id") == "CASE-FUZ-554-NORTH-STAR-TASK-BOARD":
        item["review_state"] = "reviewed"
Path(target).write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
PY
  cleanup() { rm -f "$temp_index"; }
  trap cleanup EXIT
  ./scripts/memory-review-state.sh --case-id CASE-FUZ-554-NORTH-STAR-TASK-BOARD --from reviewed --to accepted --index "$temp_index" --execute --output "/tmp/memory-review-state-$2.md" --json-output "/tmp/memory-review-state-$2.json"
  python3 - <<PY "/tmp/memory-review-state-$2.json"
import json
import sys
with open(sys.argv[1], encoding="utf-8") as fh:
    data = json.load(fh)
assert data["result"] == "PASSED"
assert data["from_state"] == "reviewed"
assert data["to_state"] == "accepted"
assert data["expected_from"] == "reviewed"
assert data["execute"] is True
assert data["changed"] is True
assert data["side_effects"] == [data["index"]]
PY
' _ "$first_run" "$case_id"
run_check "memory-review-state illegal transition" bash -c '
  set -euo pipefail
  temp_index=$(mktemp)
  cp memory/index.json "$temp_index"
  if ./scripts/memory-review-state.sh --case-id CASE-FUZ-554-NORTH-STAR-TASK-BOARD --to draft --index "$temp_index" >/tmp/memory-review-state-illegal-$1.out 2>/tmp/memory-review-state-illegal-$1.err; then
    rm -f "$temp_index"
    exit 1
  fi
  rm -f "$temp_index"
  grep -Eq "transition_allowed.*FAILED|Result: FAILED" /tmp/memory-review-state-illegal-$1.out
' _ "$case_id"
run_check "organization-policy-report" ./scripts/organization-policy-report.sh --issue "$case_id" --run-id "$first_run" --output "/tmp/organization-policy-report-${case_id}.md" --json-output "/tmp/organization-policy-report-${case_id}.json"
run_check "organization-policy-report assertions" python3 - <<'PY' "/tmp/organization-policy-report-${case_id}.json"
import json
import sys
with open(sys.argv[1], encoding="utf-8") as fh:
    data = json.load(fh)
assert data["result"] == "PASSED"
assert "contracts" in data
assert "routing" in data["contracts"]
assert {module["id"] for module in data["modules"]} == {"routing", "policy", "side_effect_gate", "review_orchestration"}
PY
run_check "extract-experience structured" ./scripts/extract-experience.sh --run-id "$first_run" --output "/tmp/experience-draft-${case_id}.md" --json-output "/tmp/experience-draft-${case_id}.json"
run_check "extract-experience structured assertions" python3 - <<'PY' "/tmp/experience-draft-${case_id}.json"
import json
import sys
with open(sys.argv[1], encoding="utf-8") as fh:
    data = json.load(fh)
assert data["schema_version"] == 1
assert data["review_state"] == "draft"
assert data["source_artifacts"]
assert data["human_review_required"] is True
PY
run_check "codex caveman skills visible" bash -c '
  set -euo pipefail
  npx -y skills list --global -a codex --json >/tmp/codex-skills-global-$1.json
  python3 - <<PY /tmp/codex-skills-global-$1.json
import json
import sys
with open(sys.argv[1], encoding="utf-8") as fh:
    data = json.load(fh)
names = {item.get("name") for item in data}
for required in ["caveman", "cavecrew", "caveman-compress", "caveman-review", "caveman-commit"]:
    assert required in names
PY
' _ "$case_id"
run_check "multica-loop --policy-help" ./scripts/multica-loop.sh --policy-help
run_check "multica-loop --help" ./scripts/multica-loop.sh --help
run_check "multica-loop timebox help" bash -c './scripts/multica-loop.sh --help >/tmp/multica-loop-help.out; rg -q -- "--task-tier" /tmp/multica-loop-help.out; rg -q -- "--elapsed-minutes" /tmp/multica-loop-help.out'
run_check "multica-loop metadata approval required" bash -c './scripts/multica-loop.sh --issue "$1" --repo . --task-tier L2 --elapsed-minutes 30 --write-metadata >/tmp/multica-loop-metadata-approval.out 2>/tmp/multica-loop-metadata-approval.err; test "$?" -eq 2' _ "$case_id"
run_check "multica-loop comment approval required" bash -c './scripts/multica-loop.sh --issue "$1" --repo . --write-comment >/tmp/multica-loop-comment-approval.out 2>/tmp/multica-loop-comment-approval.err; test "$?" -eq 2' _ "$case_id"
run_check "multica-loop status approval required" bash -c './scripts/multica-loop.sh --issue "$1" --repo . --write-status >/tmp/multica-loop-status-approval.out 2>/tmp/multica-loop-status-approval.err; test "$?" -eq 2' _ "$case_id"
run_check "multica-loop timebox smoke" bash -c '
  set -euo pipefail
  tmpdir=$(mktemp -d)
  smoke_run="$1-verify-timebox-smoke"
  cleanup() {
    rm -rf "$tmpdir" "runs/$smoke_run"
  }
  trap cleanup EXIT
  mkdir -p "$tmpdir/bin"
  cat > "$tmpdir/bin/multica" <<"SH"
#!/usr/bin/env bash
case "$*" in
  "issue get FUZ-554 --output json")
    cat <<"JSON"
{
  "identifier": "FUZ-554",
  "number": 554,
  "title": "Phase 1：首个案例复盘",
  "description": "选择一个低风险试点，完整记录从 issue 到 evidence 的闭环案例。",
  "labels": [{"name":"调研"}]
}
JSON
    ;;
  "issue metadata list FUZ-554 --output json") printf "{}\\n" ;;
  *) printf "unexpected fake multica call: %s\\n" "$*" >&2; exit 64 ;;
esac
SH
  chmod +x "$tmpdir/bin/multica"
  PATH="$tmpdir/bin:$PATH" ./scripts/multica-loop.sh --issue "$1" --repo . --run-id "$smoke_run" --task-tier L2 --elapsed-minutes 30 --status-policy no-status >/tmp/multica-loop-timebox-smoke.out
  rg -q "continuation_decision: CONTINUE" /tmp/multica-loop-timebox-smoke.out
  rg -q "execution_time_contract: runs/$smoke_run/execution-time-contract.md" /tmp/multica-loop-timebox-smoke.out
  rg -q "time_estimation_calibration: runs/$smoke_run/time-estimation-calibration.md" /tmp/multica-loop-timebox-smoke.out
  rg -q "Execution preflight" "runs/$smoke_run/stage-report.md"
  rg -q "Continuation decision: CONTINUE" "runs/$smoke_run/stage-report.md"
  rg -q "Execution time contract: runs/$smoke_run/execution-time-contract.md" "runs/$smoke_run/stage-report.md"
  rg -q "Time estimation calibration: runs/$smoke_run/time-estimation-calibration.md" "runs/$smoke_run/stage-report.md"
  python3 - <<PY "runs/$smoke_run/execution-preflight.json" "runs/$smoke_run/continuation-gate.json" "runs/$smoke_run/time-estimation-calibration.json" "runs/$smoke_run/execution-time-contract.json"
import json
import sys
pre = json.load(open(sys.argv[1], encoding="utf-8"))
cont = json.load(open(sys.argv[2], encoding="utf-8"))
cal = json.load(open(sys.argv[3], encoding="utf-8"))
time_contract = json.load(open(sys.argv[4], encoding="utf-8"))
assert pre["timebox"]["tier"] == "L2"
assert pre["timebox"]["anti_idle_floor_minutes"] == 30
assert cont["decision"] == "CONTINUE"
assert cal["summary"]["manual_timing_runs"] == 0
assert cal["summary"]["trusted_measured_runs"] in (0, 1)
assert cal["runs"][0]["timing_source"] == "timestamp"
assert cal["runs"][0]["trusted_timing"] is True
assert time_contract["estimate_minutes"] == "90"
assert time_contract["completed_at"] == cont["completed_at"]
assert time_contract["elapsed_seconds"] == cont["elapsed_seconds"]
PY
' _ "$case_id"
run_check "multica-loop preflight task type passthrough" bash -c '
  set -euo pipefail
  smoke_run="$1-preflight-task-type-smoke"
  rm -rf "runs/$smoke_run"
  tmpdir=$(mktemp -d)
  cleanup() { rm -rf "$tmpdir" "runs/$smoke_run"; }
  trap cleanup EXIT
  mkdir -p "$tmpdir/bin"
  cat > "$tmpdir/bin/multica" <<"SH"
#!/usr/bin/env bash
case "$*" in
  "issue get FUZ-554 --output json")
    cat <<"JSON"
{
  "identifier": "FUZ-554",
  "number": 554,
  "title": "Phase I documentation timing",
  "description": "更新 north-star README script evidence calibration documentation smoke。",
  "labels": [{"name":"文档"}]
}
JSON
    ;;
  "issue metadata list FUZ-554 --output json") printf "{}\\n" ;;
  *) printf "unexpected fake multica call: %s\\n" "$*" >&2; exit 64 ;;
esac
SH
  chmod +x "$tmpdir/bin/multica"
  PATH="$tmpdir/bin:$PATH" ./scripts/multica-loop.sh --issue "$1" --repo . --run-id "$smoke_run" --task-type documentation --task-tier L2 --status-policy no-status >/tmp/multica-loop-preflight-task-type.out
  python3 - <<PY "runs/$smoke_run/execution-preflight.json"
import json
import sys
with open(sys.argv[1], encoding="utf-8") as fh:
    data = json.load(fh)
assert data["timebox"]["calibration"]["task_type"] == "documentation"
PY
' _ "$case_id"
run_check "classify-task heuristic" ./scripts/classify-task.sh --issue "$case_id" --ai-model none
run_check "collect-evidence" ./scripts/collect-evidence.sh --issue "$case_id" --run-id "$verify_tmp_run" --output "/tmp/collect-evidence-${case_id}.json" --markdown "/tmp/collect-evidence-${case_id}.md"
run_check "sinan-fitness-check" ./scripts/sinan-fitness-check.sh --run-id "$verify_tmp_run" --output "runs/$verify_tmp_run/sinan-fitness-check.md" --json-output "runs/$verify_tmp_run/sinan-fitness-check.json"
run_check "sinan-fitness-check assertions" python3 - <<'PY' "runs/${verify_tmp_run}/sinan-fitness-check.json"
import json
import sys
with open(sys.argv[1], encoding="utf-8") as fh:
    data = json.load(fh)
assert data["result"] in {"PASSED", "WARN"}
assert data["score"] >= 70
assert {"capability", "evidence", "memory", "organization", "timing"}.issubset(data["categories"].keys())
PY
run_check "intent-ambiguity-gate canonical" ./scripts/intent-ambiguity-gate.sh --text "继续推进司南建设" --output "runs/$verify_tmp_run/intent-ambiguity-gate.md" --json-output "runs/$verify_tmp_run/intent-ambiguity-gate.json"
run_check "intent-ambiguity-gate canonical assertions" python3 - <<'PY' "runs/${verify_tmp_run}/intent-ambiguity-gate.json"
import json
import sys
with open(sys.argv[1], encoding="utf-8") as fh:
    data = json.load(fh)
assert data["result"] == "PASSED"
assert data["requires_clarification"] is False
PY
run_check "intent-ambiguity-gate ambiguous blocks" bash -c '
  set -euo pipefail
  if ./scripts/intent-ambiguity-gate.sh --text "继续推进司南健身" --output "/tmp/intent-ambiguity-block-$1.md" --json-output "/tmp/intent-ambiguity-block-$1.json" >/tmp/intent-ambiguity-block-$1.out 2>/tmp/intent-ambiguity-block-$1.err; then
    exit 1
  fi
  python3 - <<PY "/tmp/intent-ambiguity-block-$1.json"
import json
import sys
with open(sys.argv[1], encoding="utf-8") as fh:
    data = json.load(fh)
assert data["result"] == "BLOCKED"
assert data["requires_clarification"] is True
assert data["clarification_questions"]
assert "司南健身" in data["clarification_questions"][0]
PY
' _ "$case_id"
run_check "collect-evidence after fitness" ./scripts/collect-evidence.sh --issue "$case_id" --run-id "$verify_tmp_run" --output "/tmp/collect-evidence-${case_id}.json" --markdown "/tmp/collect-evidence-${case_id}.md"
cp "/tmp/collect-evidence-${case_id}.json" "$verify_tmp_dir/evidence-summary.json"
cp "/tmp/collect-evidence-${case_id}.md" "$verify_tmp_dir/evidence-summary.md"
run_check "collect-evidence time artifacts" python3 - <<'PY' "/tmp/collect-evidence-${case_id}.json"
import json
import sys
with open(sys.argv[1], encoding="utf-8") as fh:
    data = json.load(fh)
artifacts = data["artifacts"]
timing = data["checks"]["timing_accuracy"]
registry = data["artifact_registry"]
assert registry["present"] is True
assert "core" in registry["groups"]
assert registry["artifacts"]["summary"]["present"] is True
assert "artifacts" in timing
assert timing["artifact_count"] >= 1
assert timing["trusted_measured_count"] >= 1
assert timing["latest"] is not None
assert "absolute_error_minutes" in timing["latest"]
assert "within_one_minute" in timing["latest"]
assert "recommended_next_estimate_minutes" in timing["latest"]
for key in [
    "continuation_gate",
    "continuation_gate_json",
    "execution_time_contract",
    "execution_time_contract_json",
    "time_estimation_calibration",
    "time_estimation_calibration_json",
    "phase_i_task_queue",
    "phase_i_task_queue_json",
    "north_star_task_board",
    "north_star_task_board_json",
    "north_star_execution_report",
    "phase_cd_task_board",
    "phase_cd_task_board_json",
    "phase_cd_execution_report",
    "memory_quality_report",
    "memory_quality_report_json",
    "organization_policy_report",
    "organization_policy_report_json",
    "experience_draft",
    "experience_draft_json",
    "memory_review_state",
    "memory_review_state_json",
    "phase_cd_next_task_board",
    "phase_cd_next_task_board_json",
    "phase_cd_next_execution_report",
    "phase_cd_preflight_memory_state_task_board",
    "phase_cd_preflight_memory_state_task_board_json",
    "phase_cd_preflight_memory_state_execution_report",
    "execution_time_contract_preflight_memory_state",
    "execution_time_contract_preflight_memory_state_json",
    "execution_time_contract_timer_guard",
    "execution_time_contract_timer_guard_json",
    "timer_guard_marker",
    "sinan_fitness_check",
    "sinan_fitness_check_json",
    "intent_ambiguity_gate",
    "intent_ambiguity_gate_json",
]:
    assert key in artifacts
PY
run_check "collect-evidence timing accuracy markdown" bash -c '
  set -euo pipefail
  rg -q "## Timing Accuracy" "/tmp/collect-evidence-$1.md"
  rg -q "Latest within_one_minute" "/tmp/collect-evidence-$1.md"
  rg -q "Latest absolute error minutes" "/tmp/collect-evidence-$1.md"
' _ "$case_id"
run_check "collect-evidence artifact registry markdown" bash -c '
  set -euo pipefail
  rg -q "## Artifact Registry" "/tmp/collect-evidence-$1.md"
  rg -q "Registry source: config/evidence-artifacts.json" "/tmp/collect-evidence-$1.md"
' _ "$case_id"
run_check "collect-evidence phase-i queue markdown" bash -c '
  set -euo pipefail
  rg -q "Phase I task queue" "/tmp/collect-evidence-$1.md"
  rg -q "Phase I task queue JSON" "/tmp/collect-evidence-$1.md"
  rg -q "North Star task board" "/tmp/collect-evidence-$1.md"
  rg -q "North Star task board JSON" "/tmp/collect-evidence-$1.md"
  rg -q "North Star execution report" "/tmp/collect-evidence-$1.md"
  rg -q "Phase C/D task board" "/tmp/collect-evidence-$1.md"
  rg -q "Phase C/D execution report" "/tmp/collect-evidence-$1.md"
  rg -q "Memory quality report" "/tmp/collect-evidence-$1.md"
  rg -q "Organization policy report" "/tmp/collect-evidence-$1.md"
  rg -q "Experience draft JSON" "/tmp/collect-evidence-$1.md"
  rg -q "Memory review state JSON" "/tmp/collect-evidence-$1.md"
  rg -q "Phase C/D next execution report" "/tmp/collect-evidence-$1.md"
  rg -q "Phase C/D preflight memory-state task board JSON" "/tmp/collect-evidence-$1.md"
  rg -q "Execution time contract preflight memory-state JSON" "/tmp/collect-evidence-$1.md"
  rg -q "Execution time contract timer guard JSON" "/tmp/collect-evidence-$1.md"
  rg -q "Sinan fitness check JSON" "/tmp/collect-evidence-$1.md"
  rg -q "Intent ambiguity gate JSON" "/tmp/collect-evidence-$1.md"
' _ "$case_id"
run_check "evaluate-state" ./scripts/evaluate-state.sh --issue "$case_id" --run-id "$first_run"
run_check "evaluate-state review contract" bash -c '
  set -euo pipefail
  ./scripts/evaluate-state.sh --issue "$1" --run-id "$2" --output "/tmp/evaluate-state-contract-$1.json" --markdown "/tmp/evaluate-state-contract-$1.md" >/dev/null
  python3 - <<PY "/tmp/evaluate-state-contract-$1.json"
import json
import sys
with open(sys.argv[1], encoding="utf-8") as fh:
    data = json.load(fh)
assert data["contract"] == "review-orchestration.v1"
assert "review_orchestration" in data
PY
' _ "$case_id" "$first_run"
run_check "metadata-draft" ./scripts/metadata-draft.sh --issue "$case_id" --run-id "$first_run"
run_check "refresh-run-evidence --help" ./scripts/refresh-run-evidence.sh --help
run_check "refresh-run-evidence skip policy" ./scripts/refresh-run-evidence.sh --pattern "$pattern" --skip-gate-policy
run_check "share-preflight --help" ./scripts/share-preflight.sh --help
reset_verify_fixture
run_check "share-preflight summary snapshot" bash -c '
  set -euo pipefail
  out_dir="/tmp/verify-share-preflight-$1"
  run_dir="runs/$2"
  restore_dir=$(mktemp -d)
  restore_summary=false
  restore_summary_json=false
  before_hash=""
  if [[ -f "$run_dir/share-preflight-summary.md" ]]; then
    cp "$run_dir/share-preflight-summary.md" "$restore_dir/share-preflight-summary.md"
    restore_summary=true
  fi
  if [[ -f "$run_dir/share-preflight-summary.json" ]]; then
    cp "$run_dir/share-preflight-summary.json" "$restore_dir/share-preflight-summary.json"
    restore_summary_json=true
  fi
  if [[ "$restore_summary" == "true" && "$restore_summary_json" == "true" ]]; then
    before_hash=$(sha256sum "$run_dir/share-preflight-summary.md" "$run_dir/share-preflight-summary.json")
  fi
  cleanup() {
    if [[ "$restore_summary" == "true" ]]; then
      cp "$restore_dir/share-preflight-summary.md" "$run_dir/share-preflight-summary.md"
    else
      rm -f "$run_dir/share-preflight-summary.md"
    fi
    if [[ "$restore_summary_json" == "true" ]]; then
      cp "$restore_dir/share-preflight-summary.json" "$run_dir/share-preflight-summary.json"
    else
      rm -f "$run_dir/share-preflight-summary.json"
    fi
    rm -rf "$restore_dir"
  }
  trap cleanup EXIT
  rm -rf "$out_dir"
  ./scripts/share-preflight.sh --case "$1" --pattern "$3" --golden-run-id "$2" --skip-verify --skip-obsidian --skip-golden-path --persist-to-run --output-dir "$out_dir" >/tmp/share-preflight-summary-snapshot.out
  rg -q "Golden path check: SKIPPED" "$out_dir/share-preflight-summary.md"
  rg -q "Approval Boundary" "$out_dir/share-preflight-summary.md"
  rg -q "Time Contract Gates" "$out_dir/share-preflight-summary.md"
  python3 - <<PY "$out_dir/share-preflight-summary.json"
import json
import sys
with open(sys.argv[1], encoding="utf-8") as fh:
    data = json.load(fh)
assert data["golden_path"]["result"] == "SKIPPED"
assert data["toolchain_verification"]["mode"] == "SKIPPED"
assert isinstance(data["approval_boundary"], list)
PY
  test -s "runs/$2/share-preflight-summary.md"
  test -s "runs/$2/share-preflight-summary.json"
  cleanup
  trap - EXIT
  if [[ -n "$before_hash" ]]; then
    after_hash=$(sha256sum "$run_dir/share-preflight-summary.md" "$run_dir/share-preflight-summary.json")
    [[ "$before_hash" == "$after_hash" ]]
  fi
' _ "$case_id" "$verify_tmp_run" "$verify_tmp_run"
run_check "obsidian-sync operation log guard" bash -c '
  set -euo pipefail
  tmpdir=$(mktemp -d)
  trap "rm -rf \"$tmpdir\"" EXIT
  mkdir -p "$tmpdir/bin" "$tmpdir/vault" "$tmpdir/state"
  cat > "$tmpdir/bin/multica" <<"SH"
#!/usr/bin/env bash
case "$*" in
  "project list --output json") printf "[]\\n" ;;
  "agent list --include-archived --output json") printf "[]\\n" ;;
  "runtime list --output json") printf "[]\\n" ;;
  "autopilot list --output json") printf "{\"autopilots\":[]}\\n" ;;
  issue\ list*) printf "{\"issues\":[]}\\n" ;;
  *) printf "[]\\n" ;;
esac
SH
  chmod +x "$tmpdir/bin/multica"
  PATH="$tmpdir/bin:$PATH" VAULT_PATH="$tmpdir/vault" REPO_ROOT="$PWD" JAVA_ROOT="$tmpdir/java" DRY_RUN=false OPERATION_LOG_DIR="$tmpdir/state/operations" ./scripts/obsidian-sync.sh >/dev/null
  test -s "$tmpdir/state/operations/obsidian-sync.latest.md"
  docs_index="$tmpdir/vault/99-generated/loop/ai-loop-docs-index.md"
  phase_report="$tmpdir/vault/99-generated/loop/docs/reports/2026-06-23-phase-87-share-preflight-snapshot-guard.md"
  time_contract="$tmpdir/vault/99-generated/loop/docs/25-execution-time-contract.md"
  workbench_share="$tmpdir/vault/99-generated/loop/docs/share/sinan-v0.2-workbench-overview.md"
  tiering_share="$tmpdir/vault/99-generated/loop/docs/share/task-tiering-execution-strategy.md"
  showcase_share="$tmpdir/vault/99-generated/loop/docs/share/fuz-554-showcase-case-pack.md"
  continuous_share="$tmpdir/vault/99-generated/loop/docs/share/sinan-continuous-execution-guide.md"
  calibration_share="$tmpdir/vault/99-generated/loop/docs/share/time-estimation-calibration-guide.md"
  capability_config="$tmpdir/vault/99-generated/loop/docs/config/sinan-capabilities.json"
  capability_page="$tmpdir/vault/99-generated/loop/docs/sinan-capabilities.md"
  test -s "$docs_index"
  test -s "$phase_report"
  test -s "$time_contract"
  test -s "$workbench_share"
  test -s "$tiering_share"
  test -s "$showcase_share"
  test -s "$continuous_share"
  test -s "$calibration_share"
  test -s "$capability_config"
  test -s "$capability_page"
  rg -q "2026-06-23-phase-87-share-preflight-snapshot-guard" "$docs_index"
  rg -q "25-execution-time-contract" "$docs_index"
  rg -q "sinan-v0.2-workbench-overview" "$docs_index"
  rg -q "task-tiering-execution-strategy" "$docs_index"
  rg -q "fuz-554-showcase-case-pack" "$docs_index"
  rg -q "sinan-continuous-execution-guide" "$docs_index"
  rg -q "time-estimation-calibration-guide" "$docs_index"
  rg -q "sinan-capabilities" "$docs_index"
  rg -q "Phase 87: Share Preflight Snapshot Guard" "$phase_report"
  rg -q "执行时间契约" "$time_contract"
  rg -q "开工前必须输出" "$time_contract"
  rg -q "收工后必须输出" "$time_contract"
  rg -q "司南 v0.2 工作台总览" "$workbench_share"
  rg -q "任务分级与执行策略" "$tiering_share"
  rg -q "FUZ-554 展示案例包" "$showcase_share"
  rg -q "司南连续执行指南" "$continuous_share"
  rg -q "估时校准指南" "$calibration_share"
  python3 -m json.tool "$capability_config" >/dev/null
  rg -q "司南能力目录" "$capability_page"
  rg -q "trusted_timing_calibration" "$capability_page"
  rg -q "token_output_compression" "$capability_page"
  rg -q "外部工具" "$capability_page"
  rg -q "~/.agents/skills/caveman/SKILL.md" "$capability_page"
	rg -q "npx skills list --global -a codex --json" "$capability_page"
	obsidian_runs="$tmpdir/vault/99-generated/loop/runs-index.md"
	test -s "$obsidian_runs"
	rg -q "within_one_minute" "$obsidian_runs"
	rg -q "Absolute Error" "$obsidian_runs"
	! rg -q "^# Operation Log:|^# Approval Boundary:" "$tmpdir/vault/99-generated"
	' _ "$first_run"
run_check "route-actor" ./scripts/route-actor.sh --next-actor reviewer
run_check "route-actor contract" bash -c '
  set -euo pipefail
  ./scripts/route-actor.sh --next-actor reviewer --output "/tmp/route-actor-contract-$1.json" --markdown "/tmp/route-actor-contract-$1.md" >/dev/null
  python3 - <<PY "/tmp/route-actor-contract-$1.json"
import json
import sys
with open(sys.argv[1], encoding="utf-8") as fh:
    data = json.load(fh)
assert data["contract"] == "route-result.v1"
assert data["result"] == "PASSED"
assert data["lane"] == "review"
PY
' _ "$case_id"
run_check "requirement-gate --help" ./scripts/requirement-gate.sh --help
run_check "clarification-gate --help" ./scripts/clarification-gate.sh --help
run_check "design-gate --help" ./scripts/design-gate.sh --help
run_check "deliverable-gate --help" ./scripts/deliverable-gate.sh --help
run_check "gate-policy-check --help" ./scripts/gate-policy-check.sh --help
run_check "gate-policy contract" bash -c '
  set -euo pipefail
  ./scripts/gate-policy-check.sh --run-id "$2" --issue "$1" --task-type documentation --output "/tmp/gate-policy-contract-$1.md" --json-output "/tmp/gate-policy-contract-$1.json" >/dev/null || true
  python3 - <<PY "/tmp/gate-policy-contract-$1.json"
import json
import sys
with open(sys.argv[1], encoding="utf-8") as fh:
    data = json.load(fh)
assert data["contract"] == "policy-report.v1"
assert data["decision"] in ("allow", "block")
PY
' _ "$verify_tmp_run" "$verify_tmp_run"
run_check "gate-policy-exception --help" ./scripts/gate-policy-exception.sh --help
run_check "metadata-writeback --help" ./scripts/metadata-writeback.sh --help
run_check "approval-boundary --help" ./scripts/approval-boundary.sh --help
run_check "smoke-multica-writeback --help" ./scripts/smoke-multica-writeback.sh --help
run_check "smoke-multica-writeback" ./scripts/smoke-multica-writeback.sh --issue "$case_id" --run-id "${case_id}-smoke-writeback"
run_check "approval-boundary local proceed" ./scripts/approval-boundary.sh --action verify --issue "$case_id" --run-id "$first_run"
run_check "approval-boundary side-effect contract" bash -c '
  set -euo pipefail
  ./scripts/approval-boundary.sh --action feishu-write --issue "$1" --run-id "$2" --output "/tmp/approval-boundary-contract-$1.md" --json-output "/tmp/approval-boundary-contract-$1.json" >/dev/null || true
  python3 - <<PY "/tmp/approval-boundary-contract-$1.json"
import json
import sys
with open(sys.argv[1], encoding="utf-8") as fh:
    data = json.load(fh)
assert data["contract"] == "side-effect-manifest.v1"
assert data["side_effect_manifest"]["requires_approval"] is True
assert data["decision"] == "stop_for_approval"
PY
' _ "$case_id" "$first_run"
run_check "approval-boundary batch approval window" bash -c '
  set -euo pipefail
  window="/tmp/approval-window-$1.json"
  cat > "$window" <<JSON
{"schema_version":1,"approved_by":"batch-user","expires_at":"2099-01-01T00:00:00Z","actions":["feishu-write","multica-comment"],"side_effects":["feishu_document_or_base_write","multica_comment_write"],"issues":["$1"],"run_ids":["$2"]}
JSON
  ./scripts/approval-boundary.sh --action feishu-write --issue "$1" --run-id "$2" --approval-window "$window" --json-output "/tmp/approval-boundary-window-$1.json" >/tmp/approval-boundary-window-$1.md
  python3 - <<PY "/tmp/approval-boundary-window-$1.json"
import json
import sys
with open(sys.argv[1], encoding="utf-8") as fh:
    data = json.load(fh)
assert data["result"] == "PASSED"
assert data["approval_window"]["matched"] is True
assert data["approved_by"] == "batch-user"
assert data["side_effect_manifest"]["approval_window_matched"] is True
PY
' _ "$case_id" "$first_run"
run_check "approval-boundary batch approval expired" bash -c '
  set -euo pipefail
  window="/tmp/approval-window-expired-$1.json"
  cat > "$window" <<JSON
{"schema_version":1,"approved_by":"batch-user","expires_at":"2000-01-01T00:00:00Z","actions":["feishu-write"],"side_effects":["feishu_document_or_base_write"],"issues":["$1"],"run_ids":["$2"]}
JSON
  if ./scripts/approval-boundary.sh --action feishu-write --issue "$1" --run-id "$2" --approval-window "$window" --json-output "/tmp/approval-boundary-window-expired-$1.json" >/tmp/approval-boundary-window-expired-$1.md; then
    exit 1
  fi
  python3 - <<PY "/tmp/approval-boundary-window-expired-$1.json"
import json
import sys
with open(sys.argv[1], encoding="utf-8") as fh:
    data = json.load(fh)
assert data["result"] == "APPROVAL_REQUIRED"
assert data["approval_window"]["matched"] is False
checks = {item["name"]: item["status"] for item in data["approval_window"]["checks"]}
assert checks["expires_at"] == "FAILED"
PY
' _ "$case_id" "$first_run"
run_check "approval-boundary obsidian standing proceed" bash -c './scripts/approval-boundary.sh --action obsidian-sync --issue "$1" --run-id "$2" >/tmp/approval-boundary-obsidian.out 2>/tmp/approval-boundary-obsidian.err; rg -q "Decision: proceed" /tmp/approval-boundary-obsidian.out; rg -q "Obsidian generated sync has standing approval" /tmp/approval-boundary-obsidian.out; ! rg -q "Obsidian, Multica" /tmp/approval-boundary-obsidian.out' _ "$case_id" "$first_run"
run_check "approval-boundary tool install stop" bash -c './scripts/approval-boundary.sh --action tool-install >/tmp/approval-boundary-tool-install.out 2>/tmp/approval-boundary-tool-install.err; test "$?" -eq 1'
run_check "approval-boundary codex config stop" bash -c './scripts/approval-boundary.sh --action codex-config >/tmp/approval-boundary-codex-config.out 2>/tmp/approval-boundary-codex-config.err; test "$?" -eq 1'
run_check "writeback-summary-json --help" ./scripts/writeback-summary-json.sh --help
run_check "golden-path-check --help" ./scripts/golden-path-check.sh --help
run_check "metadata-writeback dry-run" ./scripts/metadata-writeback.sh --issue "$case_id" --run-id "$first_run"
run_check "writeback-summary-json" ./scripts/writeback-summary-json.sh --issue "$case_id" --run-id "$first_run"
run_check "writeback-gate unified approval" bash -c '
  set -euo pipefail
  if ./scripts/writeback-gate.sh --issue "$1" --run-id "$2" --type comment --output "/tmp/writeback-gate-comment-no-$1.json" >/tmp/writeback-gate-comment-no-$1.out; then
    exit 1
  fi
  ./scripts/writeback-gate.sh --issue "$1" --run-id "$2" --type comment --approved-by reviewer --output "/tmp/writeback-gate-comment-yes-$1.json" >/tmp/writeback-gate-comment-yes-$1.out
  python3 - <<PY "/tmp/writeback-gate-comment-no-$1.json" "/tmp/writeback-gate-comment-yes-$1.json"
import json
import sys
no = json.load(open(sys.argv[1], encoding="utf-8"))
yes = json.load(open(sys.argv[2], encoding="utf-8"))
assert no["allowed"] is False
assert no["checks"]["human_approval"] == "FAILED"
assert yes["allowed"] is True
assert yes["checks"]["human_approval"] == "PASSED"
assert yes["approval_boundary"]["decision"] == "approved_to_proceed"
assert yes["readback"]["required_after_write"] is True
PY
' _ "$case_id" "$first_run"
run_check "writeback-summary-json readback artifacts" bash -c '
  set -euo pipefail
  fixture="/tmp/writeback-summary-readback-$1.md"
  cat > "$fixture" <<MD
# Writeback Summary

- Issue: $1
- Write comment requested: true
- Write status requested: true
- Write metadata requested: true
- Comment written: true
- Status written: true
- Status write value: done
- Metadata written: true
- Metadata write value: foo=bar
- Comment readback: runs/$2/multica-comment-readback.json
- Status readback: runs/$2/multica-status-readback.json
- Metadata readback: runs/$2/multica-metadata-get-foo.json
- Feishu readback: runs/$2/feishu-readback.json
- Approval boundary comment: runs/$2/approval-boundary-comment.md
- Approval boundary status: runs/$2/approval-boundary-status.md
- Approval boundary metadata: runs/$2/approval-boundary-metadata.md
- Writeback gate: runs/$2/writeback-gate-comment.json
- Status writeback gate: runs/$2/writeback-gate-status.json
- Metadata writeback gate: runs/$2/writeback-gate-metadata.json
- Write error log:
MD
  ./scripts/writeback-summary-json.sh --issue "$1" --run-id "$2" --input "$fixture" --output "/tmp/writeback-summary-readback-$1.json" >/tmp/writeback-summary-readback-$1.out
  python3 - <<PY "/tmp/writeback-summary-readback-$1.json"
import json
import sys
with open(sys.argv[1], encoding="utf-8") as fh:
    data = json.load(fh)
assert data["readback_artifacts"]["comment"].endswith("multica-comment-readback.json")
assert data["readback_artifacts"]["status"].endswith("multica-status-readback.json")
assert data["readback_artifacts"]["metadata"].endswith("multica-metadata-get-foo.json")
assert data["status"]["approval_boundary"].endswith("approval-boundary-status.md")
PY
' _ "$case_id" "$first_run"
run_check "writeback-summary-json empty fields" python3 - <<'PY' "runs/$first_run/writeback-summary.json"
import json
import sys
with open(sys.argv[1], encoding="utf-8") as fh:
    data = json.load(fh)
assert data.get("status", {}).get("value") in ("", None)
assert data.get("error_log") in ("", None)
PY
reset_verify_fixture
run_check "golden-path-check skip obsidian" ./scripts/golden-path-check.sh --issue "$case_id" --run-id "$verify_tmp_run" --skip-obsidian --output "/tmp/golden-path-check-${case_id}.md" --json-output "/tmp/golden-path-check-${case_id}.json"
run_check "golden-path-check time contract" python3 - <<'PY' "/tmp/golden-path-check-${case_id}.json"
import json
import sys
with open(sys.argv[1], encoding="utf-8") as fh:
    data = json.load(fh)
checks = {check["name"]: check for check in data["checks"]}
for name in [
    "execution_time_contract",
    "execution_time_contract_json",
    "execution_time_contract_fields",
    "execution_time_contract_elapsed",
    "execution_time_contract_closeout",
    "time_estimation_calibration",
    "time_estimation_calibration_json",
    "time_calibration_summary",
    "evidence_summary_time_artifacts",
]:
    assert name in checks
    assert checks[name]["status"] == "PASSED"
PY
run_check "golden-path-check obsidian time contract" bash -c '
  set -euo pipefail
  ./scripts/golden-path-check.sh --issue "$1" --run-id "$2" --skip-obsidian --output "/tmp/golden-path-check-$1-obsidian.md" --json-output "/tmp/golden-path-check-$1-obsidian.json" >/dev/null
  python3 - <<PY "/tmp/golden-path-check-$1-obsidian.json"
import json
import sys
with open(sys.argv[1], encoding="utf-8") as fh:
    data = json.load(fh)
checks = {check["name"]: check for check in data["checks"]}
assert checks["obsidian"]["status"] == "SKIPPED"
assert data["result"] == "PASSED"
PY
' _ "$case_id" "$verify_tmp_run"
run_check "patch-summary --help" ./scripts/patch-summary.sh --help
run_check "evidence-checklist" ./scripts/evidence-checklist.sh --run-id "$first_run"
run_check "evidence-index" ./scripts/evidence-index.sh --pattern "$pattern"
run_check "evidence registry checklist/index" bash -c '
  set -euo pipefail
  ./scripts/evidence-checklist.sh --run-id "$2" --task-type local_script_patch --output "/tmp/evidence-checklist-registry-$1.md" >/dev/null
  ./scripts/evidence-index.sh --pattern "$2" --output "/tmp/evidence-index-registry-$1.md" >/dev/null
  rg -q "## Required Evidence By Task Type" "/tmp/evidence-checklist-registry-$1.md"
  rg -q "execution_preflight_json" "/tmp/evidence-checklist-registry-$1.md"
  rg -q "Registry Groups" "/tmp/evidence-index-registry-$1.md"
' _ "$case_id" "$first_run"
run_check "sinan share docs" bash -c '
  set -euo pipefail
  test -s docs/ai-work-orchestration/share/fuz-554-showcase-case-pack.md
  test -s docs/ai-work-orchestration/share/sinan-demo-script.md
  test -s docs/ai-work-orchestration/share/sinan-best-practices-templates.md
  test -s memory/templates/sinan-task-execution-template.md
  rg -q "北极星" docs/ai-work-orchestration/share/fuz-554-showcase-case-pack.md
  rg -q "证据链" docs/ai-work-orchestration/share/fuz-554-showcase-case-pack.md
  rg -q "计时" docs/ai-work-orchestration/share/fuz-554-showcase-case-pack.md
  rg -q "受控回写" docs/ai-work-orchestration/share/fuz-554-showcase-case-pack.md
  rg -q "预期输出" docs/ai-work-orchestration/share/sinan-demo-script.md
  rg -q "失败回滚" docs/ai-work-orchestration/share/sinan-demo-script.md
  rg -q "writeback-gate" docs/ai-work-orchestration/share/sinan-demo-script.md
  rg -q "任务拆分" docs/ai-work-orchestration/share/sinan-best-practices-templates.md
  rg -q "readback artifact" docs/ai-work-orchestration/share/sinan-best-practices-templates.md
  rg -q "司南任务执行模板" memory/templates/sinan-task-execution-template.md
  rg -q "sinan-demo-script" docs/ai-work-orchestration/share/README.md
  rg -q "sinan-best-practices-templates" docs/ai-work-orchestration/share/README.md
' _ "$case_id" "$first_run"
run_check "automation classify golden tests" bash -c '
  set -euo pipefail
  cat > /tmp/classify-writeback-$1.json <<JSON
{"title":"飞书多维表格写回确认数量","description":"需要写 Feishu base 和 Multica metadata","labels":["需求"]}
JSON
  cat > /tmp/classify-doc-$1.json <<JSON
{"title":"司南演示脚本和最佳实践模板","description":"补充分享文档、demo、模板","labels":["documentation"]}
JSON
  ./scripts/classify-task.sh --issue "$1-W" --input /tmp/classify-writeback-$1.json --output /tmp/classify-writeback-$1-out.json >/tmp/classify-writeback-$1.out
  ./scripts/classify-task.sh --issue "$1-D" --input /tmp/classify-doc-$1.json --output /tmp/classify-doc-$1-out.json >/tmp/classify-doc-$1.out
  python3 - <<PY /tmp/classify-writeback-$1-out.json /tmp/classify-doc-$1-out.json
import json
import sys
w = json.load(open(sys.argv[1], encoding="utf-8"))
d = json.load(open(sys.argv[2], encoding="utf-8"))
assert w["task_type"] == "writeback"
assert w["risk"] == "high"
assert w["tier"] == "L3"
assert w["needs_clarification"] is False
assert d["task_type"] == "documentation"
assert d["tier"] == "L1"
assert d["automation_boundary"]["auto_execute"] is False
PY
' _ "$case_id" "$first_run"
run_check "generate-plan structured" bash -c '
  set -euo pipefail
  cat > /tmp/generate-plan-input-$1.json <<JSON
{"title":"自动生成执行计划 generate-plan","description":"根据任务描述生成步骤、验收、验证命令、副作用草案","labels":["automation"]}
JSON
  ./scripts/generate-plan.sh --issue "$1-GEN" --input /tmp/generate-plan-input-$1.json --output /tmp/generate-plan-$1.md --json-output /tmp/generate-plan-$1.json >/tmp/generate-plan-$1.out
  python3 - <<PY /tmp/generate-plan-$1.json
import json
import sys
data = json.load(open(sys.argv[1], encoding="utf-8"))
assert data["schema_version"] == 1
assert data["steps"]
assert data["acceptance"]
assert data["verification_commands"]
assert data["side_effects_draft"]
assert data["gate_plan"]["required_gates"]
assert "requirement" in data["gate_plan"]["required_gates"]
assert data["gate_plan"]["commands"]
assert data["automation_boundary"]["auto_execute"] is False
assert data["automation_boundary"]["auto_writeback_decision"] is False
PY
  rg -q "不自动执行计划" /tmp/generate-plan-$1.md
  rg -q "## Gate Plan" /tmp/generate-plan-$1.md
  rg -q "Required gates" /tmp/generate-plan-$1.md
' _ "$case_id" "$first_run"
run_check "automation boundary docs and preflight" bash -c '
  set -euo pipefail
  rg -q "不做自动 reviewer" docs/ai-work-orchestration/20-automation-enhancement.md
  rg -q "不做自动回写决策" docs/ai-work-orchestration/20-automation-enhancement.md
  rg -q "不做自动远端副作用" docs/ai-work-orchestration/20-automation-enhancement.md
  task_file="/tmp/automation-boundary-preflight-task-$1.md"
  cat > "$task_file" <<MD
# 自动化边界验证

Issue: $1

## 目标

- 验证 preflight 展示 automation boundary。

## 验收

- JSON 包含 automation_boundary。
- Markdown 包含 Automation Boundary。

## 安全边界

- 只做本地验证。
- 不做远端写回。
MD
  ./scripts/loop-execution-preflight.sh --issue "$1" --task "$task_file" --repo . --run-id "$2" --no-phase-report --no-operation-log --task-tier L2 --output "/tmp/automation-boundary-preflight-$1.md" --json-output "/tmp/automation-boundary-preflight-$1.json" >/dev/null
  python3 - <<PY "/tmp/automation-boundary-preflight-$1.json"
import json
import sys
with open(sys.argv[1], encoding="utf-8") as fh:
    data = json.load(fh)
boundary = data["automation_boundary"]
assert boundary["auto_execute"] is False
assert boundary["auto_reviewer"] is False
assert boundary["auto_writeback_decision"] is False
assert boundary["auto_remote_side_effect"] is False
PY
  rg -q "Automation Boundary|自动化边界" "/tmp/automation-boundary-preflight-$1.md"
' _ "$case_id" "$first_run"
run_check "review-packet" ./scripts/review-packet.sh --case "$case_id" --pattern "$pattern" --output "/tmp/review-packet-${case_id}.md"
run_check "review-packet time contract" bash -c '
  set -euo pipefail
  rg -q "Time Contract" "/tmp/review-packet-$1.md"
  rg -q "within_one_minute" "/tmp/review-packet-$1.md"
  rg -q "absolute error" "/tmp/review-packet-$1.md" || rg -q "error=" "/tmp/review-packet-$1.md"
' _ "$case_id"
run_check "loop-execution-preflight" ./scripts/loop-execution-preflight.sh --issue "$case_id" --task "tasks/${case_id}.md" --repo . --run-id "$first_run" --allow-feishu-write --allow-multica-write --no-phase-report --no-operation-log --task-tier L2 --output "/tmp/loop-execution-preflight-${case_id}.md" --json-output "/tmp/loop-execution-preflight-${case_id}.json"
run_check "loop-execution-preflight recommendations" python3 - <<'PY' "/tmp/loop-execution-preflight-${case_id}.json"
import json
import sys
with open(sys.argv[1], encoding="utf-8") as fh:
    data = json.load(fh)
assert data["phase_report"]["policy"] == "no"
assert data["intent_ambiguity"]["result"] == "PASSED"
assert data["organization_contract"]["routing"] == "route-result.v1"
assert data["organization_contract"]["policy"] == "policy-report.v1"
assert data["organization_contract"]["side_effect"] == "side-effect-manifest.v1"
assert data["organization_contract"]["review"] == "review-orchestration.v1"
assert data["operation_log"]["policy"] == "no"
assert data["timebox"]["tier"] == "L2"
assert data["timebox"]["policy_estimated_minutes"] == 90
assert data["timebox"]["calibration"]["source"] in {"time-estimation-calibration", "policy_default"}
if data["timebox"]["calibration"]["source"] == "time-estimation-calibration":
    assert data["timebox"]["calibration"]["bucket_used"] == "local_script_patch"
    assert data["timebox"]["estimated_minutes"] == data["timebox"]["calibration"]["recommended_next_estimate_minutes"]
    assert data["timebox"]["calibration"]["execution_time_contract_runs"] >= 1
else:
    assert data["timebox"]["estimated_minutes"] == data["timebox"]["policy_estimated_minutes"]
assert data["timebox"]["anti_idle_floor_minutes"] == 30
assert "do not stop on small milestones" in data["timebox"]["stop_rule"]
assert data["writeback_recommendation"]["multica_write"] == "allowed"
assert data["writeback_recommendation"]["done_candidate_after_closeout"] is True
PY
run_check "loop-execution-preflight local script bucket" bash -c '
  set -euo pipefail
  task_file="/tmp/local-script-patch-task-$1.md"
  cat > "$task_file" <<TASK
# Local Script Patch Smoke

Issue: $1

## 目标

优化本地 script / evidence / calibration / preflight 行为。

## 验收

- 更新脚本逻辑
- 运行本地 verify-toolchain
- 刷新 evidence 和 Obsidian generated

## 安全边界

- 不写 Feishu
- 不写 Multica
- 不做 git remote
TASK
  ./scripts/loop-execution-preflight.sh --issue "$1" --task "$task_file" --repo . --run-id "$2" --no-phase-report --no-operation-log --task-tier L2 --output "/tmp/local-script-patch-preflight-$1.md" --json-output "/tmp/local-script-patch-preflight-$1.json" >/dev/null
  python3 - <<PY "/tmp/local-script-patch-preflight-$1.json"
import json
import sys
with open(sys.argv[1], encoding="utf-8") as fh:
    data = json.load(fh)
assert data["result"] == "PASSED"
assert data["intake"]["result"] == "PASSED"
assert data["timebox"]["calibration"]["task_type"] == "local_script_patch"
assert data["timebox"]["calibration"]["source"] in {"time-estimation-calibration", "policy_default"}
if data["timebox"]["calibration"]["source"] == "time-estimation-calibration":
    assert data["timebox"]["calibration"]["bucket_used"] == "local_script_patch"
    assert data["timebox"]["estimated_minutes"] == data["timebox"]["calibration"]["recommended_next_estimate_minutes"]
    assert data["timebox"]["calibration"]["trusted_measured_runs"] >= 1
else:
    assert data["timebox"]["estimated_minutes"] == data["timebox"]["policy_estimated_minutes"]
assert data["timebox"]["policy_estimated_minutes"] >= data["timebox"]["estimated_minutes"]
PY
' _ "$case_id" "$first_run"
run_check "loop-execution-preflight ambiguity gate" bash -c '
  set -euo pipefail
  task_file="/tmp/ambiguous-preflight-task-$1.md"
  cat > "$task_file" <<TASK
# Ambiguous Preflight Smoke

Issue: $1

## 目标

继续推进司南健身。

## 验收

- preflight 阻断并要求澄清

## 安全边界

- local files only
TASK
  if ./scripts/loop-execution-preflight.sh --issue "$1" --task "$task_file" --repo . --run-id "$2" --no-phase-report --no-operation-log --task-tier L2 --output "/tmp/ambiguous-preflight-$1.md" --json-output "/tmp/ambiguous-preflight-$1.json" >/dev/null; then
    exit 1
  fi
  python3 - <<PY "/tmp/ambiguous-preflight-$1.json"
import json
import sys
with open(sys.argv[1], encoding="utf-8") as fh:
    data = json.load(fh)
assert data["result"] == "FAILED"
assert data["intent_ambiguity"]["result"] == "BLOCKED"
PY
  rg -q "Intent ambiguity gate: BLOCKED" "/tmp/ambiguous-preflight-$1.md"
' _ "$case_id" "$first_run"
run_check "loop-execution-preflight task type override" bash -c '
  set -euo pipefail
  task_file="/tmp/documentation-task-$1.md"
  cat > "$task_file" <<TASK
# Documentation Preflight Smoke

Issue: $1

## 目标

更新 README 和 north-star 文档，同时可能提到 script / evidence。

## 验收

- 文档入口更新
- 本地 verify-toolchain 通过

## 安全边界

- 不写 Feishu
- 不写 Multica
- 不做 git remote
TASK
  ./scripts/loop-execution-preflight.sh --issue "$1" --task "$task_file" --repo . --run-id "$2" --task-type documentation --no-phase-report --no-operation-log --task-tier L2 --output "/tmp/documentation-preflight-$1.md" --json-output "/tmp/documentation-preflight-$1.json" >/dev/null
  python3 - <<PY "/tmp/documentation-preflight-$1.json"
import json
import sys
with open(sys.argv[1], encoding="utf-8") as fh:
    data = json.load(fh)
assert data["result"] == "PASSED"
assert data["timebox"]["calibration"]["task_type"] == "documentation"
if data["timebox"]["calibration"]["source"] == "time-estimation-calibration":
    assert data["timebox"]["calibration"]["bucket_used"] in ("documentation", "all_trusted_samples")
PY
' _ "$case_id" "$first_run"
run_check "loop-execution-preflight bucket quality" python3 - <<'PY' "/tmp/documentation-preflight-${case_id}.json"
import json
import sys
with open(sys.argv[1], encoding="utf-8") as fh:
    data = json.load(fh)
calibration = data["timebox"]["calibration"]
assert "one_minute_hit_rate" in calibration
assert "one_minute_hit_runs" in calibration
assert "one_minute_miss_runs" in calibration
assert "sample_quality" in calibration
assert isinstance(calibration["one_minute_hit_runs"], int)
assert isinstance(calibration["one_minute_miss_runs"], int)
PY
run_check "loop-closeout --help" ./scripts/loop-closeout.sh --help
run_check "loop-closeout calibration help" bash -c './scripts/loop-closeout.sh --help >/tmp/loop-closeout-help.out; rg -q "time-estimation-calibration" /tmp/loop-closeout-help.out'
run_check "loop-closeout time contract help" bash -c './scripts/loop-closeout.sh --help >/tmp/loop-closeout-help.out; rg -q "execution-time-contract" /tmp/loop-closeout-help.out'
run_check "execution-time-contract --help" ./scripts/execution-time-contract.sh --help
run_check "execution-time-contract smoke" ./scripts/execution-time-contract.sh --estimate-minutes 10-15 --basis "verify smoke" --started-at 2026-06-23T03:00:00Z --completed-at 2026-06-23T03:12:00Z --output "/tmp/execution-time-contract-${case_id}.md" --json-output "/tmp/execution-time-contract-${case_id}.json"
run_check "execution-time-contract fast smoke" ./scripts/execution-time-contract.sh --estimate-minutes 20-30 --basis "verify fast smoke" --started-at 2026-06-23T04:00:00Z --completed-at 2026-06-23T04:07:00Z --output "/tmp/execution-time-contract-${case_id}-fast.md" --json-output "/tmp/execution-time-contract-${case_id}-fast.json"
run_check "execution-time-contract assertions" python3 - <<'PY' "/tmp/execution-time-contract-${case_id}.json"
import json
import sys
with open(sys.argv[1], encoding="utf-8") as fh:
    data = json.load(fh)
assert data["estimate_minutes"] == "10-15"
assert data["elapsed_seconds"] == 720
assert data["elapsed_minutes"] == 12.0
assert data["within_estimate"] is True
assert data["absolute_error_minutes"] == 0.0
assert data["within_one_minute"] is True
assert data["variance_note"] == "within_estimate"
PY
run_check "execution-time-contract one minute miss" ./scripts/execution-time-contract.sh --estimate-minutes 10 --basis "verify miss" --started-at 2026-06-23T03:00:00Z --completed-at 2026-06-23T03:12:30Z --output "/tmp/execution-time-contract-${case_id}-miss.md" --json-output "/tmp/execution-time-contract-${case_id}-miss.json"
run_check "execution-time-contract one minute assertions" python3 - <<'PY' "/tmp/execution-time-contract-${case_id}-miss.json"
import json
import sys
with open(sys.argv[1], encoding="utf-8") as fh:
    data = json.load(fh)
assert data["elapsed_minutes"] == 12.5
assert data["absolute_error_minutes"] == 2.5
assert data["within_one_minute"] is False
PY
run_check "execution-time-contract timestamp guard" bash -c './scripts/execution-time-contract.sh --estimate-minutes 10-15 --started-at 2026-06-23T03:12:00Z --completed-at 2026-06-23T03:00:00Z >/tmp/execution-time-contract-negative.out 2>/tmp/execution-time-contract-negative.err; test "$?" -eq 1; rg -q -- "--completed-at must be greater than or equal to --started-at" /tmp/execution-time-contract-negative.err'
reset_verify_fixture
run_check "loop-continuation-gate --help" ./scripts/loop-continuation-gate.sh --help
run_check "loop-continuation-gate manual timing" ./scripts/loop-continuation-gate.sh --issue "$case_id" --run-id "$verify_tmp_run" --task-tier L2 --elapsed-minutes 30 --stage verify --json-output "/tmp/loop-continuation-gate-${case_id}-manual.json" --output "/tmp/loop-continuation-gate-${case_id}-manual.md"
run_check "loop-continuation-gate manual timing decision" python3 - <<'PY' "/tmp/loop-continuation-gate-${case_id}-manual.json"
import json
import sys
with open(sys.argv[1], encoding="utf-8") as fh:
    data = json.load(fh)
assert data["decision"] == "ALLOW_STOP"
assert data["tier"] == "L2"
assert data["timing_source"] == "manual"
assert data["started_at"] is None
assert data["completed_at"] is None
assert data["estimated_minutes"] == 90
assert data["anti_idle_floor_minutes"] == 30
assert data["elapsed_seconds"] == 1800
assert data["elapsed_minutes"] == 30
assert data["estimate_accuracy"] == "untrusted_timing"
assert data["variance_ratio"] is None
assert "acceptance met" in " ".join(data["allow_stop_reasons"])
PY
run_check "loop-continuation-gate timestamp timing" ./scripts/loop-continuation-gate.sh --issue "$case_id" --run-id "$verify_tmp_run" --task-tier L2 --started-at 2026-06-23T01:00:00Z --completed-at 2026-06-23T01:12:00Z --stage verify --json-output "/tmp/loop-continuation-gate-${case_id}-timestamp.json" --output "/tmp/loop-continuation-gate-${case_id}-timestamp.md"
run_check "loop-continuation-gate timestamp timing decision" python3 - <<'PY' "/tmp/loop-continuation-gate-${case_id}-timestamp.json"
import json
import sys
with open(sys.argv[1], encoding="utf-8") as fh:
    data = json.load(fh)
assert data["decision"] == "ALLOW_STOP"
assert data["tier"] == "L2"
assert data["timing_source"] == "timestamp"
assert data["started_at"] == "2026-06-23T01:00:00Z"
assert data["completed_at"] == "2026-06-23T01:12:00Z"
assert data["elapsed_seconds"] == 720
assert data["elapsed_minutes"] == 12
assert data["estimated_minutes"] == 90
assert data["estimate_accuracy"] == "outside_tolerance"
PY
run_check "loop-continuation-gate timestamp order guard" bash -c './scripts/loop-continuation-gate.sh --issue "$1" --run-id "$2" --task-tier L2 --started-at 2026-06-23T01:12:00Z --completed-at 2026-06-23T01:00:00Z --json-output /tmp/loop-continuation-gate-$1-negative.json >/tmp/loop-continuation-gate-$1-negative.out 2>/tmp/loop-continuation-gate-$1-negative.err; test "$?" -eq 1; rg -q -- "--completed-at must be greater than or equal to --started-at" /tmp/loop-continuation-gate-$1-negative.err' _ "$case_id" "$verify_tmp_run"
run_check "loop-continuation-gate allow stop" ./scripts/loop-continuation-gate.sh --issue "$case_id" --run-id "$verify_tmp_run" --task-tier L2 --elapsed-minutes 90 --stage closeout --json-output "/tmp/loop-continuation-gate-${case_id}-allow.json" --output "/tmp/loop-continuation-gate-${case_id}-allow.md"
run_check "loop-continuation-gate allow decision" python3 - <<'PY' "/tmp/loop-continuation-gate-${case_id}-allow.json"
import json
import sys
with open(sys.argv[1], encoding="utf-8") as fh:
    data = json.load(fh)
assert data["decision"] == "ALLOW_STOP"
assert data["closeout"]["complete"] is True
assert data["writeback"]["complete"] is True
PY
run_check "time-estimation-calibration --help" ./scripts/time-estimation-calibration.sh --help
run_check "time-estimation-calibration smoke" bash -c '
  set -euo pipefail
  smoke_root="runs/$1-verify-calibration-smoke"
  rm -rf "$smoke_root-manual" "$smoke_root-timestamp" "$smoke_root-contract"
  cleanup() { rm -rf "$smoke_root-manual" "$smoke_root-timestamp" "$smoke_root-contract"; }
  trap cleanup EXIT
  mkdir -p "$smoke_root-manual" "$smoke_root-timestamp" "$smoke_root-contract"
  cp /tmp/loop-continuation-gate-$1-manual.json "$smoke_root-manual/continuation-gate.json"
  cp /tmp/loop-continuation-gate-$1-timestamp.json "$smoke_root-timestamp/continuation-gate.json"
  cp /tmp/execution-time-contract-$1.json "$smoke_root-contract/execution-time-contract.json"
  cp /tmp/execution-time-contract-$1-fast.json "$smoke_root-contract/execution-time-contract-fast.json"
  ./scripts/time-estimation-calibration.sh --pattern "$1-verify-calibration-smoke*" --output "/tmp/time-estimation-calibration-$1.md" --json-output "/tmp/time-estimation-calibration-$1.json" >/dev/null
' _ "$case_id"
run_check "time-estimation-calibration assertions" python3 - <<'PY' "/tmp/time-estimation-calibration-${case_id}.json"
import json
import sys
with open(sys.argv[1], encoding="utf-8") as fh:
    data = json.load(fh)
assert data["summary"]["trusted_measured_runs"] == 3
assert data["summary"]["measured_runs"] == 3
assert data["summary"]["manual_timing_runs"] == 1
assert data["summary"]["execution_time_contract_runs"] == 2
assert data["summary"]["recommended_next_estimate_minutes"] == 25
assert data["summary"]["one_minute_hit_runs"] == 1
assert data["summary"]["one_minute_miss_runs"] == 2
assert data["summary"]["one_minute_hit_rate"] == 0.3333
rows = {row["source_artifact"]: row for row in data["runs"]}
unknown_bucket = data["summary"]["task_type_buckets"]["unknown"]
assert unknown_bucket["one_minute_hit_runs"] == 1
assert unknown_bucket["one_minute_miss_runs"] == 1
assert unknown_bucket["one_minute_hit_rate"] == 0.5
manual = [row for row in data["runs"] if row["timing_source"] == "manual"][0]
assert manual["trusted_timing"] is False
assert manual["direction"] == "unknown"
assert manual["recommended_next_estimate_minutes"] is None
assert rows["continuation-gate.json"]["trusted_timing"] is True
assert rows["continuation-gate.json"]["estimated_minutes"] == 90
assert rows["continuation-gate.json"]["elapsed_seconds"] == 720
assert rows["continuation-gate.json"]["elapsed_minutes"] == 12
assert rows["continuation-gate.json"]["direction"] == "overestimated"
assert rows["execution-time-contract.json"]["trusted_timing"] is True
assert rows["execution-time-contract.json"]["estimated_minutes"] == 15
assert rows["execution-time-contract.json"]["elapsed_seconds"] == 720
assert rows["execution-time-contract.json"]["elapsed_minutes"] == 12.0
assert rows["execution-time-contract.json"]["direction"] == "overestimated"
assert rows["execution-time-contract.json"]["absolute_error_minutes"] == 0.0
assert rows["execution-time-contract.json"]["within_one_minute"] is True
assert rows["execution-time-contract.json"]["recommended_next_estimate_minutes"] == 14
assert rows["execution-time-contract-fast.json"]["trusted_timing"] is True
assert rows["execution-time-contract-fast.json"]["estimated_minutes"] == 30
assert rows["execution-time-contract-fast.json"]["elapsed_seconds"] == 420
assert rows["execution-time-contract-fast.json"]["elapsed_minutes"] == 7.0
assert rows["execution-time-contract-fast.json"]["direction"] == "overestimated"
assert rows["execution-time-contract-fast.json"]["absolute_error_minutes"] == 13.0
assert rows["execution-time-contract-fast.json"]["within_one_minute"] is False
assert rows["execution-time-contract-fast.json"]["recommended_next_estimate_minutes"] == 10
assert data["summary"]["per_slice_recommendations"]
slice_names = {item["slice"] for item in data["summary"]["per_slice_recommendations"]}
assert "fast" in slice_names
PY
run_check "archive-run-artifacts dry-run" bash -c '
  set -euo pipefail
  ./scripts/archive-run-artifacts.sh --run-id "$2" --dry-run --output "/tmp/archive-run-artifacts-$1.md" --json-output "/tmp/archive-run-artifacts-$1.json" >/tmp/archive-run-artifacts-$1.out
  python3 - <<PY "/tmp/archive-run-artifacts-$1.json"
import json
import sys
with open(sys.argv[1], encoding="utf-8") as fh:
    data = json.load(fh)
assert data["result"] == "PASSED"
assert data["dry_run"] is True
assert "candidates" in data
PY
' _ "$case_id" "$first_run"

strict_rows=""
strict_fail_count=0
if [[ "$strict" == "true" ]]; then
  for run_dir in "${run_dirs[@]}"; do
    if [[ ! -d "$run_dir" ]]; then
      continue
    fi
    run_id="$(basename "$run_dir")"
    missing=()
    for required_file in summary.md stage-report.md multica-comment.md; do
      if [[ ! -s "$run_dir/$required_file" ]]; then
        missing+=("$required_file")
      fi
    done
    registry_missing="$(python3 - <<'PY' "$run_dir" local_script_patch
import json
import sys
from pathlib import Path
run_dir = Path(sys.argv[1])
task_type = sys.argv[2]
registry_path = Path("config/evidence-artifacts.json")
if not registry_path.is_file():
    print("config/evidence-artifacts.json")
    raise SystemExit
registry = json.loads(registry_path.read_text(encoding="utf-8"))
missing = []
for item in registry.get("artifacts") or []:
    required_for = item.get("required_for") or []
    if "all" not in required_for and task_type not in required_for:
        continue
    path = run_dir / item.get("path", "")
    if not path.is_file() or path.stat().st_size == 0:
        missing.append(item.get("key") or item.get("path"))
print(",".join(missing))
PY
)"
    if [[ -n "$registry_missing" ]]; then
      missing+=("registry:${registry_missing}")
    fi
    if [[ -s "$run_dir/execution-time-contract.md" && ! -s "$run_dir/execution-time-contract.json" ]]; then
      missing+=("execution-time-contract.json")
    elif [[ -s "$run_dir/execution-time-contract.json" && ! -s "$run_dir/execution-time-contract.md" ]]; then
      missing+=("execution-time-contract.md")
    fi
    if [[ -s "$run_dir/execution-time-contract.json" ]]; then
      time_contract_valid="$(python3 - <<'PY' "$run_dir/execution-time-contract.json"
import json
import sys
try:
    with open(sys.argv[1], encoding="utf-8") as fh:
        data = json.load(fh)
except Exception:
    print("false")
    raise SystemExit
required = ["estimate_minutes", "basis", "started_at", "completed_at", "elapsed_seconds", "elapsed_minutes", "variance_note", "next_estimate_minutes"]
print("true" if all(key in data and data[key] not in (None, "") for key in required) else "false")
PY
)"
      if [[ "$time_contract_valid" != "true" ]]; then
        missing+=("execution-time-contract.fields")
      fi
    fi
    if [[ ${#missing[@]} -eq 0 ]]; then
      strict_rows+="| ${run_id} | PASSED | |"
    else
      strict_fail_count=$((strict_fail_count + 1))
      missing_text="$(IFS=,; printf '%s' "${missing[*]}")"
      strict_rows+="| ${run_id} | FAILED | ${missing_text} |"
    fi
    strict_rows+=$'\n'
  done
fi

state_rows=""
state_fail_count=0
if [[ "$state_gate" == "true" ]]; then
  for run_dir in "${run_dirs[@]}"; do
    if [[ ! -d "$run_dir" ]]; then
      continue
    fi
    run_id="$(basename "$run_dir")"
    missing=()
    for required_file in state-evaluation.json state-evaluation.md metadata-draft.json metadata-draft.md; do
      if [[ ! -s "$run_dir/$required_file" ]]; then
        missing+=("$required_file")
      fi
    done
    if [[ -s "$run_dir/metadata-draft.json" ]]; then
      assigned_actor="$(python3 - <<'PY' "$run_dir/metadata-draft.json"
import json
import sys
with open(sys.argv[1], encoding="utf-8") as fh:
    data = json.load(fh)
print(data.get("metadata", {}).get("assigned_actor") or "")
PY
)"
      if [[ -z "$assigned_actor" ]]; then
        missing+=("metadata.assigned_actor")
      fi
    fi
    if [[ -s "$run_dir/state-evaluation.json" ]]; then
      clarification_required="$(python3 - <<'PY' "$run_dir/state-evaluation.json"
import json
import sys
with open(sys.argv[1], encoding="utf-8") as fh:
    data = json.load(fh)
checks = data.get("checks", {})
requires = (
    data.get("to") == "needs_clarification"
    or (checks.get("requirement_gate") == "FAILED" and checks.get("clarification") == "MISSING")
    or (checks.get("requirement_gate") == "FAILED" and checks.get("clarification_gate") != "PASSED")
)
print("true" if requires else "false")
PY
)"
      if [[ "$clarification_required" == "true" && ! -s "$run_dir/clarification.md" ]]; then
        missing+=("clarification.md")
      fi
      if [[ "$clarification_required" == "true" && ! -s "$run_dir/clarification-gate.md" ]]; then
        missing+=("clarification-gate.md")
      elif [[ -s "$run_dir/clarification-gate.md" ]] && ! rg -q "Result: PASSED" "$run_dir/clarification-gate.md"; then
        missing+=("clarification-gate.result")
      fi
    fi
    if [[ ${#missing[@]} -eq 0 ]]; then
      state_rows+="| ${run_id} | PASSED | |"
    else
      state_fail_count=$((state_fail_count + 1))
      missing_text="$(IFS=,; printf '%s' "${missing[*]}")"
      state_rows+="| ${run_id} | FAILED | ${missing_text} |"
    fi
    state_rows+=$'\n'
  done
fi

report="# Toolchain Verification: ${case_id}

## Scope

- Case: ${case_id}
- Pattern: runs/${pattern}
- Sample run: ${first_run}
- Strict evidence gate: ${strict}
- State metadata gate: ${state_gate}
- Network access: false
- Remote writes: false

## Checks

| Check | Result | Error |
|---|---|---|
"

for row in "${checks[@]}"; do
  report+="${row}
"
done

if [[ "$strict" == "true" ]]; then
  report+="
## Strict Evidence Gate

| Run | Result | Missing Core Evidence |
|---|---|---|
${strict_rows}"
fi

if [[ "$state_gate" == "true" ]]; then
  report+="
## State Metadata Gate

| Run | Result | Missing State Evidence |
|---|---|---|
${state_rows}"
fi

conclusion="Local helper toolchain smoke checks passed."
if [[ "$check_fail_count" -gt 0 ]]; then
  conclusion="Local helper toolchain smoke checks failed for ${check_fail_count} check(s)."
elif [[ "$strict" == "true" && "$strict_fail_count" -gt 0 ]]; then
  conclusion="Local helper toolchain smoke checks passed, but strict evidence gate failed for ${strict_fail_count} run(s)."
elif [[ "$state_gate" == "true" && "$state_fail_count" -gt 0 ]]; then
  conclusion="Local helper toolchain smoke checks passed, but state metadata gate failed for ${state_fail_count} run(s)."
elif [[ "$strict" == "true" ]]; then
  conclusion="Local helper toolchain smoke checks and strict evidence gate passed."
fi

if [[ "$strict" == "true" && "$strict_fail_count" -eq 0 && "$state_gate" == "true" && "$state_fail_count" -eq 0 ]]; then
  conclusion="Local helper toolchain smoke checks, strict evidence gate, and state metadata gate passed."
elif [[ "$strict" == "false" && "$state_gate" == "true" && "$state_fail_count" -eq 0 ]]; then
  conclusion="Local helper toolchain smoke checks and state metadata gate passed."
fi

report+="
## Conclusion

${conclusion}
"

if [[ -n "$output" ]]; then
  mkdir -p "$(dirname "$output")"
  printf '%s' "$report" > "$output"
  echo "verification_report: $output"
else
  printf '%s' "$report"
fi

if [[ "$check_fail_count" -gt 0 ]]; then
  exit 1
fi

if [[ "$strict" == "true" && "$strict_fail_count" -gt 0 ]]; then
  exit 1
fi

if [[ "$state_gate" == "true" && "$state_fail_count" -gt 0 ]]; then
  exit 1
fi
