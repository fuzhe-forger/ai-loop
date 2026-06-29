# North Star：AI 工作编排的终极效果

## 一句话终局

把 AI 从“单次对话里的编码助手”升级成“可治理、可审计、可复盘、可持续进化的工程团队操作系统”。

人仍然定义目标、边界和验收；AI 负责拆解、执行、举证、复核、沉淀经验；系统负责把每一步变成可追踪事实。

## 2026-06 重定向：近期北极星

短期不追求“更多自动化”，先追求“每次任务更可验收、更准时、更少返工”。司南近期北极星改为：

```text
用户给出目标后，系统能在本地连续执行到可验收结果；
每一步都有证据，每个副作用都有人控，每轮估时和实际耗时误差逐步收敛到 1 分钟内。
```

近期主轴：

- **可验收结果优先**：任务结束必须能指向明确产物、验证命令和 evidence，不用“我做了很多”替代验收。
- **可信时间优先**：开工必须估时，收工必须记录真实耗时、绝对误差、`within_one_minute` 和下一轮校准建议。
- **人控副作用优先**：飞书、Multica、远端 Git、部署、全局配置仍先过 approval boundary；Obsidian `99-generated/` 可按常驻授权同步。
- **小切片快闭环**：复杂目标拆成可验证切片，切片完成后继续推进，直到可验收、触发审批边界或明确无下一步。
- **产出把控优先于功能堆叠**：方案设计、证据完整性、复核包、时间校准和知识沉淀优先级高于新增自动 reviewer 或自动回写。

近期成功标准：

| 指标 | 目标 | 证据 |
|---|---|---|
| 可验收完成 | 每轮最终总结能列出产物、验证和副作用 | `verification-report.md`、`evidence-summary.json` |
| 时间误差收敛 | 同类小切片逐步出现 `<1 分钟` 命中 | `execution-time-contract*.json`、`time-estimation-calibration.json` |
| 副作用可控 | 外部写入前必须有审批边界或常驻授权说明 | `approval-boundary*.md/json`、`writeback-summary.json` |
| 知识可复查 | Obsidian generated 可读到 run、能力、校准和证据 | `99-generated/loop/**` |
| token 不空转 | 中间进展短、证据结构化、重复汇报减少 | Caveman/Cavecrew skill、share/preflight 摘要 |

近期不做：

- 不做自动 reviewer 的最终裁决。
- 不做自动远端回写决策。
- 不为“跑满时间”继续执行无验收价值的动作。
- 不把 phase report / operation log 当成果堆叠。
- 不牺牲审批清晰度来压缩输出。

## 最终演示应该长什么样

理想状态下，技术分享现场只需要演示一条真实 issue：

```text
1. 在 Multica 创建一个需求或 bug
2. 系统判断任务类型、风险和是否需要追问
3. 自动生成本地 task.md 和执行计划
4. ai-loop 在本地隔离环境执行
5. 自动收集 evidence：summary / patch / test / review packet / strict gate / state gate
6. reviewer 智能体基于 evidence 给出 approve 或 request changes
7. 系统生成 Multica comment draft 和 status 建议
8. 人确认后才写回远端
9. 经验进入项目记忆，下一个 issue 自动复用
```

演示的重点不是“AI 一次成功写完代码”，而是：

- 每个动作有来源。
- 每个结论有证据。
- 每个副作用有人控。
- 每次失败都能成为下一轮输入。
- 团队能复盘、复制、扩展这套工作方式。

## 最终系统分层

```text
Multica：任务事实源
  issue / status / comment / assignee / project

Multica Loop：组织与治理层
  task routing / memory / policy / side-effect gate / review orchestration

ai-loop：本地执行事实源
  task.md / run / worktree / patch / verify / evidence / summary

Agent Network：能力角色层
  黑墙调度 / 顾实执行 / 裴衡审查 / 测真验收 / 简辞表达

Artifacts & Memory：知识沉淀层
  evidence / decisions / failures / playbooks / project memory
```

## 终极能力清单

### 1. 任务进入系统

- Multica issue 自动转成本地 work item。
- 模糊任务先追问，不直接执行。
- 风险和副作用先分类。
- 可执行任务生成 task.md、验收标准和验证命令。

### 2. 智能编排

- 根据任务类型自动选择角色：规划、开发、审查、测试、文档。
- 支持并行子任务和同步屏障。
- 支持循环保护：执行/审查超过阈值自动升级。
- 支持 blocked 原因结构化记录。

### 3. 确定性执行

- 所有代码改动走本地 worktree。
- 所有结果必须有 verify 命令或人工复核证据。
- patch summary 和 scope check 阻止越界改动。
- strict gate 阻止 core evidence 不完整的回写，state gate 阻止状态和 metadata evidence 缺失的复核。

### 4. 结构化证据

- 每个 run 产出 evidence.json / evidence.md。
- 证据覆盖 summary、stage report、comment draft、patch summary、review packet、verification report。
- 证据可被 reviewer、Multica comment 和技术分享复用。

