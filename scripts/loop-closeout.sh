#!/usr/bin/env bash
set -euo pipefail

show_help() {
  cat <<'HELP'
Usage: scripts/loop-closeout.sh --issue <issue> --task <task.md> --repo <repo> --run-id <run-id> [options]

Run the standard local closeout sequence for a Loop execution package.

Steps:
  1. loop-execution-preflight
  2. verify-toolchain --strict --state-gate
  3. share-preflight --persist-to-run
  4. evidence-checklist
  5. evidence-index
  6. loop-continuation-gate
  7. time-estimation-calibration
  8. execution-time-contract

Options:
  --issue <issue>             Issue identifier, required
  --task <task.md>            Task file, required
  --repo <repo>               Target repo, required
  --run-id <run-id>           Run id, required
  --output-dir <dir>          Output dir, default runs/<run-id>/closeout
  --allow-feishu-write        Pass through to execution preflight
  --allow-multica-write       Pass through to execution preflight
  --phase-report <auto|yes|no>
                              Pass through to execution preflight, default auto
  --operation-log <auto|yes|no>
                              Pass through to execution preflight, default auto
  --task-tier <L0|L1|L2|L3|L4|auto>
                              Pass through to execution preflight, default auto
  --started-at <iso>          Execution start timestamp for audited elapsed time, default script start
  --completed-at <iso>        Execution completion timestamp, default before continuation gate
  --elapsed-minutes <n>       Manual fallback only when timestamps are unavailable
  --no-phase-report           Shortcut for --phase-report no
  --no-operation-log          Shortcut for --operation-log no
  -h, --help                  Show this help

This script is local-only. It does not perform Feishu, Multica, Git remote, deploy, or Obsidian writes.
HELP
}

issue_id=""
task_file=""
repo_path=""
run_id=""
output_dir=""
allow_feishu_write="false"
allow_multica_write="false"
phase_report="auto"
operation_log="auto"
task_tier="auto"
elapsed_minutes="0"
started_at="$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
completed_at=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --issue)
      issue_id="${2:-}"; shift 2 ;;
    --task)
      task_file="${2:-}"; shift 2 ;;
    --repo)
      repo_path="${2:-}"; shift 2 ;;
    --run-id)
      run_id="${2:-}"; shift 2 ;;
    --output-dir)
      output_dir="${2:-}"; shift 2 ;;
    --allow-feishu-write)
      allow_feishu_write="true"; shift ;;
    --allow-multica-write)
      allow_multica_write="true"; shift ;;
    --phase-report)
      phase_report="${2:-}"; shift 2 ;;
    --operation-log)
      operation_log="${2:-}"; shift 2 ;;
    --task-tier)
      task_tier="${2:-}"; shift 2 ;;
    --started-at)
      started_at="${2:-}"; shift 2 ;;
    --completed-at)
      completed_at="${2:-}"; shift 2 ;;
    --elapsed-minutes)
      elapsed_minutes="${2:-}"; shift 2 ;;
    --no-phase-report)
      phase_report="no"; shift ;;
    --no-operation-log)
      operation_log="no"; shift ;;
    -h|--help)
      show_help; exit 0 ;;
    *)
      echo "Unknown argument: $1" >&2
      show_help
      exit 2 ;;
  esac
done

if [[ -z "$issue_id" || -z "$task_file" || -z "$repo_path" || -z "$run_id" ]]; then
  echo "--issue, --task, --repo, and --run-id are required" >&2
  show_help
  exit 2
fi

if [[ -z "$output_dir" ]]; then
  output_dir="runs/$run_id/closeout"
fi

if ! [[ "$elapsed_minutes" =~ ^[0-9]+$ ]]; then
  echo "--elapsed-minutes must be a non-negative integer" >&2
  exit 2
fi

run_dir="runs/$run_id"
if [[ ! -d "$run_dir" ]]; then
  echo "Run directory not found: $run_dir" >&2
  exit 1
fi

mkdir -p "$output_dir"
preflight_report="$run_dir/execution-preflight.md"
preflight_json="$run_dir/execution-preflight.json"
preflight_args=(--issue "$issue_id" --task "$task_file" --repo "$repo_path" --run-id "$run_id" --phase-report "$phase_report" --operation-log "$operation_log" --task-tier "$task_tier" --output "$preflight_report" --json-output "$preflight_json")
if [[ "$allow_feishu_write" == "true" ]]; then
  preflight_args+=(--allow-feishu-write)
fi
if [[ "$allow_multica_write" == "true" ]]; then
  preflight_args+=(--allow-multica-write)
fi

./scripts/loop-execution-preflight.sh "${preflight_args[@]}"
cp "$preflight_report" "$output_dir/execution-preflight.md"
cp "$preflight_json" "$output_dir/execution-preflight.json"
./scripts/verify-toolchain.sh \
  --case "$issue_id" \
  --pattern "$run_id" \
  --strict \
  --state-gate \
  --output "$run_dir/verification-report.md"
./scripts/share-preflight.sh \
  --case "$issue_id" \
  --pattern "$run_id" \
  --golden-run-id "$run_id" \
  --persist-to-run \
  --output-dir "$output_dir/share-preflight"
./scripts/evidence-checklist.sh \
  --run-id "$run_id" \
  --output "$run_dir/evidence-checklist.md"
./scripts/evidence-index.sh \
  --pattern "$run_id" \
  --output "$run_dir/evidence-index.md"

experience_draft="$run_dir/experience-draft.md"
experience_draft_json="$run_dir/experience-draft.json"
./scripts/extract-experience.sh \
  --run-id "$run_id" \
  --output "$experience_draft" \
  --json-output "$experience_draft_json" >/dev/null
