#!/usr/bin/env bash
set -euo pipefail

show_help() {
  cat <<'HELP'
Usage: scripts/classify-task.sh --issue <issue> [options]

Classify task type, risk level, and complexity using AI or heuristics.

Options:
  --issue <issue>     Issue identifier, required
  --input <file>      Issue JSON file (from multica issue get)
  --output <file>     Write classification to file
  --ai-model <model>  AI model: llama3 | gpt-4 | none (default: none)
  --ai-endpoint <url> AI endpoint URL (default: http://localhost:11434/api/generate)
  -h, --help          Show this help
HELP
}

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

issue_id=""
input_file=""
output_file=""
ai_model="none"
ai_endpoint="http://localhost:11434/api/generate"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --issue)
      issue_id="${2:-}"; shift 2 ;;
    --input)
      input_file="${2:-}"; shift 2 ;;
    --output)
      output_file="${2:-}"; shift 2 ;;
    --ai-model)
      ai_model="${2:-}"; shift 2 ;;
    --ai-endpoint)
      ai_endpoint="${2:-}"; shift 2 ;;
    -h|--help)
      show_help; exit 0 ;;
    *)
      echo "Unknown argument: $1" >&2
      show_help
      exit 2 ;;
  esac
done

if [[ -z "$issue_id" ]]; then
  echo "--issue is required" >&2
  show_help
  exit 2
fi

issue_title=""
issue_description=""
issue_labels=""

if [[ -n "$input_file" && -f "$input_file" ]]; then
  issue_title=$(python3 -c "import json,sys; d=json.load(open('$input_file')); print(d.get('title',''))")
  issue_description=$(python3 -c "import json,sys; d=json.load(open('$input_file')); print(d.get('description',''))")
  issue_labels=$(python3 -c "import json,sys; d=json.load(open('$input_file')); print(','.join([l['name'] for l in d.get('labels',[])]))")
else
  echo "Warning: no --input file, will use heuristics only" >&2
  issue_title="$issue_id"
  issue_description="(no description)"
  issue_labels=""
fi

classify_heuristic() {
  local title="$1"
  local description="$2"
  local labels="$3"
  
  local task_type="unknown"
  local confidence="0.3"
  local reasoning="Heuristic classification based on keywords"
  local risk_level="low"
  local requires_clarification="false"
  local complexity="medium"
  
  # Bug fix
  if echo "$title $description" | grep -iqE "bug|错误|异常|报错|fix"; then
    task_type="bug_fix"
    confidence="0.7"
    reasoning="Contains bug-related keywords"
    risk_level="medium"
  # Feature
  elif echo "$title $description" | grep -iqE "feature|功能|新增|add"; then
    task_type="feature"
    confidence="0.7"
    reasoning="Contains feature-related keywords"
    risk_level="medium"
    complexity="high"
  # Documentation
  elif echo "$title $description" | grep -iqE "doc|文档|说明|readme"; then
    task_type="documentation"
    confidence="0.8"
    reasoning="Contains documentation keywords"
    risk_level="low"
    complexity="low"
  # Refactor
  elif echo "$title $description" | grep -iqE "refactor|重构|优化|cleanup"; then
    task_type="refactor"
    confidence="0.7"
    reasoning="Contains refactor keywords"
    risk_level="medium"
    complexity="medium"
  # Infrastructure
  elif echo "$title $description" | grep -iqE "infra|infrastructure|基础设施|工具|tooling"; then
    task_type="infrastructure"
    confidence="0.7"
    reasoning="Contains infrastructure keywords"
    risk_level="low"
  fi
  
  # Risk level from labels
  if echo "$labels" | grep -iq "高风险\|high-risk"; then
    risk_level="high"
  elif echo "$labels" | grep -iq "低风险\|low-risk"; then
    risk_level="low"
  fi
  
  cat <<JSON
{
  "issue": "$issue_id",
  "task_type": "$task_type",
  "confidence": $confidence,
  "reasoning": "$reasoning",
  "risk_level": "$risk_level",
  "requires_clarification": $requires_clarification,
  "estimated_complexity": "$complexity",
  "classification_method": "heuristic",
  "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
}
JSON
}

classify_with_ai() {
  local model="$1"
  local endpoint="$2"
  local title="$3"
  local description="$4"
  
  local prompt="Classify this task:

Title: $title
Description: $description

Respond in JSON:
{
  \"task_type\": \"bug_fix|feature|documentation|refactor|infrastructure|test\",
  \"confidence\": 0.0-1.0,
  \"reasoning\": \"brief explanation\",
  \"risk_level\": \"low|medium|high\",
  \"requires_clarification\": true|false,
  \"estimated_complexity\": \"low|medium|high\"
}"
  
  if [[ "$model" == "llama3" ]]; then
    # Local Ollama API
    response=$(curl -s "$endpoint" -d "{\"model\":\"$model\",\"prompt\":$(echo "$prompt" | python3 -c 'import json,sys; print(json.dumps(sys.stdin.read()))')}" 2>/dev/null || echo '{"response":"{}"}')
    echo "$response" | python3 -c "import json,sys; d=json.load(sys.stdin); print(d.get('response','{}'))"
  elif [[ "$model" == "gpt-4" ]]; then
    # OpenAI API (requires OPENAI_API_KEY)
    if [[ -z "${OPENAI_API_KEY:-}" ]]; then
      echo "{\"error\":\"OPENAI_API_KEY not set\"}" >&2
      echo "{}"
      return 1
    fi
    curl -s https://api.openai.com/v1/chat/completions \
      -H "Authorization: Bearer $OPENAI_API_KEY" \
      -H "Content-Type: application/json" \
      -d "{\"model\":\"gpt-4\",\"messages\":[{\"role\":\"user\",\"content\":$(echo "$prompt" | python3 -c 'import json,sys; print(json.dumps(sys.stdin.read()))')}]}" \
    | python3 -c "import json,sys; d=json.load(sys.stdin); print(d.get('choices',[{}])[0].get('message',{}).get('content','{}'))" 2>/dev/null || echo "{}"
  else
    echo "{}" >&2
    return 1
  fi
}

if [[ "$ai_model" == "none" ]]; then
  result=$(classify_heuristic "$issue_title" "$issue_description" "$issue_labels")
else
  ai_result=$(classify_with_ai "$ai_model" "$ai_endpoint" "$issue_title" "$issue_description" 2>/dev/null || echo "{}")
  
  if echo "$ai_result" | python3 -c "import json,sys; json.load(sys.stdin)" >/dev/null 2>&1; then
    # AI result valid
    result=$(echo "$ai_result" | python3 -c "import json,sys; d=json.load(sys.stdin); d['issue']='$issue_id'; d['classification_method']='ai:$ai_model'; d['timestamp']='$(date -u +%Y-%m-%dT%H:%M:%SZ)'; print(json.dumps(d,indent=2))")
  else
    # AI failed, fallback to heuristic
    echo "Warning: AI classification failed, using heuristic" >&2
    result=$(classify_heuristic "$issue_title" "$issue_description" "$issue_labels")
  fi
fi

if [[ -n "$output_file" ]]; then
  echo "$result" > "$output_file"
  echo "classification: $output_file"
fi

echo "$result"
