#!/usr/bin/env bash
set -euo pipefail

show_help() {
  cat <<'HELP'
Usage: scripts/requirement-gate.sh --input <requirement.md> [--issue <issue-id>] [--strict] [--output <file>] [--clarification-output <file>]

Check whether a blank-slate or early-stage request is clear enough to enter design.

Required requirement signals:
  - problem / background / context
  - user / stakeholder / scenario
  - goal / expected outcome
  - scope / non-goal / boundary
  - acceptance / success criteria
  - constraints / assumptions
  - dependencies / inputs / upstream-downstream
  - risks / open questions
  - priority / timeline / urgency
  - side-effect / external write policy

Options:
  --input    Requirement markdown file, required
  --issue    Optional issue identifier; when present, the requirement must reference it
  --strict   Also require explicit human confirmation / communication record
  --output   Optional markdown report output
  --clarification-output
             Optional clarification draft output when requirement is incomplete
  -h, --help Show this help

This script is local-only. It does not read Multica and never performs remote writes.
HELP
}

input_file=""
issue_id=""
strict="false"
output_file=""
clarification_output=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --input)
      input_file="${2:-}"; shift 2 ;;
    --issue)
      issue_id="${2:-}"; shift 2 ;;
    --strict)
      strict="true"; shift ;;
    --output)
      output_file="${2:-}"; shift 2 ;;
    --clarification-output)
      clarification_output="${2:-}"; shift 2 ;;
    -h|--help)
      show_help; exit 0 ;;
    *)
      echo "Unknown argument: $1" >&2
      show_help
      exit 2 ;;
  esac
done

if [[ -z "$input_file" ]]; then
  echo "--input is required" >&2
  show_help
  exit 2
fi

rows=""
clarifying_questions=""
required_total=0
required_passed=0
required_failed=0
warning_count=0

add_check() {
  local name="$1"
  local status="$2"
  local detail="$3"
  local question="$4"
  local required="${5:-true}"
  rows+="| ${name} | ${status} | ${detail} |"$'\n'
  if [[ "$required" == "true" && "$status" != "SKIPPED" ]]; then
    required_total=$((required_total + 1))
  fi
  if [[ "$required" == "true" && "$status" == "PASSED" ]]; then
    required_passed=$((required_passed + 1))
  elif [[ "$required" == "true" && "$status" == "FAILED" ]]; then
    required_failed=$((required_failed + 1))
    clarifying_questions+="- ${question}"$'\n'
  elif [[ "$status" == "WARN" ]]; then
    warning_count=$((warning_count + 1))
    clarifying_questions+="- ${question}"$'\n'
  fi
}

check_pattern() {
  local name="$1"
  local pattern="$2"
  local detail="$3"
  local question="$4"
  local required="${5:-true}"
  if [[ -f "$input_file" ]] && rg -qi -- "$pattern" "$input_file"; then
    add_check "$name" "PASSED" "$detail" "$question" "$required"
  else
    if [[ "$required" == "true" ]]; then
      add_check "$name" "FAILED" "missing ${detail}" "$question" "$required"
    else
      add_check "$name" "WARN" "missing ${detail}" "$question" "$required"
    fi
  fi
}

if [[ -f "$input_file" && -s "$input_file" ]]; then
  add_check "Input file" "PASSED" "$input_file" "请提供需求草稿文件。"
else
  add_check "Input file" "FAILED" "$input_file missing or empty" "请先补充需求草稿，不要直接进入方案设计或开发。"
fi

if [[ -n "$issue_id" ]]; then
  if [[ "$issue_id" =~ ^[A-Z]+-[0-9]+$ ]]; then
    add_check "Issue ID format" "PASSED" "$issue_id" "请确认 issue ID。"
  else
    add_check "Issue ID format" "FAILED" "expected format like FUZ-554" "请提供形如 FUZ-554 的 issue ID。"
  fi

  if [[ -f "$input_file" ]] && rg -q --fixed-strings "$issue_id" "$input_file"; then
    add_check "Issue reference" "PASSED" "$issue_id" "请确认需求和 issue 的对应关系。"
  else
    add_check "Issue reference" "FAILED" "requirement must mention $issue_id" "请在需求草稿里显式引用 $issue_id，保证 traceability。"
  fi
else
  add_check "Issue reference" "SKIPPED" "no --issue provided" "请确认是否需要绑定 Multica issue。" "false"
fi

