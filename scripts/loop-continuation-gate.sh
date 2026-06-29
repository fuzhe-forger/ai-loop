#!/usr/bin/env bash
set -euo pipefail

show_help() {
  cat <<'HELP'
Usage: scripts/loop-continuation-gate.sh --issue <issue> --run-id <run-id> [options]

Decide whether an agent may stop after a Loop slice or must continue to the next substantive slice.

Options:
  --issue <issue>             Issue identifier, required
  --run-id <run-id>           Run id, required
  --task-tier <L0|L1|L2|L3|L4|auto>
                              Task tier, default auto
  --started-at <iso>          Execution start timestamp; used for auditable elapsed time
  --completed-at <iso>        Execution completion timestamp; default now when --started-at is set
  --elapsed-minutes <n>       Manual fallback only; not auditable unless timestamps are unavailable
  --stage <name>              Current stage label, default slice
  --same-failure-count <n>    Consecutive same-failure count, default 0
  --l4-boundary               A prohibited/high-risk boundary was reached
  --closeout-complete         Override closeout completion to true
  --writeback-complete        Override writeback completion to true
  --output <file>             Write Markdown report
  --json-output <file>        Write JSON report
  -h, --help                  Show this help

The script is local-only. It never performs remote writes, Obsidian sync, Git remote operations, deploys, installs, or destructive filesystem actions.
HELP
}

issue_id=""
run_id=""
task_tier="auto"
elapsed_minutes="0"
started_at=""
completed_at=""
stage="slice"
same_failure_count="0"
l4_boundary="false"
closeout_override="auto"
writeback_override="auto"
output_file=""
json_output_file=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --issue)
      issue_id="${2:-}"; shift 2 ;;
    --run-id)
      run_id="${2:-}"; shift 2 ;;
    --task-tier)
      task_tier="${2:-}"; shift 2 ;;
    --started-at)
      started_at="${2:-}"; shift 2 ;;
    --completed-at)
      completed_at="${2:-}"; shift 2 ;;
    --elapsed-minutes)
      elapsed_minutes="${2:-}"; shift 2 ;;
    --stage)
      stage="${2:-}"; shift 2 ;;
    --same-failure-count)
      same_failure_count="${2:-}"; shift 2 ;;
    --l4-boundary)
      l4_boundary="true"; shift ;;
    --closeout-complete)
      closeout_override="true"; shift ;;
    --writeback-complete)
      writeback_override="true"; shift ;;
    --output)
      output_file="${2:-}"; shift 2 ;;
    --json-output)
      json_output_file="${2:-}"; shift 2 ;;
    -h|--help)
      show_help; exit 0 ;;
    *)
      echo "Unknown argument: $1" >&2
      show_help
      exit 2 ;;
  esac
done

if [[ -z "$issue_id" || -z "$run_id" ]]; then
  echo "--issue and --run-id are required" >&2
  show_help
  exit 2
fi

case "$task_tier" in
  L0|L1|L2|L3|L4|auto) ;;
  *) echo "--task-tier must be L0, L1, L2, L3, L4, or auto" >&2; exit 2 ;;
esac

if ! [[ "$elapsed_minutes" =~ ^[0-9]+$ ]]; then
  echo "--elapsed-minutes must be a non-negative integer" >&2
  exit 2
fi
if ! [[ "$same_failure_count" =~ ^[0-9]+$ ]]; then
  echo "--same-failure-count must be a non-negative integer" >&2
  exit 2
fi

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
run_dir="$ROOT_DIR/runs/$run_id"
if [[ ! -d "$run_dir" ]]; then
  echo "Run directory not found: runs/$run_id" >&2
  exit 1
fi

json_report="$(python3 - <<'PY' "$ROOT_DIR" "$issue_id" "$run_id" "$task_tier" "$elapsed_minutes" "$started_at" "$completed_at" "$stage" "$same_failure_count" "$l4_boundary" "$closeout_override" "$writeback_override"
import datetime as dt
import json
import sys
from pathlib import Path

