# Phase C/D：组织层与项目记忆建设计划

## 目标

Phase C 和 Phase D 同步推进：把司南从“脚本集合”推进为“有组织层边界、有项目记忆质量门禁”的本地治理系统。

- Phase C：把 routing、policy、side-effect gate、review orchestration 从零散脚本整理成稳定组织层。
- Phase D：把经验、决策、踩坑和偏好沉淀为可检查、可查询、可复用的 L2 项目记忆。

## Phase C 组织层模块边界

| 模块 | 职责 | 输入 | 输出 | 当前入口 | 缺口 |
|---|---|---|---|---|---|
| Routing | 判断任务类型、风险、角色和是否需要追问 | issue/task/user prompt/classification | task_type、actor、tier、clarification 状态 | `classify-task.sh`、`route-actor.sh`、`loop-intake-gate.sh` | 路由结果还没有统一 schema，actor 选择未进入所有 preflight |
| Policy | 读取任务类型、时间盒、门禁和状态策略 | `config/gate-policy.json`、`config/timebox-policy.json`、classification | required gates、min score、timebox、stop rule | `gate-policy-check.sh`、`loop-execution-preflight.sh`、`loop-continuation-gate.sh` | policy 分散在多个脚本，缺少统一 policy report |
| Side-effect Gate | 把 Feishu/Multica/Git/deploy/delete 等副作用前置审批 | action、issue、run、approval config | approval-boundary evidence、allow/stop decision | `approval-boundary.sh`、`writeback-gate.sh`、`metadata-writeback.sh` | 写回路径已控，但缺少跨动作统一 side-effect manifest |
| Review Orchestration | 组织 evidence、review packet、strict/state gate 和复核结论 | run evidence、patch、verification | review packet、verdict、next action | `review-packet.sh`、`verify-toolchain.sh`、`evaluate-state.sh` | 尚不做自动 reviewer 裁决；需要稳定 review orchestration contract |

## Intake-to-Writeback 本地路径

```text
user goal / Multica issue
  -> classify-task / route-actor
  -> requirement/design/deliverable gate policy
  -> loop-execution-preflight
  -> local execution + verification
  -> collect-evidence / review-packet / verify-toolchain
  -> approval-boundary / writeback-gate
  -> human approved writeback only
  -> Obsidian generated sync / project memory
```

## Phase D 项目记忆质量规则

项目记忆必须先文件化、结构化、可查询，再考虑自动化增强。

| 规则 | 要求 | 验证 |
|---|---|---|
| Index 完整 | `memory/index.json` 必须是合法 JSON，schema_version=1 | `memory-quality-check.sh` |
| 引用可读 | index 中的 file 必须存在且非空 | `memory-quality-check.sh` |
| 类型明确 | constraints/decisions/pitfalls/cases 等分类字段必须存在 | `memory-quality-check.sh` |
| 标签可检索 | 每条记忆至少 1 个 tag | `memory-quality-check.sh` |
| 复核状态 | 自动提取的经验必须标注需人工复核或 accepted 状态，并通过 helper 流转 | `memory-quality-check.sh`、`memory-review-state.sh` |
| 敏感信息 | 不允许提交 API key、password、token 明文 | `memory-quality-check.sh` |
| 可查询性 | `memory-query.sh` 能按 type/tag/search 找到关键记忆 | `memory-query.sh` |

## 首批执行切片

| Slice | Tasks | 验收 |
|---|---|---|
| C/D-1 | CD-001/CD-003 | 本文档覆盖四个组织层模块和 intake-to-writeback 路径 |
| C/D-2 | CD-005/CD-006/CD-007 | 项目记忆质量策略、脚本和 run 报告可用 |
| C/D-3 | CD-008 | 北极星任务板经验进入 `memory/cases` 并可查询 |
| C/D-4 | CD-002/CD-009 | 能力注册和最终报告收口 |

## 下一轮缺口

### Phase C

- 抽出统一 `organization-policy` schema，聚合 routing、policy、side-effect 和 review contract。
- 让 `loop-execution-preflight` 直接展示 route actor、required gates、side-effect manifest 和 review policy。
- 明确 review orchestration 只给建议，不替代人类最终裁决。

### Phase D

- `extract-experience.sh` 已支持结构化 metadata 和 `--promote-to-memory` dry-run 草稿，`memory-promote-draft.sh` 负责显式验证并在 `--execute` 时写入，`phase-d-closeout.sh` 将提取、promote dry-run、质量校验和复核指引串成一份报告。
- 让 `recommend-memory.sh` 返回稳定 JSON schema，并进入 preflight/review packet。
- 已增加记忆复核状态流转 helper：`draft -> reviewed -> accepted/deprecated`，默认 dry-run，`--execute` 才更新 index。

## 验证命令

```bash
python3 -m json.tool config/phase-cd-tasks.json
python3 -m json.tool config/project-memory-policy.json
bash -n scripts/memory-quality-check.sh
./scripts/memory-quality-check.sh --output /tmp/memory-quality.md --json-output /tmp/memory-quality.json
./scripts/north-star-task-board.sh --run-id <run-id> --tasks config/phase-cd-tasks.json --target-minutes 30
./scripts/verify-toolchain.sh --case FUZ-554 --pattern <run-id> --strict --state-gate
```
