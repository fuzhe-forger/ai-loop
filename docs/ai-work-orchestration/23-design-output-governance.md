# Phase H：需求沟通、方案设计与产出把控

## 背景与问题

Phase A-G 已经把 `司南` 的本地闭环跑通：任务可以进入 Loop，执行可以产出 evidence，回写可以经过 policy gate，经验可以沉淀到项目记忆。

当前主要问题不再是“有没有脚本”，而是三个质量风险：

- 需求一开始一片空白时，AI 直接进入方案或开发，导致后续返工和 token 消耗。
- 方案设计可能不够清晰，导致执行时反复返工。
- 产出内容可能有 evidence，但人类阅读层缺少结论、验证、负责人和下一步。

因此 Phase H 的核心目标是把“需求先沟通、方案先评审、产出先验收”变成默认门禁。

## 目标

- 在进入方案设计前，用 `requirement-gate` 检查需求是否具备可沟通、可拆解、可验收的基本结构。
- 在进入执行前，用 `design-gate` 检查方案是否具备可评审、可执行、可验证的基本结构。
- 在交付、handoff 或回写前，用 `deliverable-gate` 检查产出是否具备结论、证据、验证和下一步。
- 让每次失败都能明确是需求缺失、方案缺失、证据缺失、验证缺失，还是回写副作用未说明。
- 保持 human in command：脚本只给质量判断，不替代人类决策。

## 非目标与边界

- 不自动生成最终方案结论。
- 不用脚本替代真实需求沟通。
- 不自动批准 reviewer 结果。
- 不自动执行 Multica、飞书、Git remote 或部署回写。
- 不引入向量搜索、LLM 微调或自动 reviewer。
- 不要求所有历史文档一次性补齐，只要求新任务和关键产出逐步接入。

## 需求沟通门禁

脚本：`scripts/requirement-gate.sh`

需求草稿进入方案设计前，至少需要覆盖以下维度：

| 维度 | 说明 | 常见证据 |
|---|---|---|
| 背景 / 问题 | 为什么要做，现状痛点是什么 | issue、用户描述、线上问题、人工说明 |
| 用户 / 干系人 / 场景 | 谁使用，谁受影响，在什么场景发生 | 用户角色、业务流程、场景样例 |
| 目标 / 期望结果 | 完成后要达到什么结果 | 业务目标、用户收益、技术收益 |
| 范围 / 非目标 / 边界 | 本轮做什么、不做什么 | scope、non-goal、边界说明 |
| 验收 / 成功标准 | 怎样判断需求完成 | DoD、验收口径、关键指标 |
| 约束 / 假设 | 哪些前提限制方案选择 | 时间、权限、兼容性、资源约束 |
| 依赖 / 输入 / 上下游 | 需要哪些系统、数据和角色配合 | API、数据源、上游/下游系统 |
| 风险 / 待确认 | 哪些问题还不能直接决策 | 风险、疑问、阻塞、待确认项 |
| 优先级 / 时间 | 为什么现在做，什么时候要 | deadline、优先级、排期 |
| 副作用 / 外部写入策略 | 是否涉及远端写入、删除、部署 | Multica、飞书、Git remote、生产操作 |

推荐命令：

```bash
./scripts/requirement-gate.sh \
  --input docs/ai-work-orchestration/23-design-output-governance.md \
  --strict
```

严格模式会额外要求需求写明人工沟通或确认记录：

```bash
./scripts/requirement-gate.sh --input <requirement.md> --strict
```

如果门禁失败，下一步不是设计或开发，而是输出澄清问题并回到需求沟通。

可以额外生成给人确认的澄清草稿：

```bash
./scripts/requirement-gate.sh \
  --input <requirement.md> \
  --output <run-or-task>/requirement-gate.md \
  --clarification-output <run-or-task>/clarification.md
```

`clarification.md` 会包含失败原因、需人工确认的问题，以及可直接补写的需求骨架。