root, issue, run_id, task_tier, elapsed, started_at, completed_at, stage, same_failure_count, l4_boundary, closeout_override, writeback_override = sys.argv[1:]
root_path = Path(root)
run_dir = root_path / "runs" / run_id
def parse_ts(value):
    if not value:
        return None
    normalized = value.replace("Z", "+00:00")
    return dt.datetime.fromisoformat(normalized)

started_dt = parse_ts(started_at)
completed_dt = parse_ts(completed_at) if completed_at else None
if started_dt and not completed_dt:
    completed_dt = dt.datetime.now(dt.timezone.utc)
if started_dt and completed_dt:
    if started_dt.tzinfo is None:
        started_dt = started_dt.replace(tzinfo=dt.timezone.utc)
    if completed_dt.tzinfo is None:
        completed_dt = completed_dt.replace(tzinfo=dt.timezone.utc)
    elapsed_seconds = int(round((completed_dt - started_dt).total_seconds()))
    if elapsed_seconds < 0:
        raise SystemExit("--completed-at must be greater than or equal to --started-at")
    elapsed_minutes = int(round(elapsed_seconds / 60))
    timing_source = "timestamp"
    started_at_out = started_dt.astimezone(dt.timezone.utc).replace(microsecond=0).isoformat().replace("+00:00", "Z")
    completed_at_out = completed_dt.astimezone(dt.timezone.utc).replace(microsecond=0).isoformat().replace("+00:00", "Z")
else:
    elapsed_minutes = int(elapsed)
    elapsed_seconds = elapsed_minutes * 60 if elapsed_minutes > 0 else None
    timing_source = "manual" if elapsed_minutes > 0 else "not_measured"
    started_at_out = None
    completed_at_out = None
same_failure_count = int(same_failure_count)
policy_path = root_path / "config" / "timebox-policy.json"
timebox_policy = json.loads(policy_path.read_text(encoding="utf-8"))

preflight_path = run_dir / "execution-preflight.json"
preflight = {}
if preflight_path.exists():
    try:
        preflight = json.loads(preflight_path.read_text(encoding="utf-8"))
    except json.JSONDecodeError:
        preflight = {}

inferred_tier = task_tier
if inferred_tier == "auto":
    auto_policy = timebox_policy.get("auto_tier") or {}
    inferred_tier = (preflight.get("timebox") or {}).get("tier") or (auto_policy.get("with_issue_and_run_id", "L2") if issue and run_id else auto_policy.get("fallback", "L1"))

tier_policy = (timebox_policy.get("tiers") or {}).get(inferred_tier) or (timebox_policy.get("tiers") or {}).get(timebox_policy.get("default_tier", "L1"), {})
estimated_minutes = int(tier_policy.get("estimated_minutes", tier_policy.get("minimum_continuous_minutes", 30)))
anti_idle_floor_minutes = int(tier_policy.get("anti_idle_floor_minutes", tier_policy.get("hard_floor_minutes", 0)))
acceptable_variance_ratio = float(tier_policy.get("acceptable_variance_ratio", 0.5))
if timing_source != "timestamp":
    estimate_accuracy = "not_measured" if timing_source == "not_measured" else "untrusted_timing"
    variance_ratio = None
elif elapsed_minutes == 0:
    estimate_accuracy = "not_measured"
    variance_ratio = None
elif estimated_minutes == 0:
    estimate_accuracy = "not_applicable"
    variance_ratio = None
else:
    variance_ratio = round(abs(elapsed_minutes - estimated_minutes) / estimated_minutes, 4)
    estimate_accuracy = "within_tolerance" if variance_ratio <= acceptable_variance_ratio else "outside_tolerance"

closeout_files = [
    run_dir / "closeout" / "closeout-summary.md",
    run_dir / "verification-report.md",
    run_dir / "share-preflight-summary.json",
    run_dir / "evidence-checklist.md",
    run_dir / "evidence-index.md",
]
closeout_detected = all(path.exists() and path.stat().st_size > 0 for path in closeout_files)

