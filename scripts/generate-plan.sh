#!/usr/bin/env bash
set -euo pipefail

show_help() {
  cat <<'HELP'
Usage: scripts/generate-plan.sh --issue <issue> [options]

Generate execution plan draft based on task description and project memory.

Options:
  --issue <issue>       Issue identifier, required
  --input <file>        Issue JSON file (from multica issue get)
  --output <file>       Write plan draft to file
  --memory-dir <dir>    Memory directory (default: memory/)
  --ai-model <model>    AI model: llama3 | gpt-4 | none (default: none)
  -h, --help            Show this help
HELP
}

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

issue_id=""
input_file=""
output_file=""
memory_dir="$ROOT_DIR/memory"
ai_model="none"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --issue)
      issue_id="${2:-}"; shift 2 ;;
    --input)
      input_file="${2:-}"; shift 2 ;;
    --output)
      output_file="${2:-}"; shift 2 ;;
    --memory-dir)
      memory_dir="${2:-}"; shift 2 ;;
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

if [[ -z "$issue_id" ]]; then
  echo "--issue is required" >&2
  show_help
  exit 2
fi

issue_title=""
issue_description=""

if [[ -n "$input_file" && -f "$input_file" ]]; then
  issue_title=$(python3 -c "import json,sys; d=json.load(open('$input_file')); print(d.get('title',''))")
  issue_description=$(python3 -c "import json,sys; d=json.load(open('$input_file')); print(d.get('description',''))")
else
  echo "Warning: no --input file, will use template only" >&2
  issue_title="$issue_id"
  issue_description="(no description)"
fi

# Query memory for relevant context
relevant_constraints=""
if [[ -d "$memory_dir" && -f "$memory_dir/architecture-constraints.md" ]]; then
  relevant_constraints=$(head -50 "$memory_dir/architecture-constraints.md" | tail -30 || echo "")
fi

relevant_preferences=""
if [[ -d "$memory_dir" && -f "$memory_dir/review-preferences.md" ]]; then
  relevant_preferences=$(head -30 "$memory_dir/review-preferences.md" | tail -15 || echo "")
fi

# Search for similar cases
similar_cases=""
if [[ -d "$memory_dir/cases" ]]; then
  similar_cases=$(find "$memory_dir/cases" -name "*.md" -type f | head -3 || echo "")
fi

generate_template_plan() {
  local issue="$1"
  local title="$2"
  local description="$3"
  
  cat <<PLAN
# $issue 执行计划草稿

## 任务描述

**标题**：$title

**描述**：
$description

## 分析

根据任务描述，这是一个 [待分类] 任务。

### 参考案例

$( if [[ -n "$similar_cases" ]]; then
  for case in $similar_cases; do
    echo "- $(basename "$case")"
  done
else
  echo "(暂无相似案例)"
fi )

## 建议步骤

### 步骤 1: 理解需求

- 理由：明确任务目标和范围
- 风险：需求理解偏差

### 步骤 2: 本地验证

- 理由：先在本地环境验证可行性
- 风险：本地和远端环境差异

### 步骤 3: 生成 Evidence

- 理由：必须有完整证据链
- 风险：evidence 不完整导致门禁失败

### 步骤 4: 人工复核

- 理由：确认改动符合预期
- 风险：遗漏边界情况

## 需要注意

### 架构约束

$( if [[ -n "$relevant_constraints" ]]; then
  echo "$relevant_constraints"
else
  echo "(暂无相关约束)"
fi )

### 验收偏好

$( if [[ -n "$relevant_preferences" ]]; then
  echo "$relevant_preferences"
else
  echo "(暂无验收偏好)"
fi )

### 已知坑

(查询项目记忆中的 pitfalls/)

## 人工确认

请复核以下内容：

- [ ] 步骤是否完整
- [ ] 风险是否可控
- [ ] 是否遗漏架构约束
- [ ] 是否考虑验收偏好
- [ ] 是否参考了相似案例

---

**生成方式**：模板  
**生成时间**：$(date -u +%Y-%m-%dT%H:%M:%SZ)  
**需人工复核**：是
PLAN
}

if [[ "$ai_model" == "none" ]]; then
  result=$(generate_template_plan "$issue_id" "$issue_title" "$issue_description")
else
  echo "Warning: AI model not implemented yet, using template" >&2
  result=$(generate_template_plan "$issue_id" "$issue_title" "$issue_description")
fi

if [[ -n "$output_file" ]]; then
  echo "$result" > "$output_file"
  echo "plan_draft: $output_file"
fi

echo "$result"
