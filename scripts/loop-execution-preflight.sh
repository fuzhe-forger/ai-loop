#!/usr/bin/env bash
set -euo pipefail

show_help() {
  cat <<'HELP'
Usage: scripts/loop-execution-preflight.sh --issue <issue> --task <task.md> --repo <repo> [options]

Create a local execution preflight checklist before coding or writeback.

Options:
  --issue <issue>             Issue identifier, required
  --task <task.md>            Task file, required
  --repo <repo>               Target repo, required
  --run-id <run-id>           Optional run id for evidence references
  --output <file>             Optional markdown output path
  --json-output <file>        Optional JSON output path
  --allow-feishu-write        Mark Feishu writes as allowed for this execution package
  --allow-multica-write       Mark Multica writes as allowed for this execution package
  --allow-obsidian-sync       Mark Obsidian generated sync as allowed; default true due standing approval
  --phase-report <auto|yes|no>
                              Whether this task should create a phase report, default auto
  --operation-log <auto|yes|no>
                              Whether this task should create an operation log, default auto
  --no-phase-report           Shortcut for --phase-report no
  --no-operation-log          Shortcut for --operation-log no
  --task-tier <L0|L1|L2|L3|L4|auto>
                              Task tier for timebox recommendation, default auto
  --task-type <type|auto>     Task type for calibration bucket selection, default auto
  -h, --help                  Show this help

This script is local-only. It writes checklist artifacts only and performs no remote writes.
HELP
}

issue_id=""
task_file=""
repo_path=""
run_id=""
output_file=""
json_output_file=""
allow_feishu_write="false"
allow_multica_write="false"
allow_obsidian_sync="true"
phase_report="auto"
operation_log="auto"
task_tier="auto"
task_type="auto"

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
    --output)
      output_file="${2:-}"; shift 2 ;;
    --json-output)
      json_output_file="${2:-}"; shift 2 ;;
    --allow-feishu-write)
      allow_feishu_write="true"; shift ;;
    --allow-multica-write)
      allow_multica_write="true"; shift ;;
    --allow-obsidian-sync)
      allow_obsidian_sync="true"; shift ;;
    --phase-report)
      phase_report="${2:-}"; shift 2 ;;
    --operation-log)
      operation_log="${2:-}"; shift 2 ;;
    --no-phase-report)
      phase_report="no"; shift ;;
    --no-operation-log)
      operation_log="no"; shift ;;
    --task-tier)
      task_tier="${2:-}"; shift 2 ;;
    --task-type)
      task_type="${2:-}"; shift 2 ;;
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

if [[ ! -s "$task_file" && -n "$run_id" && -s "runs/$run_id/task.md" ]]; then
  task_file="runs/$run_id/task.md"
fi

case "$phase_report" in
  auto|yes|no) ;;
  *) echo "--phase-report must be auto, yes, or no" >&2; exit 2 ;;
esac
case "$operation_log" in
  auto|yes|no) ;;
  *) echo "--operation-log must be auto, yes, or no" >&2; exit 2 ;;
esac
case "$task_tier" in
  L0|L1|L2|L3|L4|auto) ;;
  *) echo "--task-tier must be L0, L1, L2, L3, L4, or auto" >&2; exit 2 ;;
esac
if [[ -z "$task_type" ]]; then
  echo "--task-type must not be empty" >&2
  exit 2
fi

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
intake_report=""
intake_result="FAILED"
intent_report=""
intent_json_report=""
intent_result="SKIPPED"
memory_recommendations_report=""
memory_recommendations_result="SKIPPED"
organization_policy_report=""
organization_policy_json_report=""
organization_policy_result="SKIPPED"
if [[ -n "$output_file" ]]; then
  intake_report="$(dirname "$output_file")/$(basename "$output_file" .md)-intake.md"
  intent_report="$(dirname "$output_file")/$(basename "$output_file" .md)-intent-ambiguity.md"
  intent_json_report="$(dirname "$output_file")/$(basename "$output_file" .md)-intent-ambiguity.json"
  memory_recommendations_report="$(dirname "$output_file")/$(basename "$output_file" .md)-memory-recommendations.json"
  organization_policy_report="$(dirname "$output_file")/organization-policy-report.md"
  organization_policy_json_report="$(dirname "$output_file")/organization-policy-report.json"
