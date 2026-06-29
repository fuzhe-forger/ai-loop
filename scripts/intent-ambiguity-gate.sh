#!/usr/bin/env bash
set -euo pipefail

show_help() {
  cat <<'HELP'
Usage: scripts/intent-ambiguity-gate.sh --text <task-text> [options]

Detect ambiguous, typo-prone, or metaphor-like user task keywords before execution.
When blocked, ask the clarification question instead of choosing a branch silently.

Options:
  --text <text>          User task text, required unless --input is provided
  --input <file>         Read task text from file
  --policy <file>        Policy file, default config/intent-ambiguity-policy.json
  --output <file>        Optional Markdown output path
  --json-output <file>   Optional JSON output path
  -h, --help             Show this help

This script is local-only. It reads local policy and never performs external writes.
HELP
}

text=""
input_file=""
policy_file="config/intent-ambiguity-policy.json"
output_file=""
json_output_file=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --text)
      text="${2:-}"; shift 2 ;;
    --input)
      input_file="${2:-}"; shift 2 ;;
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

if [[ -n "$input_file" ]]; then
  if [[ ! -s "$input_file" ]]; then
    echo "Input file missing or empty: $input_file" >&2
    exit 2
  fi
  text="$(cat "$input_file")"
fi
if [[ -z "$text" ]]; then
  echo "--text or --input is required" >&2
  show_help
  exit 2
fi

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

json_report="$(python3 - <<'PY' "$text" "$policy_file"
import datetime as dt
import json
import sys
from pathlib import Path

text, policy_file = sys.argv[1:]
policy_path = Path(policy_file)
if not policy_path.is_file():
    raise SystemExit(f"Policy not found: {policy_path}")
policy = json.loads(policy_path.read_text(encoding="utf-8"))
text_compact = "".join(text.split())
matches = []
for pair in policy.get("term_pairs") or []:
    ambiguous = pair.get("ambiguous") or ""
    canonical = pair.get("canonical") or ""
    ambiguous_hit = ambiguous and ambiguous in text
    canonical_hit = canonical and canonical in text
    if ambiguous_hit:
        matches.append({
            "id": pair.get("id"),
            "type": "ambiguous_term",
            "canonical": canonical,
            "ambiguous": ambiguous,
            "risk": pair.get("risk") or "medium",
            "clarification_question": pair.get("clarification_question"),
            "detail": f"ambiguous term {ambiguous!r} present",
        })
    elif canonical_hit and ambiguous and len(text_compact) <= int((policy.get("heuristics") or {}).get("short_task_max_chars", 30)):
        matches.append({
            "id": pair.get("id"),
            "type": "short_canonical_term",
            "canonical": canonical,
            "ambiguous": ambiguous,
            "risk": "low",
            "clarification_question": None,
            "detail": f"canonical term {canonical!r} present in short task",
        })
blocking_matches = [item for item in matches if item["type"] == "ambiguous_term" and item.get("risk") in {"medium", "high"}]
questions = [item["clarification_question"] for item in blocking_matches if item.get("clarification_question")]
report = {
    "schema_version": 1,
    "generated_at": dt.datetime.now(dt.timezone.utc).replace(microsecond=0).isoformat().replace("+00:00", "Z"),
    "policy": str(policy_path),
    "text": text,
    "matches": matches,
    "requires_clarification": bool(blocking_matches),
    "clarification_questions": questions,
    "result": "BLOCKED" if blocking_matches else "PASSED",
    "side_effects": [],
    "remote_writes": False,
}
print(json.dumps(report, ensure_ascii=False, indent=2))
PY
)"

markdown_report="$(python3 - <<'PY' "$json_report"
import json
import sys
report = json.loads(sys.argv[1])
print(f"""# Intent Ambiguity Gate

## Summary

- Result: {report['result']}
- Requires clarification: {str(report['requires_clarification']).lower()}
- Policy: {report['policy']}
- Remote writes: false

## Input

{report['text']}

## Matches

| ID | Type | Risk | Canonical | Ambiguous | Detail |
|---|---|---|---|---|---|
""")
for item in report["matches"]:
    detail = str(item.get("detail") or "").replace("|", "-")
    print(f"| {item.get('id')} | {item.get('type')} | {item.get('risk')} | {item.get('canonical')} | {item.get('ambiguous')} | {detail} |")
print("""
## Clarification Questions
""")
if report["clarification_questions"]:
    for question in report["clarification_questions"]:
        print(f"- {question}")
else:
    print("- none")
PY
)"

if [[ -n "$json_output_file" ]]; then
  mkdir -p "$(dirname "$json_output_file")"
  printf '%s\n' "$json_report" > "$json_output_file"
  echo "intent_ambiguity_json: $json_output_file"
fi
if [[ -n "$output_file" ]]; then
  mkdir -p "$(dirname "$output_file")"
  printf '%s\n' "$markdown_report" > "$output_file"
  echo "intent_ambiguity_report: $output_file"
fi
if [[ -z "$json_output_file" && -z "$output_file" ]]; then
  printf '%s\n' "$markdown_report"
fi

result="$(python3 - <<'PY' "$json_report"
import json
import sys
print(json.loads(sys.argv[1])["result"])
PY
)"
if [[ "$result" == "BLOCKED" ]]; then
  exit 1
fi
