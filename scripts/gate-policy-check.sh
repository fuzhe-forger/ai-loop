#!/usr/bin/env bash
set -euo pipefail

show_help() {
  cat <<'HELP'
Usage: scripts/gate-policy-check.sh --run-id <run-id> [options]

Check gate reports against task-type policy.

Options:
  --run-id <run-id>          Run directory under runs/, required unless --evidence is used
  --issue <issue-id>         Optional issue identifier for report metadata
  --task-type <type>         Override task type: bug_fix|feature|documentation|refactor|infrastructure|test|unknown
  --classification <file>    Classification JSON from scripts/classify-task.sh
  --evidence <file>          Evidence JSON from scripts/collect-evidence.sh
  --policy <file>            Policy JSON, default config/gate-policy.json
  --output <file>            Optional Markdown report output
  --json-output <file>       Optional JSON report output
  -h, --help                 Show this help

This script is local-only. It reads policy/evidence files and never performs remote writes.
HELP
}

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
run_id=""
issue_id=""
task_type=""
classification_file=""
evidence_file=""
policy_file="$ROOT_DIR/config/gate-policy.json"
output_file=""
json_output_file=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --run-id)
      run_id="${2:-}"; shift 2 ;;
    --issue)
      issue_id="${2:-}"; shift 2 ;;
    --task-type)
      task_type="${2:-}"; shift 2 ;;
    --classification)
      classification_file="${2:-}"; shift 2 ;;
    --evidence)
      evidence_file="${2:-}"; shift 2 ;;
    --policy)
      policy_file="${2:-}"; shift 2 ;;
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

if [[ -z "$run_id" && -z "$evidence_file" ]]; then
  echo "--run-id is required unless --evidence is provided" >&2
  show_help
  exit 2
fi

if [[ ! -s "$policy_file" ]]; then
  echo "Policy file is missing or empty: $policy_file" >&2
  exit 1
fi

if [[ -n "$classification_file" && ! -s "$classification_file" ]]; then
  echo "Classification file is missing or empty: $classification_file" >&2
  exit 1
fi

if [[ -n "$evidence_file" && ! -s "$evidence_file" ]]; then
  echo "Evidence file is missing or empty: $evidence_file" >&2
  exit 1
fi

if [[ -n "$run_id" && ! -d "$ROOT_DIR/runs/$run_id" ]]; then
  echo "Run directory not found: runs/$run_id" >&2
  exit 1
fi

json_report="$(python3 - <<'PY' \
  "$ROOT_DIR" "$policy_file" "$run_id" "$issue_id" "$task_type" "$classification_file" "$evidence_file"
import json
import re
import sys
from pathlib import Path

root_dir, policy_file, run_id_arg, issue_arg, task_type_arg, classification_file, evidence_file = sys.argv[1:]
root = Path(root_dir)
policy_path = Path(policy_file)
policy = json.loads(policy_path.read_text(encoding="utf-8"))

classification = {}
if classification_file:
    classification = json.loads(Path(classification_file).read_text(encoding="utf-8"))

evidence = {}
if evidence_file:
    evidence = json.loads(Path(evidence_file).read_text(encoding="utf-8"))

run_id = run_id_arg or evidence.get("run_id") or "unknown"
issue = issue_arg or evidence.get("issue") or classification.get("issue") or "none"
run_dir_value = evidence.get("run_dir") or (f"runs/{run_id}" if run_id != "unknown" else "")
run_dir = root / run_dir_value if run_dir_value and not Path(run_dir_value).is_absolute() else Path(run_dir_value)

policy_task_types = policy.get("task_types", {})
default_task_type = policy.get("default_task_type", "unknown")
raw_task_type = task_type_arg or classification.get("task_type") or default_task_type
resolved_task_type = raw_task_type if raw_task_type in policy_task_types else default_task_type
policy_entry = policy_task_types.get(resolved_task_type, policy_task_types.get(default_task_type, {}))
required_gates = list(policy_entry.get("required_gates", []))
optional_gates = list(policy_entry.get("optional_gates", []))
minimum_scores = policy_entry.get("minimum_scores", {})
clarification_policy = policy.get("clarification_policy", {})

