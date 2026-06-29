# 司南 v1.0 产品说明与使用手册

## 1. 一句话介绍

司南是一个本地优先的 AI 需求交付治理系统。它不是单一脚本，也不是让 AI 自动替人决策，而是把任务从目标输入、需求澄清、方案设计、本地执行、证据收集、时间校准、受控写回到复盘沉淀，串成可治理、可审计、可复用的工作流。

## 2. v1.0 定位

v1.0 的发布口径是“本地治理能力可验收”。它证明司南已经可以稳定支撑一类 AI 辅助需求交付流程，但不代表全自动产品化，也不代表可以跳过人类验收。

| 维度 | v1.0 说明 |
|---|---|
| 产品形态 | 本地 CLI、Markdown 协议、飞书/Multica/Obsidian 写回、能力注册表组成的工作台 |
| 主要价值 | 降低长任务失控、上下文污染、证据缺失、写回越界、估时失真 |
| 使用对象 | 研发、技术负责人、AI agent 使用者、需要可复盘交付过程的人 |
| 当前状态 | `v1.0.0 released`，本地治理能力发布，不包含代码部署 |
| 事实源 | `config/sinan-version.json`、`runs/v1.0-final/acceptance-report.md` |

## 3. 适合解决什么问题

### 3.1 长任务执行失控

传统长会话容易出现目标漂移、上下文污染、重复消耗 token、执行中途停下。司南要求任务拆成可验收切片，每个切片有估时、执行、验证、证据和收口。

### 3.2 AI 写了代码但没人看得懂

司南要求产出 evidence、review packet、patch summary、设计/交付门禁，让人可以复核“改了什么、为什么改、怎么验证、风险在哪里”。

### 3.3 外部写回风险不可控

飞书、Multica、metadata、Obsidian 写回都必须走审批边界和 readback。v1.0 明确不自动部署、不自动远端裁决、不自动改高风险状态。

### 3.4 估时不准但没人复盘

司南要求开工前给估时，结束后记录真实耗时、误差和下次估时建议。当前 v1.0 样本显示最大误差约 5.4 分钟，主要问题是偏保守高估。

## 4. 核心能力

| 能力 | 解决的问题 | 入口/证据 |
|---|---|---|
| 需求/方案/交付门禁 | 防止需求不清就开干、方案不明就改代码、交付不可验收 | `scripts/requirement-gate.sh`、`scripts/design-gate.sh`、`scripts/deliverable-gate.sh` |
| 可信计时与估时校准 | 防止任务耗时凭感觉、复盘无数据 | `scripts/execution-timer.sh`、`scripts/time-estimation-calibration.sh` |
| Evidence 标准化 | 让执行结果可审计、可复核、可分享 | `scripts/collect-evidence.sh`、`scripts/evidence-index.sh`、`scripts/review-packet.sh` |
| 受控写回 | 让飞书/Multica/metadata 写回可审批、可回读 | `scripts/approval-boundary.sh`、`scripts/writeback-gate.sh` |
| 项目记忆 | 沉淀经验、偏好、踩坑，减少重复解释 | `memory/index.json`、`scripts/recommend-memory.sh`、`scripts/extract-experience.sh` |
| 多角色质量闭环 | 区分执行、审查、测试、表达，不让 reviewer 自动裁决 | `scripts/route-actor.sh`、`config/routing-policy.json` |
| Obsidian 知识镜像 | 把 run、文档、配置、外链同步到知识库复盘 | `scripts/obsidian-sync.sh` |
| 能力注册表 | 统一记录能力、入口、证据、验证方式 | `config/sinan-capabilities.json` |

## 5. 标准工作流

```text
目标 / Multica Issue / 飞书任务
  -> 明确目标、验收、边界、副作用
  -> 任务分类和记忆推荐
  -> 需求门禁
  -> 方案生成和设计门禁
  -> 本地执行或 ai-loop run
  -> 收集 evidence
  -> 交付门禁和 review packet
  -> 受控写回审批
  -> 飞书/Multica/Obsidian readback
  -> 计时复盘和记忆沉淀
```

## 6. 快速上手

### Step 1：确认任务是否适合进入司南

适合进入司南的任务通常满足任一条件：

- 多步骤，需要持续推进。
- 涉及代码、文档、验证、外部写回中的多个环节。
- 需要保留证据或之后复盘。
- 涉及飞书、Multica、Obsidian、跨会话交接。

简单问答、一次性解释、纯脑暴不一定要进司南。

### Step 2：准备任务文件

推荐任务文件包含：

```markdown
# 任务名称

## 目标

## 非目标

## 验收标准

## 风险与副作用

## 验证方式
```

### Step 3：做本地预检