check_pattern "Problem context" "背景|上下文|现状|问题|痛点|Problem|Context|Background|Current state" "problem/background/context" "要解决的具体问题和现状是什么？"
check_pattern "User stakeholder scenario" "用户|角色|干系人|场景|使用方|User|Stakeholder|Scenario|Actor|Persona" "user/stakeholder/scenario" "谁会使用或受影响？典型使用场景是什么？"
check_pattern "Goal outcome" "目标|目的|期望|收益|Outcome|Goal|Objective|Expected" "goal/expected outcome" "这次完成后期望达到什么结果？"
check_pattern "Scope boundary" "范围|边界|非目标|不做|Scope|Boundary|Non-goal|Out of scope" "scope/non-goal/boundary" "本轮做什么、不做什么？"
check_pattern "Acceptance criteria" "验收|成功标准|完成标准|Acceptance|Success criteria|Definition of done|DoD" "acceptance/success criteria" "怎样判断需求已经完成？"
check_pattern "Constraints assumptions" "约束|假设|限制|前提|Constraint|Assumption|Limitation" "constraints/assumptions" "有哪些技术、时间、权限、兼容性或资源约束？"
check_pattern "Dependencies inputs" "依赖|输入|上游|下游|接口|Dependency|Input|Upstream|Downstream|API" "dependencies/inputs/upstream-downstream" "依赖哪些系统、接口、数据或外部角色？"
check_pattern "Risks questions" "风险|待确认|开放问题|疑问|阻塞|Risk|Question|Open issue|Blocker|TBD" "risks/open questions" "目前最大风险和待确认问题是什么？"
check_pattern "Priority timeline" "优先级|截止|排期|时间|紧急|Priority|Timeline|Deadline|Urgency|Schedule" "priority/timeline/urgency" "优先级和期望完成时间是什么？"
check_pattern "Side-effect policy" "副作用|回写|远端|外部|删除|部署|Side effect|Writeback|Remote|External|Delete|Deploy" "side-effect/external write policy" "是否涉及远端写入、删除、部署、飞书/Multica/Git remote 等副作用？"

if [[ "$strict" == "true" ]]; then
  check_pattern "Human communication" "沟通|确认|访谈|纪要|评审|Human|Confirmed|Interview|Meeting|Discussion|Sign-off" "human confirmation/communication record" "需求是否已经和人类 DRI 沟通确认？" "true"
fi

score=0
if [[ "$required_total" -gt 0 ]]; then
  score=$((required_passed * 100 / required_total))
fi

result="PASSED"
next_state="ready_for_design"
if [[ "$required_failed" -gt 0 || "$score" -lt 80 ]]; then
  result="FAILED"
  next_state="needs_clarification"
fi

notes="Requirement is clear enough to enter design-gate."
if [[ "$result" != "PASSED" ]]; then
  notes="Requirement is not clear enough. Do not enter design or development; run clarification first."
fi

if [[ -z "$clarifying_questions" ]]; then
  clarifying_questions="- 暂无阻断性澄清问题。"
fi

report="# Requirement Gate Report

## Result

- Result: ${result}
- Score: ${score}/100
- Next state: ${next_state}
- Input: ${input_file}
- Issue: ${issue_id:-none}
- Strict: ${strict}
- Required checks: ${required_passed}/${required_total}
- Required failures: ${required_failed}
- Warnings: ${warning_count}
- Network access: false
- Remote writes: false

## Checks

| Check | Result | Detail |
|---|---|---|
${rows}
## Clarifying Questions

${clarifying_questions}
## Notes

${notes}
"

clarification_report="# Requirement Clarification Draft

## Summary

- Source requirement: ${input_file}
- Issue: ${issue_id:-none}
- Gate result: ${result}
- Score: ${score}/100
- Next state: ${next_state}
- Network access: false
- Remote writes: false

## Why This Is Needed

The requirement is not clear enough to enter design or development. Please answer the questions below, then update the requirement draft and rerun scripts/requirement-gate.sh.

## Questions For Human Confirmation

${clarifying_questions}
## Suggested Requirement Skeleton

### 1. 背景 / 问题

请说明当前现状、痛点和触发原因。

### 2. 用户 / 干系人 / 场景

请说明谁会使用或受影响，以及典型业务场景。

### 3. 目标 / 期望结果

请说明本轮完成后希望达到的业务或技术结果。

### 4. 范围 / 非目标 / 边界

请说明本轮做什么、不做什么，以及已知边界。

### 5. 验收 / 成功标准

请说明怎样判断需求已经完成。

### 6. 约束 / 假设

请说明时间、权限、兼容性、资源或技术约束。

### 7. 依赖 / 输入 / 上下游

请说明依赖哪些系统、接口、数据或外部角色。

### 8. 风险 / 待确认问题

请列出当前风险、疑问、阻塞和待确认项。

### 9. 优先级 / 时间要求

请说明优先级、截止时间和期望排期。

### 10. 副作用 / 外部写入策略

请说明是否涉及远端写入、删除、部署、飞书/Multica/Git remote 或生产操作。

## Next Step

- Human owner answers the questions above.
- Update the source requirement or create a new requirement draft.
- Rerun: scripts/requirement-gate.sh --input <updated-requirement.md>
"

if [[ -n "$output_file" ]]; then
  mkdir -p "$(dirname "$output_file")"
  printf '%s' "$report" > "$output_file"
  echo "requirement_gate_report: $output_file"
else
  printf '%s' "$report"
fi

if [[ -n "$clarification_output" && "$result" != "PASSED" ]]; then
  mkdir -p "$(dirname "$clarification_output")"
  printf '%s' "$clarification_report" > "$clarification_output"
  echo "clarification_draft: $clarification_output"
elif [[ -n "$clarification_output" && "$result" == "PASSED" ]]; then
  rm -f "$clarification_output"
fi

if [[ "$result" != "PASSED" ]]; then
  exit 1
fi