else
  intake_report="/tmp/loop-execution-preflight-${issue_id}-intake.md"
  intent_report="/tmp/loop-execution-preflight-${issue_id}-intent-ambiguity.md"
  intent_json_report="/tmp/loop-execution-preflight-${issue_id}-intent-ambiguity.json"
  memory_recommendations_report="/tmp/loop-execution-preflight-${issue_id}-memory-recommendations.json"
  organization_policy_report="/tmp/loop-execution-preflight-${issue_id}-organization-policy-report.md"
  organization_policy_json_report="/tmp/loop-execution-preflight-${issue_id}-organization-policy-report.json"
fi

if "$ROOT_DIR/scripts/loop-intake-gate.sh" --issue "$issue_id" --task "$task_file" --repo "$repo_path" --output "$intake_report" >/tmp/loop-execution-preflight-intake.out 2>/tmp/loop-execution-preflight-intake.err; then
  intake_result="PASSED"
fi

task_text=""
if [[ -f "$task_file" ]]; then
  task_text="$(cat "$task_file")"
fi
if [[ -n "$task_text" ]]; then
  if "$ROOT_DIR/scripts/intent-ambiguity-gate.sh" --input "$task_file" --output "$intent_report" --json-output "$intent_json_report" >/tmp/loop-execution-preflight-intent.out 2>/tmp/loop-execution-preflight-intent.err; then
    intent_result="PASSED"
  else
    intent_result="BLOCKED"
  fi
  if "$ROOT_DIR/scripts/recommend-memory.sh" --query "$task_text" --output "$memory_recommendations_report" --limit 5 >/tmp/loop-execution-preflight-memory.out 2>/tmp/loop-execution-preflight-memory.err; then
    memory_recommendations_result="PASSED"
  else
    memory_recommendations_result="FAILED"
  fi
fi

if [[ -n "$run_id" ]]; then
  if "$ROOT_DIR/scripts/organization-policy-report.sh" --issue "$issue_id" --run-id "$run_id" --output "$organization_policy_report" --json-output "$organization_policy_json_report" >/tmp/loop-execution-preflight-organization-policy.out 2>/tmp/loop-execution-preflight-organization-policy.err; then
    organization_policy_result="PASSED"
  else
    organization_policy_result="FAILED"
  fi
fi

json_report="$(python3 - <<'PY' \
  "$ROOT_DIR" "$issue_id" "$task_file" "$repo_path" "$run_id" "$intake_result" "$intake_report" "$intent_result" "$intent_report" "$intent_json_report" "$memory_recommendations_result" "$memory_recommendations_report" "$organization_policy_result" "$organization_policy_report" "$organization_policy_json_report" "$allow_feishu_write" "$allow_multica_write" "$allow_obsidian_sync" "$phase_report" "$operation_log" "$task_tier" "$task_type" "$task_text"
import datetime as dt
import json
from pathlib import Path
import re
import sys
(
    root_dir,
    issue,
    task_file,
    repo_path,
    run_id,
    intake_result,
    intake_report,
    intent_result,
    intent_report,
    intent_json_report,
    memory_recommendations_result,
    memory_recommendations_report,
    organization_policy_result,
    organization_policy_report,
    organization_policy_json_report,
    allow_feishu,
    allow_multica,
    allow_obsidian,
    phase_report,
    operation_log,
    task_tier,
    task_type_override,
    task_text,
) = sys.argv[1:]
policy_path = Path(root_dir) / "config" / "timebox-policy.json"
timebox_policy = json.loads(policy_path.read_text(encoding="utf-8"))
root_path = Path(root_dir)

def root_relative(path):
    try:
        return str(path.relative_to(root_path))
    except ValueError:
        return str(path)

def output_path(path_text):
    path = Path(path_text)
    return path if path.is_absolute() else root_path / path

def section_text(names):
    escaped = "|".join(re.escape(name) for name in names)
    pattern = re.compile(rf"^##\s+({escaped})\s*$([\s\S]*?)(?=^##\s+|\Z)", re.M)
    match = pattern.search(task_text)
    if not match:
        return ""
    return match.group(2).strip()

