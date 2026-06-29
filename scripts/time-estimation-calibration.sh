#!/usr/bin/env bash
set -euo pipefail

show_help() {
  cat <<'HELP'
Usage: scripts/time-estimation-calibration.sh --pattern <glob> [options]

Generate a local calibration report from Loop continuation gate evidence.

Options:
  --pattern <glob>   Run glob under runs/, for example 'FUZ-554*', required
  --output <file>    Optional Markdown output path
  --json-output <file>
                     Optional JSON output path
  -h, --help         Show this help

This script is local-only. It reads runs/ and never performs remote writes.
HELP
}

pattern=""
output_file=""
json_output_file=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --pattern)
      pattern="${2:-}"; shift 2 ;;
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

if [[ -z "$pattern" ]]; then
  echo "--pattern is required" >&2
  show_help
  exit 2
fi

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

shopt -s nullglob
run_dirs=(runs/$pattern)
shopt -u nullglob

if [[ ${#run_dirs[@]} -eq 0 ]]; then
  echo "No run directories matched: runs/$pattern" >&2
  exit 1
fi

json_report="$(python3 - <<'PY' "$pattern" "${run_dirs[@]}"
import datetime as dt
import json
import sys
from pathlib import Path

pattern = sys.argv[1]
run_dirs = [Path(item) for item in sys.argv[2:]]
rows = []
missing = []


def parse_range_midpoint(value):
    if value is None:
        return None
    if isinstance(value, (int, float)):
        return int(round(float(value)))
    text = str(value).strip()
    if not text:
        return None
    if "-" in text:
        low_text, high_text = text.split("-", 1)
        try:
            low = float(low_text)
            high = float(high_text)
        except ValueError:
            return None
        return int(round((low + high) / 2))
    try:
        return int(round(float(text)))
    except ValueError:
        return None


def row_from_continuation(run_dir, data):
    estimated = data.get("estimated_minutes")
    elapsed = data.get("elapsed_minutes")
    timing_source = data.get("timing_source") or "legacy_unknown"
    trusted_timing = timing_source == "timestamp"
    variance = data.get("variance_ratio") if trusted_timing else None
    accuracy = (data.get("estimate_accuracy") or "unknown") if trusted_timing else "untrusted_timing"
    decision = data.get("decision")
    tier = data.get("tier")
    issue = data.get("issue")
    return build_row(
        run_dir=run_dir,
        source_artifact="continuation-gate.json",
        issue=issue,
        tier=tier,
        decision=decision,
        timing_source=timing_source,
        trusted_timing=trusted_timing,
        started_at=data.get("started_at"),
        completed_at=data.get("completed_at"),
        elapsed_seconds=data.get("elapsed_seconds"),
        estimated=estimated,
        elapsed=elapsed,
        variance=variance,
        accuracy=accuracy,
        explicit_recommended=None,
        task_type="loop_continuation",
    )


def row_from_time_contract(run_dir, path, data):
    estimated = data.get("estimate_high_minutes")
    elapsed = data.get("elapsed_minutes")
    timing_source = "timestamp" if data.get("started_at") and data.get("completed_at") else "not_measured"
    trusted_timing = timing_source == "timestamp"
    variance = None
    accuracy = "not_measured"
    absolute_error = data.get("absolute_error_minutes")
    within_one_minute = data.get("within_one_minute")
    if trusted_timing and isinstance(estimated, (int, float)) and isinstance(elapsed, (int, float)) and estimated:
        variance = round(abs(elapsed - estimated) / estimated, 4)
        accuracy = "within_tolerance" if data.get("within_estimate") is True else "outside_tolerance"
        if not isinstance(absolute_error, (int, float)):
            absolute_error = 0.0 if data.get("within_estimate") is True else round(abs(elapsed - estimated), 1)
        if within_one_minute is None:
            within_one_minute = absolute_error < 1
    explicit_recommended = None
    if trusted_timing and data.get("within_estimate") is not True:
        explicit_recommended = parse_range_midpoint(data.get("next_estimate_minutes"))
    task_type = data.get("task_type") or infer_task_type_from_contract(path.name, data.get("basis") or "")
    return build_row(
        run_dir=run_dir,
        source_artifact=path.name,
        issue=None,
        tier=None,
        decision="ALLOW_STOP" if data.get("completed_at") else "NOT_COMPLETED",
        timing_source=timing_source,
        trusted_timing=trusted_timing,
        started_at=data.get("started_at"),
        completed_at=data.get("completed_at"),
        elapsed_seconds=data.get("elapsed_seconds"),
        estimated=estimated,
        elapsed=elapsed,
        variance=variance,
        accuracy=accuracy,
        explicit_recommended=explicit_recommended,
        task_type=task_type,
        absolute_error=absolute_error,
        within_one_minute=within_one_minute,
    )


def infer_task_type_from_contract(source_artifact, basis):
    text = f"{source_artifact} {basis}".lower()
    local_script_markers = [
        "script",
        "golden path",
        "share-preflight",
        "preflight",
        "calibration",
        "obsidian",
        "evidence",
        "local-only sinan",
    ]
    if any(marker in text for marker in local_script_markers):
        return "local_script_patch"
    return "unknown"


def build_row(
    run_dir,
    source_artifact,
    issue,
    tier,
    decision,
    timing_source,
    trusted_timing,
    started_at,
    completed_at,
    elapsed_seconds,
    estimated,
    elapsed,
    variance,
    accuracy,
    explicit_recommended,
    task_type="unknown",
    absolute_error=None,
    within_one_minute=None,
):
    direction = "unknown"
    recommended = estimated
    if trusted_timing and isinstance(estimated, (int, float)) and isinstance(elapsed, (int, float)):
        if elapsed < estimated:
            direction = "overestimated"
        elif elapsed > estimated:
            direction = "underestimated"
        else:
            direction = "accurate"
        recommended = explicit_recommended if explicit_recommended is not None else (int(round((estimated + elapsed) / 2)) if estimated and elapsed else elapsed or estimated)
        if not isinstance(absolute_error, (int, float)):
            absolute_error = round(abs(elapsed - estimated), 1)
        if within_one_minute is None:
            within_one_minute = absolute_error < 1
    return {
        "run_id": run_dir.name,
        "issue": issue,
        "tier": tier,
        "decision": decision,
        "source_artifact": source_artifact,
        "task_type": task_type or "unknown",
        "timing_source": timing_source,
        "trusted_timing": trusted_timing,
        "started_at": started_at,
        "completed_at": completed_at,
        "elapsed_seconds": elapsed_seconds,
        "estimated_minutes": estimated,
        "elapsed_minutes": elapsed,
        "variance_ratio": variance,
        "estimate_accuracy": accuracy,
        "absolute_error_minutes": absolute_error if trusted_timing else None,
        "within_one_minute": within_one_minute if trusted_timing else None,
        "direction": direction,
        "recommended_next_estimate_minutes": recommended if trusted_timing else None,
        "acceptance_met": decision == "ALLOW_STOP",
    }


for run_dir in run_dirs:
    if not run_dir.is_dir():
        continue
    added_rows = 0
    continuation_path = run_dir / "continuation-gate.json"
    if continuation_path.exists():
        try:
            rows.append(row_from_continuation(run_dir, json.loads(continuation_path.read_text(encoding="utf-8"))))
            added_rows += 1
        except json.JSONDecodeError:
            missing.append(str(continuation_path))
    for time_contract_path in sorted(run_dir.glob("execution-time-contract*.json")):
        try:
            rows.append(row_from_time_contract(run_dir, time_contract_path, json.loads(time_contract_path.read_text(encoding="utf-8"))))
            added_rows += 1
        except json.JSONDecodeError:
            missing.append(str(time_contract_path))
    if added_rows == 0:
        missing.append(str(run_dir))

measured = [
    row for row in rows
    if row.get("trusted_timing")
    and isinstance(row.get("estimated_minutes"), (int, float))
    and isinstance(row.get("elapsed_minutes"), (int, float))
    and row.get("elapsed_minutes", 0) > 0
]
count = len(rows)
measured_count = len(measured)
manual_count = sum(1 for row in rows if row.get("timing_source") == "manual")
not_measured_count = sum(1 for row in rows if row.get("timing_source") == "not_measured")
legacy_unknown_count = sum(1 for row in rows if row.get("timing_source") == "legacy_unknown")
time_contract_count = sum(1 for row in rows if str(row.get("source_artifact") or "").startswith("execution-time-contract"))
avg_variance = None
if measured:
    avg_variance = round(sum(float(row.get("variance_ratio") or 0) for row in measured) / measured_count, 4)
overestimated = sum(1 for row in measured if row["direction"] == "overestimated")
underestimated = sum(1 for row in measured if row["direction"] == "underestimated")
accurate = sum(1 for row in measured if row["direction"] == "accurate")
outside = sum(1 for row in measured if row.get("estimate_accuracy") == "outside_tolerance")
one_minute_hit_count = sum(1 for row in measured if row.get("within_one_minute") is True)
one_minute_miss_count = sum(1 for row in measured if row.get("within_one_minute") is False)
one_minute_hit_rate = round(one_minute_hit_count / measured_count, 4) if measured_count else None
next_estimate = None
if measured:
    next_estimate = int(round(sum(float(row["recommended_next_estimate_minutes"] or 0) for row in measured) / measured_count))
task_type_buckets = {}
for row in measured:
    task_type = row.get("task_type") or "unknown"
    bucket = task_type_buckets.setdefault(task_type, {
        "runs": 0,
        "recommended_values": [],
        "overestimated_runs": 0,
        "underestimated_runs": 0,
        "accurate_runs": 0,
        "one_minute_hit_runs": 0,
        "one_minute_miss_runs": 0,
    })
    bucket["runs"] += 1
    bucket["recommended_values"].append(float(row.get("recommended_next_estimate_minutes") or 0))
    if row.get("direction") == "overestimated":
        bucket["overestimated_runs"] += 1
    elif row.get("direction") == "underestimated":
        bucket["underestimated_runs"] += 1
    elif row.get("direction") == "accurate":
        bucket["accurate_runs"] += 1
    if row.get("within_one_minute") is True:
        bucket["one_minute_hit_runs"] += 1
    elif row.get("within_one_minute") is False:
        bucket["one_minute_miss_runs"] += 1
for bucket in task_type_buckets.values():
    values = bucket.pop("recommended_values")
    bucket["recommended_next_estimate_minutes"] = int(round(sum(values) / len(values))) if values else None
    bucket["one_minute_hit_rate"] = round(bucket["one_minute_hit_runs"] / bucket["runs"], 4) if bucket.get("runs") else None
per_slice_recommendations = []
for row in measured:
    source = row.get("source_artifact") or ""
    if not source.startswith("execution-time-contract-"):
        continue
    slice_name = source.removeprefix("execution-time-contract-").removesuffix(".json")
    per_slice_recommendations.append({
        "slice": slice_name,
        "task_type": row.get("task_type") or "unknown",
        "estimated_minutes": row.get("estimated_minutes"),
        "elapsed_minutes": row.get("elapsed_minutes"),
        "absolute_error_minutes": row.get("absolute_error_minutes"),
        "within_one_minute": row.get("within_one_minute"),
        "direction": row.get("direction"),
        "recommended_next_estimate_minutes": row.get("recommended_next_estimate_minutes"),
    })
report = {
    "schema_version": 1,
    "generated_at": dt.datetime.now(dt.timezone.utc).replace(microsecond=0).isoformat().replace("+00:00", "Z"),
    "pattern": f"runs/{pattern}",
    "summary": {
        "runs_seen": count,
        "trusted_measured_runs": measured_count,
        "measured_runs": measured_count,
        "manual_timing_runs": manual_count,
        "not_measured_runs": not_measured_count,
        "legacy_unknown_timing_runs": legacy_unknown_count,
        "execution_time_contract_runs": time_contract_count,
        "missing_continuation_gate": len(missing),
        "average_variance_ratio": avg_variance,
        "overestimated_runs": overestimated,
        "underestimated_runs": underestimated,
        "accurate_runs": accurate,
        "outside_tolerance_runs": outside,
        "one_minute_hit_runs": one_minute_hit_count,
        "one_minute_miss_runs": one_minute_miss_count,
        "one_minute_hit_rate": one_minute_hit_rate,
        "recommended_next_estimate_minutes": next_estimate,
        "task_type_buckets": task_type_buckets,
        "per_slice_recommendations": per_slice_recommendations,
    },
    "runs": rows,
    "missing": missing,
}
print(json.dumps(report, ensure_ascii=False, indent=2))
PY
)"

markdown_report="$(python3 - <<'PY' "$json_report"
import json
import sys
report = json.loads(sys.argv[1])
summary = report["summary"]
rows = report["runs"]
missing = report["missing"]
print(f"""# Time Estimation Calibration

## Summary

- Generated at: {report['generated_at']}
- Pattern: {report['pattern']}
- Runs seen: {summary['runs_seen']}
- Trusted measured runs: {summary['trusted_measured_runs']}
- Manual timing runs: {summary['manual_timing_runs']}
- Not measured runs: {summary['not_measured_runs']}
- Legacy unknown timing runs: {summary['legacy_unknown_timing_runs']}
- Execution time contract runs: {summary['execution_time_contract_runs']}
- Missing continuation gate: {summary['missing_continuation_gate']}
- Average variance ratio: {summary['average_variance_ratio'] if summary['average_variance_ratio'] is not None else 'not-measured'}
- Overestimated runs: {summary['overestimated_runs']}
- Underestimated runs: {summary['underestimated_runs']}
- Accurate runs: {summary['accurate_runs']}
- Outside tolerance runs: {summary['outside_tolerance_runs']}
- One minute hit runs: {summary['one_minute_hit_runs']}
- One minute miss runs: {summary['one_minute_miss_runs']}
- One minute hit rate: {summary['one_minute_hit_rate'] if summary['one_minute_hit_rate'] is not None else 'not-measured'}
- Recommended next estimate minutes: {summary['recommended_next_estimate_minutes'] if summary['recommended_next_estimate_minutes'] is not None else 'not-measured'}

## Task Type Buckets

| Task Type | Trusted Runs | Recommended Next | <1 Min Hit Rate | <1 Min Hit | <1 Min Miss | Overestimated | Underestimated | Accurate |
|---|---:|---:|---:|---:|---:|---:|---:|---:|
""")
for task_type, bucket in sorted((summary.get('task_type_buckets') or {}).items()):
    recommended = bucket.get('recommended_next_estimate_minutes')
    hit_rate = bucket.get('one_minute_hit_rate')
    print(f"| {task_type} | {bucket.get('runs')} | {recommended if recommended is not None else ''} | {hit_rate if hit_rate is not None else ''} | {bucket.get('one_minute_hit_runs')} | {bucket.get('one_minute_miss_runs')} | {bucket.get('overestimated_runs')} | {bucket.get('underestimated_runs')} | {bucket.get('accurate_runs')} |")
print("""
## Per-Slice Recommendations

| Slice | Task Type | Estimated | Actual | Abs Error | <1 Min | Direction | Recommended Next |
|---|---|---:|---:|---:|---|---|---:|""")
for item in summary.get('per_slice_recommendations') or []:
    print(f"| {item.get('slice')} | {item.get('task_type')} | {item.get('estimated_minutes') if item.get('estimated_minutes') is not None else ''} | {item.get('elapsed_minutes') if item.get('elapsed_minutes') is not None else ''} | {item.get('absolute_error_minutes') if item.get('absolute_error_minutes') is not None else ''} | {str(item.get('within_one_minute')).lower() if item.get('within_one_minute') is not None else ''} | {item.get('direction') or ''} | {item.get('recommended_next_estimate_minutes') if item.get('recommended_next_estimate_minutes') is not None else ''} |")
print(f"""

## Runs

| Run | Source | Task Type | Tier | Decision | Timing Source | Trusted | Estimated | Actual | Abs Error | <1 Min | Variance | Accuracy | Direction | Recommended Next |
|---|---|---|---|---|---|---|---:|---:|---:|---|---:|---|---|---:|""")
for row in rows:
    print(f"| {row['run_id']} | {row.get('source_artifact') or ''} | {row.get('task_type') or ''} | {row.get('tier') or ''} | {row.get('decision') or ''} | {row.get('timing_source') or ''} | {str(row.get('trusted_timing')).lower()} | {row.get('estimated_minutes') if row.get('estimated_minutes') is not None else ''} | {row.get('elapsed_minutes') if row.get('elapsed_minutes') is not None else ''} | {row.get('absolute_error_minutes') if row.get('absolute_error_minutes') is not None else ''} | {str(row.get('within_one_minute')).lower() if row.get('within_one_minute') is not None else ''} | {row.get('variance_ratio') if row.get('variance_ratio') is not None else ''} | {row.get('estimate_accuracy') or ''} | {row.get('direction') or ''} | {row.get('recommended_next_estimate_minutes') if row.get('recommended_next_estimate_minutes') is not None else ''} |")
print("\n## Missing Continuation Gate\n")
if missing:
    for item in missing:
        print(f"- {item}")
else:
    print("- none")
print("\n## Interpretation\n")
print("- Only `timing_source=timestamp` is trusted calibration evidence.")
print("- `manual` elapsed minutes are retained for audit/debug visibility but excluded from variance and next-estimate calculations.")
print("- When continuation gate evidence is absent, `execution-time-contract.json` can be used as trusted timestamp timing evidence.")
print("- `overestimated` means trusted actual elapsed time was lower than the estimate; next estimates should shrink when this repeats.")
print("- `underestimated` means trusted actual elapsed time exceeded the estimate; next estimates should increase when this repeats.")
print("- A task may be outside tolerance and still successful when acceptance was completed quickly.")
PY
)"

if [[ -n "$json_output_file" ]]; then
  mkdir -p "$(dirname "$json_output_file")"
  printf '%s\n' "$json_report" > "$json_output_file"
  echo "calibration_json: $json_output_file"
fi
if [[ -n "$output_file" ]]; then
  mkdir -p "$(dirname "$output_file")"
  printf '%s\n' "$markdown_report" > "$output_file"
  echo "calibration_report: $output_file"
fi

if [[ -z "$output_file" && -z "$json_output_file" ]]; then
  printf '%s\n' "$markdown_report"
fi