GATE_FILES = {
    "requirement": "requirement-gate.md",
    "design": "design-gate.md",
    "clarification": "clarification-gate.md",
    "deliverable": "deliverable-gate.md",
}

def parse_gate_report(path: Path) -> dict:
    data = {
        "path": str(path.relative_to(root) if path.is_absolute() and root in path.parents else path),
        "present": path.is_file() and path.stat().st_size > 0,
        "result": "MISSING",
        "score": None,
        "required_failures": None,
    }
    if not data["present"]:
        return data
    text = path.read_text(encoding="utf-8", errors="replace")
    for line in text.splitlines():
        stripped = line.strip()
        if stripped.startswith("- Result:"):
            data["result"] = stripped.split(":", 1)[1].strip()
        elif stripped.startswith("- Score:"):
            raw = stripped.split(":", 1)[1].strip().split("/", 1)[0]
            try:
                data["score"] = int(raw)
            except ValueError:
                data["score"] = None
        elif stripped.startswith("- Required failures:"):
            raw = stripped.split(":", 1)[1].strip()
            try:
                data["required_failures"] = int(raw)
            except ValueError:
                data["required_failures"] = None
    return data

def evidence_gate_result(name: str) -> dict | None:
    gate_results = evidence.get("checks", {}).get("gate_results", {})
    item = gate_results.get(name)
    if not isinstance(item, dict):
        return None
    return {
        "path": item.get("path") or str(run_dir / GATE_FILES[name]),
        "present": bool(item.get("present")),
        "result": item.get("result") or ("MISSING" if not item.get("present") else "UNKNOWN"),
        "score": item.get("score"),
        "required_failures": item.get("required_failures"),
    }

gate_results = {}
for gate_name, gate_file in GATE_FILES.items():
    from_evidence = evidence_gate_result(gate_name)
    if from_evidence is not None:
        gate_results[gate_name] = from_evidence
    else:
        gate_results[gate_name] = parse_gate_report(run_dir / gate_file)

if clarification_policy.get("required_when_present", True) and gate_results["clarification"].get("present"):
    if "clarification" not in required_gates:
        required_gates.append("clarification")
    if "clarification" in optional_gates:
        optional_gates.remove("clarification")

if clarification_policy.get("required_when_requirement_failed", True):
    requirement = gate_results["requirement"]
    requirement_failed = requirement.get("present") and requirement.get("result") == "FAILED"
    if requirement_failed and "clarification" not in required_gates:
        required_gates.append("clarification")
        if "clarification" in optional_gates:
            optional_gates.remove("clarification")

rows = []
failures = []
warnings = []
for gate_name in GATE_FILES:
    gate = gate_results[gate_name]
    required = gate_name in required_gates
    optional = gate_name in optional_gates
    minimum = minimum_scores.get(gate_name)
    if gate_name == "clarification" and minimum is None:
        minimum = clarification_policy.get("minimum_score_default")
    status = "SKIPPED"
    reason = "not required by policy"
    if required:
        status = "PASSED"
        reason = "required gate passed policy"
        if not gate.get("present"):
            status = "FAILED"
            reason = "required gate report is missing"
        elif gate.get("result") != "PASSED":
            status = "FAILED"
            reason = f"required gate result is {gate.get('result')}"
        elif minimum is not None and (gate.get("score") is None or gate.get("score") < int(minimum)):
            status = "FAILED"
            reason = f"score {gate.get('score')} is below minimum {minimum}"
    elif optional:
        if not gate.get("present"):
            status = "OPTIONAL"
            reason = "optional gate report is absent"
        elif gate.get("result") != "PASSED":
            status = "WARN"
            reason = f"optional gate result is {gate.get('result')}"
        elif minimum is not None and gate.get("score") is not None and gate.get("score") < int(minimum):
            status = "WARN"
            reason = f"optional gate score {gate.get('score')} is below recommended {minimum}"
        else:
            status = "PASSED"
            reason = "optional gate passed"
    row = {
        "gate": gate_name,
        "policy_required": required,
        "policy_optional": optional,
        "minimum_score": minimum,
        "present": gate.get("present"),
        "result": gate.get("result"),
        "score": gate.get("score"),
        "required_failures": gate.get("required_failures"),
        "status": status,
        "reason": reason,
        "path": gate.get("path"),
    }
    rows.append(row)
    if status == "FAILED":
        failures.append(f"{gate_name}: {reason}")
    elif status == "WARN":
        warnings.append(f"{gate_name}: {reason}")