def first_lines(text, limit=8):
    lines = [line.strip() for line in text.splitlines() if line.strip()]
    return lines[:limit]

def infer_preflight_task_type(task_text):
    text = task_text.lower()
    if any(marker in text for marker in ["script", "脚本", "toolchain", "preflight", "calibration", "obsidian", "evidence", "golden path", "share-preflight"]):
        return "local_script_patch"
    if any(marker in text for marker in ["doc", "文档", "readme", "报告", "复盘"]):
        return "documentation"
    return "unknown"

goal = first_lines(section_text(["目标", "Goal", "Objective"]), 6)
acceptance = first_lines(section_text(["验收", "Acceptance", "验证", "Verification"]), 8)
boundary = first_lines(section_text(["范围 / 非目标 / 边界", "边界", "约束 / 假设", "安全边界", "Boundary", "Constraint", "Risk", "Side effect", "副作用"]), 10)
allowed_side_effects = ["local_files", "local_verification"]
if allow_obsidian == "true":
    allowed_side_effects.append("obsidian_generated_sync")
if allow_feishu == "true":
    allowed_side_effects.append("feishu_write")
if allow_multica == "true":
    allowed_side_effects.append("multica_write")
forbidden_side_effects = ["git_remote", "deploy_or_production", "tool_install", "codex_global_config", "destructive_filesystem"]
if allow_feishu != "true":
    forbidden_side_effects.append("feishu_write")
if allow_multica != "true":
    forbidden_side_effects.append("multica_write")
if task_tier == "auto":
    auto_policy = timebox_policy.get("auto_tier") or {}
    inferred_tier = auto_policy.get("with_issue_and_run_id", "L2") if issue and run_id else auto_policy.get("fallback", "L1")
else:
    inferred_tier = task_tier
tier_policy = (timebox_policy.get("tiers") or {}).get(inferred_tier) or (timebox_policy.get("tiers") or {}).get(timebox_policy.get("default_tier", "L1"), {})
timebox_minutes = int(tier_policy.get("minimum_continuous_minutes", 30))
anti_idle_floor_minutes = int(tier_policy.get("anti_idle_floor_minutes", tier_policy.get("hard_floor_minutes", 0)))
acceptable_variance_ratio = float(tier_policy.get("acceptable_variance_ratio", 0.5))
stop_rule = tier_policy.get("stop_rule", "continue until verified slice")
preflight_task_type = task_type_override if task_type_override != "auto" else infer_preflight_task_type(task_text)
calibration = {
    "source": "policy_default",
    "path": None,
    "task_type": preflight_task_type,
    "bucket_used": None,
    "recommended_next_estimate_minutes": None,
    "trusted_measured_runs": 0,
    "execution_time_contract_runs": 0,
    "one_minute_hit_rate": None,
    "one_minute_hit_runs": 0,
    "one_minute_miss_runs": 0,
    "sample_quality": "not_calibrated",
}
if run_id:
    calibration_path = Path(root_dir) / "runs" / run_id / "time-estimation-calibration.json"
    if calibration_path.is_file():
        try:
            calibration_data = json.loads(calibration_path.read_text(encoding="utf-8"))
        except json.JSONDecodeError:
            calibration_data = {}
        summary = calibration_data.get("summary") or {}
        buckets = summary.get("task_type_buckets") or {}
        bucket = buckets.get(preflight_task_type) if preflight_task_type != "unknown" else None
        recommended = (bucket or {}).get("recommended_next_estimate_minutes") or summary.get("recommended_next_estimate_minutes")
        if isinstance(recommended, (int, float)) and recommended > 0:
            trusted_runs = int(bucket.get("runs") if bucket and bucket.get("runs") is not None else summary.get("trusted_measured_runs") or 0)
            one_minute_hit_runs = int(bucket.get("one_minute_hit_runs") if bucket and bucket.get("one_minute_hit_runs") is not None else summary.get("one_minute_hit_runs") or 0)
            one_minute_miss_runs = int(bucket.get("one_minute_miss_runs") if bucket and bucket.get("one_minute_miss_runs") is not None else summary.get("one_minute_miss_runs") or 0)
            timebox_minutes = int(round(recommended))
            calibration = {
                "source": "time-estimation-calibration",
                "path": str(calibration_path.relative_to(Path(root_dir))),
                "task_type": preflight_task_type,
                "bucket_used": preflight_task_type if bucket else "all_trusted_samples",
                "recommended_next_estimate_minutes": timebox_minutes,
                "trusted_measured_runs": trusted_runs,
                "execution_time_contract_runs": int(summary.get("execution_time_contract_runs") or 0),
                "one_minute_hit_rate": (bucket or {}).get("one_minute_hit_rate") if bucket else summary.get("one_minute_hit_rate"),
                "one_minute_hit_runs": one_minute_hit_runs,
                "one_minute_miss_runs": one_minute_miss_runs,
                "sample_quality": "ok" if trusted_runs >= 3 else "low_sample",
            }