writeback_detected = False
writeback_reasons = []
share_path = run_dir / "share-preflight-summary.json"
if share_path.exists():
    try:
        share = json.loads(share_path.read_text(encoding="utf-8"))
        for item in share.get("approval_boundary") or []:
            if item.get("remote_write_done") == "YES":
                writeback_detected = True
                writeback_reasons.append("share_preflight_remote_write_done")
                break
    except json.JSONDecodeError:
        pass
issue_readback_path = run_dir / "multica-six-hour-final-issue-readback.json"
if issue_readback_path.exists():
    try:
        issue_readback = json.loads(issue_readback_path.read_text(encoding="utf-8"))
        metadata = issue_readback.get("metadata") or {}
        if issue_readback.get("status") == "done" or metadata.get("execution_package_status") == "done":
            writeback_detected = True
            writeback_reasons.append("final_issue_readback_done")
    except json.JSONDecodeError:
        pass
metadata_readback_path = run_dir / "multica-six-hour-final-metadata-readback.json"
if metadata_readback_path.exists():
    try:
        metadata_readback = json.loads(metadata_readback_path.read_text(encoding="utf-8"))
        if metadata_readback.get("execution_package_status") == "done" or metadata_readback.get("pipeline_status") == "done":
            writeback_detected = True
            writeback_reasons.append("metadata_readback_done")
    except json.JSONDecodeError:
        pass

if closeout_override == "true":
    closeout_complete = True
    closeout_source = "override"
else:
    closeout_complete = closeout_detected
    closeout_source = "detected"
if writeback_override == "true":
    writeback_complete = True
    writeback_source = "override"
else:
    writeback_complete = writeback_detected
    writeback_source = "detected"

blocking_reasons = []
continue_reasons = []
allow_stop_reasons = []

def add_continue(reason):
    continue_reasons.append(reason)

def add_allow(reason):
    allow_stop_reasons.append(reason)

if inferred_tier == "L4" or l4_boundary == "true":
    decision = "STOP_FOR_APPROVAL"
    blocking_reasons.append("L4 approval boundary reached")
elif same_failure_count >= 3:
    decision = "STOP_FOR_ASSISTANCE"
    blocking_reasons.append("same failure repeated at least 3 times")
elif inferred_tier == "L0":
    decision = "ALLOW_STOP"
    add_allow("L0 quick answer has no minimum continuation window")
elif inferred_tier == "L1":
    if closeout_complete:
        decision = "ALLOW_STOP"
        add_allow("acceptance met: L1 verified slice complete")
    elif elapsed_minutes >= estimated_minutes:
        decision = "ALLOW_STOP"
        add_allow("estimated window reached")
    else:
        decision = "CONTINUE"
        add_continue("verified slice incomplete")
elif inferred_tier == "L2":
    if closeout_complete and writeback_complete:
        decision = "ALLOW_STOP"
        add_allow("acceptance met: closeout and writeback are complete")
    elif closeout_complete and elapsed_minutes >= anti_idle_floor_minutes:
        decision = "ALLOW_STOP"
        add_allow("acceptance met: closeout complete after anti-idle floor")
    else:
        decision = "CONTINUE"
        if elapsed_minutes < anti_idle_floor_minutes:
            add_continue("elapsed minutes below L2 anti-idle floor and acceptance not complete")
        if not closeout_complete:
            add_continue("closeout package incomplete")
        if not writeback_complete:
            add_continue("writeback/readback incomplete")
elif inferred_tier == "L3":
    if closeout_complete:
        decision = "ALLOW_STOP"
        add_allow("acceptance met: L3 phase closeout complete")
    else:
        decision = "CONTINUE"
        if elapsed_minutes < anti_idle_floor_minutes:
            add_continue("elapsed minutes below L3 anti-idle floor and phase closeout incomplete")
        if not closeout_complete:
            add_continue("phase closeout incomplete")
else:
    decision = "CONTINUE"
    add_continue("unknown tier defaults to continue")

next_actions = []
if decision == "CONTINUE":
    if not closeout_complete:
        next_actions.append("finish closeout evidence and verification")
    if not writeback_complete and inferred_tier in {"L2", "L3"}:
        next_actions.append("perform approved writeback/readback or prepare draft")
    next_actions.append("select next substantive implementation or governance slice")