### 5. 人控回写

- comment 可以自动生成草稿，但写回需要策略或人工确认。
- status 默认不自动 done。
- 所有远端副作用必须有 side-effect list。
- 写回后生成 writeback summary。

### 6. 长期记忆

- L1：issue metadata，记录当前任务状态。
- L2：项目记忆，记录决策、踩坑、约束。
- L3：全局经验，记录 agent 能力、方案模板、知识图谱。
- 记忆必须有来源、时间、有效性和过期机制。

## 技术分享的核心观点

这不是“又做了一个 AI 工具”，而是建立一套新的工程控制结构：

| 旧模式 | 新模式 |
|---|---|
| 聊天窗口里问 AI | 任务系统驱动 AI 工作 |
| AI 说完成 | evidence 证明完成 |
| 人肉复盘聊天记录 | artifacts 可审计复盘 |
| 单 agent 黑盒执行 | 多角色分工与门禁 |
| 状态靠感觉更新 | policy + evidence + 人控回写 |
| 经验散在对话里 | 项目记忆持续积累 |

## 北极星指标

不是看“自动化率”一个指标，而看治理能力是否提升：

- 一个 issue 从进入到复核，是否全程有 evidence。
- 人是否能在任意节点接管。
- 失败是否能定位到阶段和原因。
- 同类任务第二次是否更快、更稳。
- 回写远端前是否能明确副作用。
- 团队成员是否能只读 artifacts 复盘全过程。

## 路线图

### Phase I：可验收结果与时间校准

目标：把司南从“有治理链路”推进到“每轮都能按可验收结果和可信耗时收口”。

当前优先级：

1. 把 `execution-time-contract` 的绝对误差、`within_one_minute` 和校准命中率纳入所有 run evidence。
2. 让 `loop-execution-preflight` 优先读取任务类型桶，给出更贴近实际的小切片估时。
3. 让 `share-preflight`、`review-packet`、Obsidian run 页直接展示时间契约和 `<1 分钟` 命中状态。
4. 把“可验收结果优先”写进连续执行指南：不到可验收不早停，到可验收不硬凑时间。
5. 对外部副作用保持人控，不把写回自动化作为近期优化目标。

Phase I 完成标志：一次真实 Loop 可以同时证明：结果可验收、证据可复查、副作用可解释、耗时可校准、下一轮估时更准。

### Phase A：可审计单任务闭环

目标：单个 issue 可以安全进入本地 ai-loop，并生成完整证据。

已基本完成：FUZ-554 证明了 task、run、evidence、review packet、strict gate、state gate、share preflight 的链路。

### Phase B：结构化 evidence 标准

目标：所有执行结果都能统一收集为 evidence.json / evidence.md。

当前切入点：`collect-evidence.sh`。

### Phase C：Multica Loop 组织层

目标：把 issue routing、policy、side-effect gate、review orchestration 从脚本中抽成稳定模块。

不做大而全平台，先做本地文件协议和明确状态机。

### Phase D：项目记忆

目标：把“天道/黑墙经验”和每次执行复盘沉淀成 L2 项目记忆。

先文件化，再考虑 KV/数据库。

### Phase E：受控回写与多角色协作

目标：comment/status/writeback 全部走 policy gate；执行、审查、测试分角色协作。

默认仍然 human in command。

### Phase F：团队分享与复制

目标：把这套实践整理成可演示、可培训、可复制的团队方法。

输出：演讲大纲、案例包、演示脚本、最佳实践模板。

### Phase G：自动化增强

目标：在治理基础上补齐任务分类、计划生成、经验提取和记忆推荐。

当前状态：已完成脚本 MVP；AI 输出仍然只作为建议，不替代 reviewer 和人类回写决策。

### Phase H：需求沟通、方案设计与产出把控

目标：把“需求先沟通、方案先评审、产出先验收”设为默认门禁，避免需求空白时直接设计/开发、执行前方案不清、交付后结论不明。

当前切入点：`requirement-gate.sh`、`design-gate.sh`、`deliverable-gate.sh`、`gate-policy-check.sh` 和 `config/gate-policy.json`。

## 当前最重要的取舍

- 先治理，后自动化。
- 先 evidence，后智能调度。
- 先单仓库，后跨仓库。
- 先文件协议，后服务化。
- 先人控回写，后策略自动化。
- 先需求澄清，后方案质量。
- 先方案质量，后执行速度。
- 先产出把控，后规模复制。

## 下一步

围绕北极星，下一步重点不再是继续堆自动化，而是补齐需求沟通、方案设计和产出把控：

1. 需求门禁：设计前检查背景、用户、目标、边界、验收、约束、依赖、风险、时间和副作用。
2. 设计门禁：执行前检查背景、目标、边界、方案、依赖、风险、验证、决策和副作用。
3. 产出门禁：交付前检查目的、结论、证据、验证、负责人、下一步和回写状态。
4. 质量闭环：把 gate 结果进入 review packet、Obsidian 摘要和项目记忆。