organization_policy = {
    "source": "missing",
    "path": None,
    "result": "MISSING",
    "remote_write_policy": None,
    "modules": [],
}
if run_id:
    organization_policy_path = output_path(organization_policy_json_report) if organization_policy_json_report else root_path / "runs" / run_id / "organization-policy-report.json"
    if organization_policy_path.is_file():
        try:
            organization_policy_data = json.loads(organization_policy_path.read_text(encoding="utf-8"))
        except json.JSONDecodeError:
            organization_policy_data = {}
        organization_policy = {
            "source": "generated_report" if organization_policy_result == "PASSED" else "existing_report",
            "path": root_relative(organization_policy_path),
            "markdown_path": root_relative(output_path(organization_policy_report)) if organization_policy_report and output_path(organization_policy_report).is_file() else None,
            "result": organization_policy_data.get("result") or "UNKNOWN",
            "preflight_generation_result": organization_policy_result,
            "remote_write_policy": organization_policy_data.get("remote_write_policy"),
            "modules": [
                {
                    "id": module.get("id"),
                    "status": module.get("status"),
                    "available_evidence_count": len(module.get("available_evidence") or []),
                    "missing_evidence_count": len(module.get("missing_evidence") or []),
                }
                for module in organization_policy_data.get("modules") or []
            ],
        }
    else:
        policy_path = root_path / "config" / "organization-policy.json"
        if policy_path.is_file():
            try:
                policy_data = json.loads(policy_path.read_text(encoding="utf-8"))
            except json.JSONDecodeError:
                policy_data = {}
            modules = policy_data.get("modules") or {}
            organization_policy = {
                "source": "policy_config",
                "path": root_relative(policy_path),
                "markdown_path": None,
                "result": "CONFIG_ONLY",
                "preflight_generation_result": organization_policy_result,
                "remote_write_policy": (policy_data.get("result_policy") or {}).get("remote_write_policy"),
                "modules": [
                    {
                        "id": module_id,
                        "status": "CONFIGURED",
                        "available_evidence_count": 0,
                        "missing_evidence_count": len(module.get("entrypoints") or []),
                    }
                    for module_id, module in modules.items()
                ],
            }

memory_recommendations = {
    "result": memory_recommendations_result,
    "report": memory_recommendations_report or None,
    "recommendations": [],
    "suggested_reading": [],
}
if memory_recommendations_report:
    recommendation_path = Path(memory_recommendations_report)
    if recommendation_path.is_file():
        try:
            recommendation_data = json.loads(recommendation_path.read_text(encoding="utf-8"))
        except json.JSONDecodeError:
            recommendation_data = {}
        memory_recommendations["schema_version"] = recommendation_data.get("schema_version")
        memory_recommendations["recommendations"] = recommendation_data.get("recommendations") or []
        memory_recommendations["suggested_reading"] = recommendation_data.get("suggested_reading") or []