elif decision == "ALLOW_STOP":
    next_actions.append("summarize changed files, verification, and synced/generated outputs")
elif decision == "STOP_FOR_APPROVAL":
    next_actions.append("present side-effect boundary and wait for explicit approval")
else:
    next_actions.append("summarize blocker and ask for missing external input")

report = {
    "schema_version": 1,
    "issue": issue,
    "run_id": run_id,
    "stage": stage,
    "tier": inferred_tier,
    "timing_source": timing_source,
    "started_at": started_at_out,
    "completed_at": completed_at_out,
    "elapsed_seconds": elapsed_seconds,
    "elapsed_minutes": elapsed_minutes,
    "estimated_minutes": estimated_minutes,
    "minimum_continuous_minutes": estimated_minutes,
    "anti_idle_floor_minutes": anti_idle_floor_minutes,
    "acceptable_variance_ratio": acceptable_variance_ratio,
    "estimate_accuracy": estimate_accuracy,
    "variance_ratio": variance_ratio,
    "same_failure_count": same_failure_count,
    "l4_boundary": l4_boundary == "true",
    "closeout": {
        "complete": closeout_complete,
        "source": closeout_source,
        "required_files": [str(path.relative_to(root_path)) for path in closeout_files],
    },
    "writeback": {
        "complete": writeback_complete,
        "source": writeback_source,
        "reasons": sorted(set(writeback_reasons)),
    },
    "decision": decision,
    "continue_reasons": continue_reasons,
    "allow_stop_reasons": allow_stop_reasons,
    "blocking_reasons": blocking_reasons,
    "next_actions": next_actions,
}
print(json.dumps(report, ensure_ascii=False, indent=2))
PY
)"

markdown_report="$(python3 - <<'PY' "$json_report"
import json
import sys
report = json.loads(sys.argv[1])

def bullets(items, fallback="- none"):
    return "\n".join(f"- {item}" for item in items) if items else fallback

print(f"""# Loop Continuation Gate: {report['issue']}

## Decision

- Decision: {report['decision']}
- Run ID: {report['run_id']}
- Stage: {report['stage']}
- Tier: {report['tier']}
- Timing source: {report['timing_source']}
- Started at: {report['started_at'] or 'not-recorded'}
- Completed at: {report['completed_at'] or 'not-recorded'}
- Elapsed seconds: {report['elapsed_seconds'] if report['elapsed_seconds'] is not None else 'not-measured'}
- Elapsed minutes: {report['elapsed_minutes']}
- Estimated minutes: {report['estimated_minutes']}
- Anti-idle floor minutes: {report['anti_idle_floor_minutes']}
- Estimate accuracy: {report['estimate_accuracy']}
- Variance ratio: {report['variance_ratio'] if report['variance_ratio'] is not None else 'not-measured'}
- Same failure count: {report['same_failure_count']}
- L4 boundary: {str(report['l4_boundary']).lower()}

## Closeout

- Complete: {str(report['closeout']['complete']).lower()}
- Source: {report['closeout']['source']}

## Writeback

- Complete: {str(report['writeback']['complete']).lower()}
- Source: {report['writeback']['source']}
- Reasons: {', '.join(report['writeback']['reasons']) if report['writeback']['reasons'] else 'none'}

## Continue Reasons

{bullets(report['continue_reasons'])}

## Allow Stop Reasons

{bullets(report['allow_stop_reasons'])}

## Blocking Reasons

{bullets(report['blocking_reasons'])}

## Next Actions

{bullets(report['next_actions'])}
""")
PY
)"

if [[ -n "$json_output_file" ]]; then
  mkdir -p "$(dirname "$json_output_file")"
  printf '%s\n' "$json_report" > "$json_output_file"
  echo "continuation_gate_json: $json_output_file"
fi
if [[ -n "$output_file" ]]; then
  mkdir -p "$(dirname "$output_file")"
  printf '%s\n' "$markdown_report" > "$output_file"
  echo "continuation_gate: $output_file"
fi

if [[ -z "$output_file" && -z "$json_output_file" ]]; then
  printf '%s\n' "$markdown_report"
fi