```bash
cd /home/user/JAVA/ai/ai-loop
./scripts/loop-execution-preflight.sh --task tasks/<task>.md --run-id <run-id> --output runs/<run-id>/execution-preflight.md --json-output runs/<run-id>/execution-preflight.json
```

### Step 4：开工估时

```bash
./scripts/execution-timer.sh start --run-id <run-id> --name <slice-name> --estimate-minutes 10-20 --basis "本轮任务依据" --task-type <task-type> --stop-condition "可验收停止条件"
```

### Step 5：执行与验证

按任务类型执行本地修改、文档生成、脚本运行或 ai-loop run。执行后至少保留：

- `summary.md` 或阶段总结。
- 关键命令输出。
- 验证报告。
- 如有写回，保留 write result 和 readback。

### Step 6：收工复盘

```bash
./scripts/execution-timer.sh close --run-id <run-id> --name <slice-name> --output runs/<run-id>/<slice-name>-close.md --json-output runs/<run-id>/<slice-name>-close.json
```

收工必须说明：估时、实际耗时、误差、下次估时建议。

### Step 7：同步知识库

```bash
WRITE_OPERATION_LOG=false DRY_RUN=false ./scripts/obsidian-sync.sh
```

### Step 8：外部写回

外部写回必须满足：

- 已有明确目标位置。
- 已有人类审批或预授权策略。
- 写回后必须 readback。
- 不自动部署、不自动生产操作、不自动 reviewer 最终裁决。

## 7. 常用命令速查

| 场景 | 命令 |
|---|---|
| 查看能力注册 | `cat config/sinan-capabilities.json` |
| 校验能力注册 | `./scripts/sinan-capability-check.sh` |
| strict 工具链验证 | `./scripts/verify-toolchain.sh --case FUZ-554 --pattern "FUZ-554-real-multica-loop-gated-20260622-142303" --strict --state-gate` |
| 任务分类 | `./scripts/classify-task.sh --input tasks/<task>.md` |
| 生成计划 | `./scripts/generate-plan.sh --task tasks/<task>.md` |
| 收集证据 | `./scripts/collect-evidence.sh --run-id <run-id>` |
| 生成 review packet | `./scripts/review-packet.sh --run-id <run-id>` |
| Obsidian 同步 | `WRITE_OPERATION_LOG=false DRY_RUN=false ./scripts/obsidian-sync.sh` |

## 8. 角色分工

| 角色 | 责任 | 不做什么 |
|---|---|---|
| 用户/负责人 | 确认目标、验收、审批高风险副作用 | 不把模糊目标直接丢给系统无限跑 |
| 执行 Agent | 拆任务、执行、验证、产出 evidence | 不绕过审批写外部系统 |
| Reviewer | 检查风险、缺口、证据质量 | 不自动给最终裁决 |
| 司南工具链 | 提供门禁、计时、证据、写回边界 | 不替代人类判断 |

## 9. v1.0 已知边界

- 不自动部署。
- 不自动访问生产。
- 不自动做 reviewer 最终裁决。
- 不自动做远端写回决策。
- 不把 P50/P80 估时当承诺。
- 不保证所有业务任务都能一次通过。
- 当前产品形态仍偏工程工作台，不是图形化 SaaS。

## 10. 当前验收状态

| 项目 | 状态 | 证据 |
|---|---|---|
| 版本 | released | `config/sinan-version.json` |
| 本地验证 | 通过 | `runs/sinan-v1-continuous-20260624-010139/completion-audit-verification.md` |
| 飞书写回 | 完成 | `runs/sinan-v1-continuous-20260624-010139/feishu/` |
| Multica 写回 | 完成 | `runs/FUZ-554-real-multica-loop-gated-20260622-142303/multica-v1-release-comment-20260624.readback.json` |
| Obsidian 同步 | 完成 | `/mnt/d/JAVA/knowledge/tiandao/99-generated` |
| 最终审计 | 完成 | `runs/sinan-v1-continuous-20260624-010139/completion-audit.md` |

## 11. 新任务推荐模板

```markdown
# <任务名>

## 目标

## 验收标准

## 风险与副作用

- 本地文件：允许 / 不允许
- 飞书写入：允许 / 不允许
- Multica 写入：允许 / 不允许
- Obsidian 同步：允许 / 不允许
- 代码部署：必须单独审批

## 计划

1. 需求确认
2. 方案设计
3. 本地执行
4. 验证和 evidence
5. 受控写回
6. 收工计时复盘
```

## 12. 推荐下一步

v1.0 后建议优先做三件事：

1. 提升估时准确率，减少高估和低估。
2. 补齐真实业务 E2E 案例，覆盖文档、代码、写回三类任务。
3. 把当前工程文档进一步产品化，降低新人理解成本。