当 run 处于 `needs_clarification` 时，`clarification.md` 应进入 run evidence，并出现在 evidence index、evidence checklist、collect-evidence 输出、review packet 和 Obsidian generated run 页面中。state gate 会把缺少 `clarification.md` 的 `needs_clarification` run 判定为 `blocked`。

`clarification.md` 交给人类前应通过质量检查：

```bash
./scripts/clarification-gate.sh \
  --run-id <run-id> \
  --strict \
  --output runs/<run-id>/clarification-gate.md
```

质量检查会确认澄清草稿包含摘要、原因、人工确认问题、至少 5 个具体问题、需求骨架、下一步和副作用可见性。state gate 只会把 `clarification-gate.md` 通过的 `needs_clarification` run 交给人类。

## 方案设计门禁

脚本：`scripts/design-gate.sh`

设计文档进入执行前，至少需要覆盖以下维度：

| 维度 | 说明 | 常见证据 |
|---|---|---|
| 背景 / 问题 | 为什么要做，现状痛点是什么 | PRD、issue、线上问题、人工说明 |
| 目标 / 目的 | 本轮要达成什么 | 验收目标、业务目标、技术目标 |
| 范围 / 边界 / 非目标 | 明确做什么、不做什么 | scope、non-goal、约束 |
| 方案 / 设计 / 架构 | 核心设计和实现路径 | 架构图、模块拆分、接口草案 |
| 依赖 / 影响 / 集成 | 影响哪些系统和角色 | 上下游、数据、接口、权限 |
| 风险 / 回滚 / 降级 | 失败时怎么止损 | rollback、fallback、灰度策略 |
| 验收 / 验证 / 测试 | 怎么证明完成 | 测试命令、验收口径、检查清单 |
| 待决策 / 开放问题 | 哪些问题还不能由 AI 代替决策 | DRI、决策项、阻塞项 |
| 负责人 / 评审人 | 谁负责确认和推进 | Owner、DRI、Reviewer |
| 副作用 / 回写策略 | 是否涉及外部写入和审批 | side effect、writeback、remote policy |

推荐命令：

```bash
./scripts/design-gate.sh \
  --input runs/FUZ-577-b-policy-review-pack/technical-design-draft.md \
  --issue FUZ-577 \
  --output runs/FUZ-577-b-policy-review-pack/design-gate.md
```

严格模式会额外要求方案写明证据来源：

```bash
./scripts/design-gate.sh --input <design.md> --strict
```

## 产出把控门禁

脚本：`scripts/deliverable-gate.sh`

任何准备交给人类复核、同步到 Multica、沉淀到 Obsidian 或作为团队分享材料的产出，至少需要包含：

| 维度 | 最小要求 |
|---|---|
| 目的 / 目标 | 说明这份产出解决什么问题 |
| 结论 / 摘要 / 结果 | 先给 3-5 条人类可读核心结论 |
| 证据 / 产物 / 链接 | 给出本地路径、外部链接或 evidence 文件 |
| 验证 / 测试结果 | 说明验证命令、人工验证或未验证原因 |
| 负责人 / 角色 | 明确 Owner、Actor、Reviewer 或 DRI |
| 下一步 / 后续动作 | 明确下一角色、待办和阻塞 |
| 副作用 / 回写状态 | 明确是否有远端写入、是否已授权、是否待回写 |

推荐命令：

```bash
./scripts/deliverable-gate.sh \
  --input runs/FUZ-577-b-policy-review-pack/stage-report.md \
  --issue FUZ-577 \
  --output runs/FUZ-577-b-policy-review-pack/deliverable-gate.md
```

对于标准 run，可以直接按 run 检查：

```bash
./scripts/deliverable-gate.sh --run-id <run-id> --strict
```

严格模式会要求 run 具备 core evidence：`summary.md`、`stage-report.md`、`multica-comment.md`。


## 任务类型策略门禁

脚本：`scripts/gate-policy-check.sh`

配置：`config/gate-policy.json`

不同任务类型的 required gates 和最低分不同，避免所有任务都用同一套强度：

