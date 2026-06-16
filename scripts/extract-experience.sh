#!/usr/bin/env bash
set -euo pipefail

show_help() {
  cat <<'HELP'
Usage: scripts/extract-experience.sh --run-id <run-id> [options]

Extract experience draft from run evidence.

Options:
  --run-id <run-id>   Run identifier, required
  --output <file>     Write experience draft to file
  --ai-model <model>  AI model: llama3 | gpt-4 | none (default: none)
  -h, --help          Show this help
HELP
}

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

run_id=""
output_file=""
ai_model="none"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --run-id)
      run_id="${2:-}"; shift 2 ;;
    --output)
      output_file="${2:-}"; shift 2 ;;
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

if [[ -z "$run_id" ]]; then
  echo "--run-id is required" >&2
  show_help
  exit 2
fi

run_dir="$ROOT_DIR/runs/$run_id"
if [[ ! -d "$run_dir" ]]; then
  echo "Run directory not found: $run_dir" >&2
  exit 1
fi

extract_from_evidence() {
  local run_dir="$1"
  
  local problem="(未找到 summary.md)"
  if [[ -f "$run_dir/summary.md" ]]; then
    problem=$(head -20 "$run_dir/summary.md" | tail -10 || echo "(提取失败)")
  fi
  
  local solution="(未找到 stage-report.md)"
  if [[ -f "$run_dir/stage-report.md" ]]; then
    solution=$(head -30 "$run_dir/stage-report.md" | tail -15 || echo "(提取失败)")
  fi
  
  local what_worked=""
  local what_failed=""
  if [[ -f "$run_dir/verification-report.md" ]]; then
    what_worked=$(rg "PASSED" "$run_dir/verification-report.md" | head -5 || echo "")
    what_failed=$(rg "FAILED" "$run_dir/verification-report.md" | head -3 || echo "")
  fi
  
  local patterns="(未找到 patch-summary 或 commit message)"
  if [[ -f "$run_dir/patch-summary.md" ]]; then
    patterns=$(head -20 "$run_dir/patch-summary.md" | tail -10 || echo "(提取失败)")
  fi
  
  cat <<EXPERIENCE
# 经验提取草稿

## 问题

$problem

## 解决方案

$solution

## 经验教训

### 做对了什么

$( if [[ -n "$what_worked" ]]; then
  echo "$what_worked"
else
  echo "(暂无验证通过项)"
fi )

### 踩过的坑

$( if [[ -n "$what_failed" ]]; then
  echo "$what_failed"
else
  echo "(暂无验证失败项)"
fi )

### 可复用模式

$patterns

## 建议补充

请人工复核并补充：

- [ ] 为什么选择这个方案？
- [ ] 有没有其他方案？
- [ ] 下次如何避免踩坑？
- [ ] 这个模式适用于哪些场景？

---

**提取来源**：$run_dir  
**提取方式**：模板  
**提取时间**：$(date -u +%Y-%m-%dT%H:%M:%SZ)  
**需人工复核**：是
EXPERIENCE
}

if [[ "$ai_model" == "none" ]]; then
  result=$(extract_from_evidence "$run_dir")
else
  echo "Warning: AI model not implemented yet, using template" >&2
  result=$(extract_from_evidence "$run_dir")
fi

if [[ -n "$output_file" ]]; then
  echo "$result" > "$output_file"
  echo "experience_draft: $output_file"
fi

echo "$result"
