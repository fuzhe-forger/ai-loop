#!/usr/bin/env bash
set -euo pipefail

show_help() {
  cat <<'HELP'
Usage: scripts/execution-time-contract.sh --estimate-minutes <n|a-b> [options]

Generate a local execution time contract for in-window or Loop tasks.
It supports two modes:
  1. start-only: provide estimate and optional started-at to emit a plan block.
  2. closeout: provide started-at and completed-at to emit actual elapsed time and variance.

Options:
  --estimate-minutes <n|a-b>  Estimated minutes or range, required
  --basis <text>              Estimate basis, default empty
  --task-type <type>          Optional task type for calibration buckets
  --started-at <iso>          UTC start timestamp, default now
  --completed-at <iso>        UTC completion timestamp, optional
  --stop-condition <text>     Stop/continue/approval condition, default empty
  --output <file>             Optional Markdown output path
  --json-output <file>        Optional JSON output path
  -h, --help                  Show this help

This script is local-only. It never performs remote writes.
HELP
}

estimate_minutes=""
basis=""
task_type=""
started_at=""
completed_at=""
stop_condition=""
output_file=""
json_output_file=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --estimate-minutes)
      estimate_minutes="${2:-}"; shift 2 ;;
    --basis)
      basis="${2:-}"; shift 2 ;;
    --task-type)
      task_type="${2:-}"; shift 2 ;;
    --started-at)
      started_at="${2:-}"; shift 2 ;;
    --completed-at)
      completed_at="${2:-}"; shift 2 ;;
    --stop-condition)
      stop_condition="${2:-}"; shift 2 ;;
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

if [[ -z "$estimate_minutes" ]]; then
  echo "--estimate-minutes is required" >&2
  show_help
  exit 2
fi

if [[ ! "$estimate_minutes" =~ ^[0-9]+(-[0-9]+)?$ ]]; then
  echo "--estimate-minutes must be an integer or range like 10-15" >&2
  exit 2
fi

if [[ -z "$started_at" ]]; then
  started_at="$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
fi

json_report="$(python3 - <<'PY' "$estimate_minutes" "$basis" "$task_type" "$started_at" "$completed_at" "$stop_condition"
import datetime as dt
import json
import sys

estimate, basis, task_type, started_at, completed_at, stop_condition = sys.argv[1:]

def parse_ts(value):
    if not value:
        return None
    parsed = dt.datetime.fromisoformat(value.replace("Z", "+00:00"))
    if parsed.tzinfo is None:
        parsed = parsed.replace(tzinfo=dt.timezone.utc)
    return parsed.astimezone(dt.timezone.utc).replace(microsecond=0)

def iso(value):
    if value is None:
        return None
    return value.isoformat().replace("+00:00", "Z")

if "-" in estimate:
    low_text, high_text = estimate.split("-", 1)
    estimate_low = int(low_text)
    estimate_high = int(high_text)
else:
    estimate_low = int(estimate)
    estimate_high = int(estimate)
if estimate_low > estimate_high:
    raise SystemExit("estimate range must be low-high")

started = parse_ts(started_at)
completed = parse_ts(completed_at)
elapsed_seconds = None
elapsed_minutes = None
within_estimate = None
absolute_error_minutes = None
within_one_minute = None
variance_note = "not_completed"
next_estimate_minutes = estimate
if completed is not None:
    elapsed_seconds = int(round((completed - started).total_seconds()))
    if elapsed_seconds < 0:
        raise SystemExit("--completed-at must be greater than or equal to --started-at")
    elapsed_minutes = round(elapsed_seconds / 60, 1)
    within_estimate = estimate_low <= elapsed_minutes <= estimate_high
    if within_estimate:
        absolute_error_minutes = 0.0
    elif elapsed_minutes < estimate_low:
        absolute_error_minutes = round(estimate_low - elapsed_minutes, 1)
    else:
        absolute_error_minutes = round(elapsed_minutes - estimate_high, 1)
    within_one_minute = absolute_error_minutes < 1
    if within_estimate:
        variance_note = "within_estimate"
        next_estimate_minutes = estimate
    elif elapsed_minutes < estimate_low:
        variance_note = "lower_than_estimate"
        next_estimate_minutes = f"{max(1, int(elapsed_minutes))}-{max(1, int(round((estimate_low + elapsed_minutes) / 2)))}"
    else:
        variance_note = "higher_than_estimate"
        next_estimate_minutes = f"{int(round((estimate_high + elapsed_minutes) / 2))}-{int(round(elapsed_minutes))}"

report = {
    "schema_version": 1,
    "generated_at": iso(dt.datetime.now(dt.timezone.utc).replace(microsecond=0)),
    "estimate_minutes": estimate,
    "estimate_low_minutes": estimate_low,
    "estimate_high_minutes": estimate_high,
    "basis": basis,
    "task_type": task_type or None,
    "started_at": iso(started),
    "completed_at": iso(completed),
    "elapsed_seconds": elapsed_seconds,
    "elapsed_minutes": elapsed_minutes,
    "within_estimate": within_estimate,
    "absolute_error_minutes": absolute_error_minutes,
    "within_one_minute": within_one_minute,
    "variance_note": variance_note,
    "next_estimate_minutes": next_estimate_minutes,
    "stop_condition": stop_condition,
}
print(json.dumps(report, ensure_ascii=False, indent=2))
PY
)"

markdown_report="$(python3 - <<'PY' "$json_report"
import json
import sys
report = json.loads(sys.argv[1])
print(f"""# Execution Time Contract

## Time Estimate

- Estimate minutes: {report['estimate_minutes']}
- Basis: {report['basis'] or 'not-provided'}
- Task type: {report.get('task_type') or 'not-provided'}
- Started at: {report['started_at']}
- Stop condition: {report['stop_condition'] or 'not-provided'}
""")
if report.get("completed_at"):
    print(f"""## Time Closeout

- Completed at: {report['completed_at']}
- Elapsed seconds: {report['elapsed_seconds']}
- Elapsed minutes: {report['elapsed_minutes']}
- Within estimate: {str(report['within_estimate']).lower()}
- Absolute error minutes: {report['absolute_error_minutes']}
- Within one minute: {str(report['within_one_minute']).lower()}
- Variance note: {report['variance_note']}
- Next estimate minutes: {report['next_estimate_minutes']}
""")
else:
    print("## Time Closeout\n\n- Status: not-completed\n")
PY
)"

if [[ -n "$json_output_file" ]]; then
  mkdir -p "$(dirname "$json_output_file")"
  printf '%s\n' "$json_report" > "$json_output_file"
  echo "time_contract_json: $json_output_file"
fi
if [[ -n "$output_file" ]]; then
  mkdir -p "$(dirname "$output_file")"
  printf '%s\n' "$markdown_report" > "$output_file"
  echo "time_contract_report: $output_file"
fi
if [[ -z "$json_output_file" && -z "$output_file" ]]; then
  printf '%s\n' "$markdown_report"
fi