report = {
    "schema_version": 1,
    "generated_at": dt.datetime.now(dt.timezone.utc).replace(microsecond=0).isoformat().replace("+00:00", "Z"),
    "issue": issue,
    "task_file": task_file,
    "repo": repo_path,
    "run_id": run_id or None,
    "intake": {"result": intake_result, "report": intake_report},
    "intent_ambiguity": {
        "result": intent_result,
        "report": intent_report or None,
        "json_report": intent_json_report or None,
    },
    "goal": goal,
    "acceptance": acceptance,
    "boundary": boundary,
    "side_effects": {
        "allowed": allowed_side_effects,
        "forbidden_without_separate_approval": forbidden_side_effects,
    },
    "timebox": {
        "tier": inferred_tier,
        "estimated_minutes": timebox_minutes,
        "policy_estimated_minutes": int(tier_policy.get("minimum_continuous_minutes", 30)),
        "calibration": calibration,
        "minimum_continuous_minutes": timebox_minutes,
        "anti_idle_floor_minutes": anti_idle_floor_minutes,
        "acceptable_variance_ratio": acceptable_variance_ratio,
        "stop_rule": stop_rule,
    },
    "phase_report": {
        "policy": phase_report,
        "recommendation": "yes" if phase_report == "yes" else ("no" if phase_report == "no" else "only for mechanism/policy/reusable capability changes"),
    },
    "operation_log": {
        "policy": operation_log,
        "recommendation": "yes" if operation_log == "yes" else ("no" if operation_log == "no" else "only for external writes, batch approvals, or material governance decisions"),
    },
    "writeback_recommendation": {
        "multica_write": "allowed" if allow_multica == "true" else "requires_approval",
        "feishu_write": "allowed" if allow_feishu == "true" else "requires_approval",
        "done_candidate_after_closeout": allow_multica == "true",
    },
    "organization_policy": organization_policy,
    "memory_recommendations": memory_recommendations,
    "organization_contract": {
        "routing": "route-result.v1",
        "policy": "policy-report.v1",
        "side_effect": "side-effect-manifest.v1",
        "review": "review-orchestration.v1",
    },
    "automation_boundary": {
        "auto_execute": False,
        "auto_reviewer": False,
        "auto_writeback_decision": False,
        "auto_remote_side_effect": False,
        "policy": "automation assists classification, planning, experience extraction, and memory recommendation only",
    },
    "result": "PASSED" if intent_result != "BLOCKED" and intake_result == "PASSED" and goal and acceptance and boundary else "FAILED",
}
print(json.dumps(report, ensure_ascii=False, indent=2))
PY
)"