cp "$experience_draft" "$output_dir/experience-draft.md"
cp "$experience_draft_json" "$output_dir/experience-draft.json"

continuation_report="$run_dir/continuation-gate.md"
continuation_json="$run_dir/continuation-gate.json"
if [[ -z "$completed_at" ]]; then
  completed_at="$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
fi
./scripts/loop-continuation-gate.sh \
  --issue "$issue_id" \
  --run-id "$run_id" \
  --task-tier "$task_tier" \
  --started-at "$started_at" \
  --completed-at "$completed_at" \
  --elapsed-minutes "$elapsed_minutes" \
  --stage closeout \
  --output "$continuation_report" \
  --json-output "$continuation_json"
cp "$continuation_report" "$output_dir/continuation-gate.md"
cp "$continuation_json" "$output_dir/continuation-gate.json"

calibration_report="$run_dir/time-estimation-calibration.md"
calibration_json="$run_dir/time-estimation-calibration.json"
./scripts/time-estimation-calibration.sh \
  --pattern "$run_id" \
  --output "$calibration_report" \
  --json-output "$calibration_json" >/dev/null
cp "$calibration_report" "$output_dir/time-estimation-calibration.md"
cp "$calibration_json" "$output_dir/time-estimation-calibration.json"

time_contract_report="$run_dir/execution-time-contract.md"
time_contract_json="$run_dir/execution-time-contract.json"
estimated_minutes="$(python3 - <<'PY' "$continuation_json"
import json, sys
with open(sys.argv[1], encoding='utf-8') as fh:
    data = json.load(fh)
print(data.get('estimated_minutes') or 0)
PY
)"
./scripts/execution-time-contract.sh \
  --estimate-minutes "$estimated_minutes" \
  --basis "loop-closeout task-tier ${task_tier}" \
  --started-at "$started_at" \
  --completed-at "$completed_at" \
  --stop-condition "closeout verification, continuation gate, and calibration completed" \
  --output "$time_contract_report" \
  --json-output "$time_contract_json" >/dev/null
cp "$time_contract_report" "$output_dir/execution-time-contract.md"
cp "$time_contract_json" "$output_dir/execution-time-contract.json"

python3 - <<'PY' "$output_dir/closeout-summary.md" "$issue_id" "$run_id" "$output_dir" "$preflight_json" "$continuation_json" "$calibration_json" "$time_contract_json"
import datetime as dt
import json
import sys
from pathlib import Path
out, issue, run_id, output_dir, preflight_json, continuation_json, calibration_json, time_contract_json = sys.argv[1:]
preflight = json.loads(Path(preflight_json).read_text(encoding="utf-8"))
writeback = preflight.get("writeback_recommendation", {})
continuation = json.loads(Path(continuation_json).read_text(encoding="utf-8"))
calibration = json.loads(Path(calibration_json).read_text(encoding="utf-8"))
calibration_summary = calibration.get("summary", {})
time_contract = json.loads(Path(time_contract_json).read_text(encoding="utf-8"))
text = f"""# Loop Closeout Summary: {issue}

- Generated at: {dt.datetime.now(dt.timezone.utc).replace(microsecond=0).isoformat().replace('+00:00', 'Z')}
- Run ID: {run_id}
- Output dir: {output_dir}
- Execution preflight: runs/{run_id}/execution-preflight.md
- Closeout preflight copy: {output_dir}/execution-preflight.md
- Verification report: runs/{run_id}/verification-report.md
- Share preflight summary: runs/{run_id}/share-preflight-summary.md
- Evidence checklist: runs/{run_id}/evidence-checklist.md
- Evidence index: runs/{run_id}/evidence-index.md
- Experience draft: runs/{run_id}/experience-draft.md
- Experience draft JSON: runs/{run_id}/experience-draft.json
- Continuation gate: runs/{run_id}/continuation-gate.md
- Time estimation calibration: runs/{run_id}/time-estimation-calibration.md
- Execution time contract: runs/{run_id}/execution-time-contract.md
- Phase report policy: {preflight.get('phase_report', {}).get('policy')}
- Operation log policy: {preflight.get('operation_log', {}).get('policy')}
- Multica write recommendation: {writeback.get('multica_write')}
- Done candidate after closeout: {str(writeback.get('done_candidate_after_closeout')).lower()}
- Continuation decision: {continuation.get('decision')}
- Timing source: {continuation.get('timing_source')}
- Started at: {continuation.get('started_at') or 'not-recorded'}
- Completed at: {continuation.get('completed_at') or 'not-recorded'}
- Estimated minutes: {continuation.get('estimated_minutes')}
- Elapsed seconds: {continuation.get('elapsed_seconds') if continuation.get('elapsed_seconds') is not None else 'not-measured'}
- Elapsed minutes: {continuation.get('elapsed_minutes')}
- Estimate accuracy: {continuation.get('estimate_accuracy')}
- Variance ratio: {continuation.get('variance_ratio')}
- Trusted measured runs: {calibration_summary.get('trusted_measured_runs')}
- Manual timing runs: {calibration_summary.get('manual_timing_runs')}
- Recommended next estimate minutes: {calibration_summary.get('recommended_next_estimate_minutes') if calibration_summary.get('recommended_next_estimate_minutes') is not None else 'not-measured'}
- Time contract within estimate: {str(time_contract.get('within_estimate')).lower()}
- Time contract next estimate minutes: {time_contract.get('next_estimate_minutes')}

## Result

Local closeout completed. Obsidian sync, Feishu writes, Multica writes, Git remote operations, and deploys were not performed by this script.
"""
Path(out).write_text(text, encoding="utf-8")
print(f"closeout_summary: {out}")
PY

cat "$output_dir/closeout-summary.md"