result = "PASSED" if not failures else "FAILED"
report = {
    "schema_version": 1,
    "contract": "policy-report.v1",
    "issue": issue,
    "run_id": run_id,
    "task_type": resolved_task_type,
    "raw_task_type": raw_task_type,
    "task_type_source": "override" if task_type_arg else ("classification" if classification else "default"),
    "classification": {
        "path": classification_file or None,
        "confidence": classification.get("confidence"),
        "risk_level": classification.get("risk_level"),
        "estimated_complexity": classification.get("estimated_complexity"),
    },
    "policy": {
        "path": str(policy_path.relative_to(root) if policy_path.is_absolute() and root in policy_path.parents else policy_path),
        "description": policy_entry.get("description", ""),
        "required_gates": required_gates,
        "optional_gates": optional_gates,
        "minimum_scores": minimum_scores,
    },
    "result": result,
    "decision": "allow" if result == "PASSED" else "block",
    "failures": failures,
    "warnings": warnings,
    "checks": rows,
    "side_effects": {
        "network_access": False,
        "remote_writes": False,
    },
}
print(json.dumps(report, ensure_ascii=False, indent=2))
PY
)"

markdown_report="$(python3 - <<'PY' "$json_report"
import json
import sys

data = json.loads(sys.argv[1])
lines = [
    "# Gate Policy Check Report",
    "",
    "## Result",
    "",
    f"- Result: {data['result']}",
    f"- Decision: {data['decision']}",
    f"- Issue: {data['issue']}",
    f"- Run ID: {data['run_id']}",
    f"- Task type: {data['task_type']}",
    f"- Task type source: {data['task_type_source']}",
    f"- Policy: {data['policy']['path']}",
    "- Network access: false",
    "- Remote writes: false",
    "",
    "## Policy",
    "",
    f"- Description: {data['policy']['description']}",
    f"- Required gates: {', '.join(data['policy']['required_gates']) or 'none'}",
    f"- Optional gates: {', '.join(data['policy']['optional_gates']) or 'none'}",
    "",
    "## Checks",
    "",
    "| Gate | Policy | Minimum | Present | Gate Result | Score | Policy Result | Reason | Path |",
    "|---|---|---|---|---|---|---|---|---|",
]
for row in data["checks"]:
    if row["policy_required"]:
        policy_state = "required"
    elif row["policy_optional"]:
        policy_state = "optional"
    else:
        policy_state = "not required"
    minimum = row["minimum_score"] if row["minimum_score"] is not None else "none"
    score = row["score"] if row["score"] is not None else "UNKNOWN"
    lines.append(
        f"| {row['gate']} | {policy_state} | {minimum} | {str(row['present']).lower()} | "
        f"{row['result']} | {score} | {row['status']} | {row['reason']} | {row['path']} |"
    )
lines.extend(["", "## Failures", ""])
if data["failures"]:
    lines.extend(f"- {item}" for item in data["failures"])
else:
    lines.append("- none")
lines.extend(["", "## Warnings", ""])
if data["warnings"]:
    lines.extend(f"- {item}" for item in data["warnings"])
else:
    lines.append("- none")
print("\n".join(lines) + "\n")
PY
)"

if [[ -n "$json_output_file" ]]; then
  mkdir -p "$(dirname "$json_output_file")"
  printf '%s\n' "$json_report" > "$json_output_file"
  echo "gate_policy_json: $json_output_file"
fi

if [[ -n "$output_file" ]]; then
  mkdir -p "$(dirname "$output_file")"
  printf '%s' "$markdown_report" > "$output_file"
  echo "gate_policy_report: $output_file"
else
  printf '%s' "$markdown_report"
fi

result="$(python3 - <<'PY' "$json_report"
import json, sys
print(json.loads(sys.argv[1]).get("result"))
PY
)"

if [[ "$result" != "PASSED" ]]; then
  exit 1
fi