markdown_report="$(python3 - <<'PY' "$json_report"
import json
import sys
report = json.loads(sys.argv[1])
allowed = "\n".join(f"- {item}" for item in report["side_effects"]["allowed"])
forbidden = "\n".join(f"- {item}" for item in report["side_effects"]["forbidden_without_separate_approval"])
goal = "\n".join(f"- {item}" for item in report["goal"]) or "- MISSING"
acceptance = "\n".join(f"- {item}" for item in report["acceptance"]) or "- MISSING"
boundary = "\n".join(f"- {item}" for item in report["boundary"]) or "- MISSING"
modules = report.get("organization_policy", {}).get("modules") or []
organization_modules = "\n".join(
    f"- {module.get('id')}: {module.get('status')} "
    f"(available={module.get('available_evidence_count')}, missing={module.get('missing_evidence_count')})"
    for module in modules
) or "- MISSING"
memory = report.get("memory_recommendations") or {}
memory_rows = "\n".join(
    f"| {item.get('type')} | {item.get('id')} | {item.get('confidence')} | {str(item.get('reason') or '').replace('|', '-')} | {item.get('path') or ''} |"
    for item in (memory.get("recommendations") or [])
) or "| none | none | 0 | no recommendation |  |"
print(f"""# Loop Execution Preflight: {report['issue']}

## Result

- Result: {report['result']}
- Intake gate: {report['intake']['result']}
- Intake report: {report['intake']['report']}
- Intent ambiguity gate: {report['intent_ambiguity']['result']}
- Intent ambiguity report: {report['intent_ambiguity']['report'] or 'not-used'}
- Task: {report['task_file']}
- Repo: {report['repo']}
- Run ID: {report.get('run_id') or 'not-provided'}

## Goal

{goal}

## Acceptance

{acceptance}

## Boundary

{boundary}

## Allowed Side Effects

{allowed}

## Forbidden Without Separate Approval

{forbidden}

## Organization Policy

- Source: {report['organization_policy']['source']}
- Path: {report['organization_policy']['path'] or 'not-used'}
- Markdown path: {report['organization_policy'].get('markdown_path') or 'not-used'}
- Preflight generation: {report['organization_policy'].get('preflight_generation_result') or 'not-run'}
- Result: {report['organization_policy']['result']}
- Remote write policy: {report['organization_policy']['remote_write_policy'] or 'not-configured'}

## Organization Contract

- Routing: {report['organization_contract']['routing']}
- Policy: {report['organization_contract']['policy']}
- Side effect: {report['organization_contract']['side_effect']}
- Review: {report['organization_contract']['review']}

### Organization Modules

{organization_modules}

## Memory Recommendations

- Result: {memory.get('result') or 'SKIPPED'}
- Report: {memory.get('report') or 'not-used'}

| Type | ID | Confidence | Reason | Path |
|---|---|---:|---|---|
{memory_rows}

## Automation Boundary

- Auto execute: {str(report['automation_boundary']['auto_execute']).lower()}
- Auto reviewer: {str(report['automation_boundary']['auto_reviewer']).lower()}
- Auto writeback decision: {str(report['automation_boundary']['auto_writeback_decision']).lower()}
- Auto remote side effect: {str(report['automation_boundary']['auto_remote_side_effect']).lower()}
- Policy: {report['automation_boundary']['policy']}

## Timebox

- Tier: {report['timebox']['tier']}
- Estimated minutes: {report['timebox']['estimated_minutes']}
- Policy estimated minutes: {report['timebox']['policy_estimated_minutes']}
- Calibration source: {report['timebox']['calibration']['source']}
- Calibration evidence: {report['timebox']['calibration']['path'] or 'not-used'}
- Calibration task type: {report['timebox']['calibration']['task_type']}
- Calibration bucket: {report['timebox']['calibration']['bucket_used'] or 'not-used'}
- Trusted measured runs: {report['timebox']['calibration']['trusted_measured_runs']}
- Execution time contract runs: {report['timebox']['calibration']['execution_time_contract_runs']}
- One minute hit rate: {report['timebox']['calibration']['one_minute_hit_rate'] if report['timebox']['calibration']['one_minute_hit_rate'] is not None else 'not-measured'}
- One minute hit runs: {report['timebox']['calibration']['one_minute_hit_runs']}
- One minute miss runs: {report['timebox']['calibration']['one_minute_miss_runs']}
- Calibration sample quality: {report['timebox']['calibration']['sample_quality']}
- Anti-idle floor minutes: {report['timebox']['anti_idle_floor_minutes']}
- Acceptable variance ratio: {report['timebox']['acceptable_variance_ratio']}
- Stop rule: {report['timebox']['stop_rule']}

## Phase Report Policy

- Policy: {report['phase_report']['policy']}
- Recommendation: {report['phase_report']['recommendation']}

## Operation Log Policy

- Policy: {report['operation_log']['policy']}
- Recommendation: {report['operation_log']['recommendation']}

## Writeback Recommendation

- Multica write: {report['writeback_recommendation']['multica_write']}
- Feishu write: {report['writeback_recommendation']['feishu_write']}
- Done candidate after closeout: {str(report['writeback_recommendation']['done_candidate_after_closeout']).lower()}

## Next Step

- If result is `PASSED`, continue to local implementation and verification.
- If result is `FAILED`, fix the task brief before coding or remote writeback.
""")
PY
)"

if [[ -n "$json_output_file" ]]; then
  mkdir -p "$(dirname "$json_output_file")"
  printf '%s\n' "$json_report" > "$json_output_file"
fi

if [[ -n "$output_file" ]]; then
  mkdir -p "$(dirname "$output_file")"
  printf '%s\n' "$markdown_report" > "$output_file"
  echo "execution_preflight: $output_file"
  if [[ -n "$json_output_file" ]]; then
    echo "execution_preflight_json: $json_output_file"
  fi
else
  printf '%s\n' "$markdown_report"
fi

result="$(python3 - <<'PY' "$json_report"
import json, sys
print(json.loads(sys.argv[1]).get("result"))
PY
)"
if [[ "$result" != "PASSED" ]]; then
  exit 1
fi
