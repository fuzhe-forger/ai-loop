#!/usr/bin/env bash
set -euo pipefail

show_help() {
  cat <<'HELP'
Usage: scripts/recommend-memory.sh --query <text> [options]

Recommend relevant memory based on query text.

Options:
  --query <text>        Query text (task description), required
  --memory-dir <dir>    Memory directory (default: memory/)
  --output <file>       Write recommendation to file
  --limit <n>           Max results per category (default: 3)
  --ai-model <model>    AI model: llama3 | gpt-4 | none (default: none)
  -h, --help            Show this help
HELP
}

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

query=""
memory_dir="$ROOT_DIR/memory"
output_file=""
limit=3
ai_model="none"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --query)
      query="${2:-}"; shift 2 ;;
    --memory-dir)
      memory_dir="${2:-}"; shift 2 ;;
    --output)
      output_file="${2:-}"; shift 2 ;;
    --limit)
      limit="${2:-}"; shift 2 ;;
    --ai-model)
      ai_model="${2:-}"; shift 2 ;;
    -h|--help)
      show_help; exit 0 ;;
    *)
      echo "Unknown argument: $1" >&2
      show_help
      exit 2 ;;
  esac
done

if [[ -z "$query" ]]; then
  echo "--query is required" >&2
  show_help
  exit 2
fi

recommend_heuristic() {
  local query="$1"
  local memory_dir="$2"
  local limit="$3"
  
  local constraints=""
  local cases=""
  local pitfalls=""
  
  # Search constraints
  if [[ -f "$memory_dir/architecture-constraints.md" ]]; then
    constraints=$(rg -i "$query" "$memory_dir/architecture-constraints.md" -C 2 | head -$((limit * 10)) || echo "")
  fi
  
  # Search cases
  if [[ -d "$memory_dir/cases" ]]; then
    cases=$(rg -i "$query" "$memory_dir/cases/" -l | head -$limit || echo "")
  fi
  
  # Search pitfalls
  if [[ -d "$memory_dir/pitfalls" ]]; then
    pitfalls=$(rg -i "$query" "$memory_dir/pitfalls/" -l | head -$limit || echo "")
  fi
  
  cat <<JSON
{
  "query": "$query",
  "relevant_constraints": [
$(if [[ -n "$constraints" ]]; then
  python3 <<PY
import json
constraints = """$constraints"""
if constraints:
    print('    {"id": "C001-C004", "relevance": 0.7, "reason": "contains query keywords"}')
PY
else
  echo '    {"id": "none", "relevance": 0.0, "reason": "no match"}'
fi)
  ],
  "relevant_cases": [
$(if [[ -n "$cases" ]]; then
  for case in $cases; do
    basename="$(basename "$case" .md)"
    echo "    {\"file\": \"$case\", \"relevance\": 0.8, \"reason\": \"contains query keywords\"},"
  done | sed '$ s/,$//'
else
  echo '    {"file": "none", "relevance": 0.0, "reason": "no match"}'
fi)
  ],
  "relevant_pitfalls": [
$(if [[ -n "$pitfalls" ]]; then
  for pitfall in $pitfalls; do
    basename="$(basename "$pitfall" .md)"
    echo "    {\"file\": \"$pitfall\", \"relevance\": 0.8, \"reason\": \"contains query keywords\"},"
  done | sed '$ s/,$//'
else
  echo '    {"file": "none", "relevance": 0.0, "reason": "no match"}'
fi)
  ],
  "suggested_reading": [
$(if [[ -n "$constraints" ]]; then
  echo '    "memory/architecture-constraints.md",'
fi
if [[ -n "$cases" ]]; then
  for case in $cases; do
    echo "    \"$case\","
  done
fi | sed '$ s/,$//')
  ],
  "recommendation_method": "heuristic",
  "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
}
JSON
}

if [[ "$ai_model" == "none" ]]; then
  result=$(recommend_heuristic "$query" "$memory_dir" "$limit")
else
  echo "Warning: AI model not implemented yet, using heuristic" >&2
  result=$(recommend_heuristic "$query" "$memory_dir" "$limit")
fi

if [[ -n "$output_file" ]]; then
  echo "$result" > "$output_file"
  echo "recommendation: $output_file"
fi

echo "$result"