| 任务类型 | Required gates | 说明 |
|---|---|---|
| `feature` | requirement、design、deliverable | 新功能默认最重，需求和方案必须更清晰 |
| `bug_fix` | requirement、design、deliverable | 修复需要明确复现、影响和验证 |
| `refactor` | requirement、design、deliverable | 重构要求更高的设计分，避免破坏既有行为 |
| `infrastructure` | requirement、design、deliverable | 工具链和平台类任务需要明确副作用边界 |
| `documentation` | requirement、deliverable | 文档类默认不强制 design，但已有 design 会被检查 |
| `test` | requirement、deliverable | 测试类默认不强制 design，但要求交付和验证清晰 |
| `unknown` | requirement、design、deliverable | 未分类任务走保守策略 |

推荐命令：

```bash
./scripts/gate-policy-check.sh \
  --run-id <run-id> \
  --classification runs/<run-id>/classification.json \
  --output runs/<run-id>/gate-policy-check.md \
  --json-output runs/<run-id>/gate-policy-check.json
```

也可以显式覆盖任务类型：

```bash
./scripts/gate-policy-check.sh --run-id <run-id> --task-type documentation
```

策略结果会进入 `collect-evidence` 的 `checks.gate_policy_check` 和 artifacts，并在 `review-packet` 的 `Gate Policy` 列展示。

特殊规则：`clarification-gate` 一旦存在，或 `requirement-gate` 失败，就升级为必检项，防止 `needs_clarification` run 在缺少澄清质量证据时交给人类。


人工例外必须结构化记录：

```bash
./scripts/gate-policy-exception.sh \
  --run-id <run-id> \
  --approved-by <human-name> \
  --reason '<why continue despite failed policy>' \
  --expires <YYYY-MM-DD>
```

例外只解除本地状态机对 gate policy 失败的阻断，不代表批准远端写入。

## 标准流程接入点

Phase H 后，标准流程调整为：

```text
Multica Issue
  -> loop-intake-gate
  -> task.md
  -> classify-task
  -> recommend-memory
  -> requirement-gate
  -> generate-plan
  -> design-gate
  -> ai-loop dry-run / run
  -> collect-evidence
  -> deliverable-gate
  -> gate-policy-check
  -> evaluate-state
  -> metadata-draft
  -> route-actor
  -> review-packet
  -> writeback-gate
  -> human decision
  -> optional remote writeback
  -> obsidian-sync
  -> memory / self-evolution
```

## 决策规则

- `PASSED`：可以进入下一阶段。
- `FAILED`：默认不进入设计、执行、handoff 或回写；如需继续，必须记录人工例外原因。
- `gate-policy-check` 的 `FAILED` 会让非澄清 run 进入 `blocked`，避免低于任务类型阈值的产出直接进入 review。
- `WARN`：不阻断，但需要在复核或复盘时处理。
- 脚本输出只作为 evidence，不替代人类审批。

## 验收标准

Phase H MVP 视为完成，需要满足：

- `scripts/design-gate.sh --help` 可用。
- `scripts/deliverable-gate.sh --help` 可用。
- `scripts/gate-policy-check.sh --help` 可用。
- `scripts/requirement-gate.sh --help` 可用。
- 四个 gate 脚本和策略校验脚本通过 `bash -n`。
- `requirement-gate` 可以检查本文件并通过。
- `design-gate` 可以检查本文件并通过。
- `deliverable-gate` 可以检查 Phase H 阶段报告并通过。
- `verify-toolchain.sh --list-checks` 包含 gate 脚本和 `gate-policy-check`。

## 后续优化

- 把质量评分接入 `review-packet.md`。
- 将 gate 质量评分接入 Obsidian generated run 页面。
- 已将任务类型策略接入 `refresh-run-evidence.sh` 和 `multica-loop.sh` 收尾链路，新增人工例外 evidence 标准，并接入 Obsidian generated run 展示。
- 在 Obsidian 摘要卡里展示 gate 结果。
- 对常见失败项沉淀到项目记忆，反哺下一次 `generate-plan`。
