# 司南课题：Token 使用率优化 Loop 方案

## 1. 课题背景

司南进入 v1.0 后，已经具备门禁、证据、计时、写回、记忆和路线图能力。但长任务仍存在 token 使用效率问题：长会话上下文持续膨胀，重复读取大文件，阶段汇报冗长，子任务结果回传过多，历史信息污染当前判断。该课题目标是把 token 使用从“靠习惯节省”升级为“可度量、可治理、可复盘”的系统能力。

## 2. 目标

在不牺牲事实准确性、审批安全和 evidence 完整性的前提下，降低长任务和 Loop 任务的 token 消耗，提高单位 token 产出的可验收结果比例。

## 3. 非目标

- 不为了省 token 牺牲安全确认。
- 不压缩代码、命令、错误、路径、审批边界到不可读。
- 不自动删除历史 evidence。
- 不用 token 指标替代业务交付质量。
- 不默认把所有文档改成极简风格。

## 4. 核心指标

| 指标 | 定义 | v1 目标 | v2 目标 |
|---|---|---|---|
| 输出 token 密度 | 有效结论/操作/证据占输出比例 | 降低废话和重复段落 | 形成自动 lint |
| 上下文复用率 | 后续会话从 md/evidence 继续而非吃完整历史 | 关键长任务有 handoff | 新会话默认从摘要启动 |
| 重复读取率 | 同一轮重复读取同一大文件次数 | 人工审计下降 | 脚本检测 |
| Evidence 引用率 | 用路径/摘要引用而非整段复制 | 80% 以上 | 90% 以上 |
| 中间汇报压缩率 | 中间进展只保留状态、证据、下一步 | 低风险任务压缩 | 自动模板化 |
| 估时-token 关系 | token 消耗与真实耗时、任务类型关联 | 先采样 | 进入估时模型 |

## 5. 当前基线

已有基础：

- `docs/ai-work-orchestration/21-local-operating-protocol.md` 已包含输出压缩与长上下文节流规则。
- `docs/ai-work-orchestration/29-token-efficiency.md` 已固化 Token 使用率指标、阈值、输出策略和 closeout 模板。
- `docs/ai-work-orchestration/share/sinan-best-practices-templates.md` 已要求长任务不要无限拖长会话。
- 全局 `AGENTS.md` 已加入上下文与交接管理规则。
- 已接入 `caveman`/`cavecrew` 技能，用于低风险压缩表达和子任务压缩回传。
- 已有 `execution-timer` 和 `completion-audit`，可把 token 优化与耗时/结果关联。

当前缺口：

- token 使用率的正式指标定义已完成首版，后续需要脚本化采集。
- 没有 token audit 报告模板。
- 没有对“重复读取/重复汇报/大段复制”的检测。
- 没有明确何时压缩、何时不能压缩的任务级策略矩阵。
- token 使用已纳入 closeout 模板和 v1.1-v2.0 路线横向课题。

## 6. 风险分级策略

| 场景 | 压缩策略 | 说明 |
|---|---|---|
| 低风险进展汇报 | 强压缩 | 只说状态、证据、下一步 |
| 本地代码定位 | 压缩 | 使用路径、符号、行号，不复制大段代码 |
| 文档总结 | 中压缩 | 保留结构，避免散文 |
| 飞书/Multica 写回草稿 | 轻压缩 | 保证人能读懂，不能省略边界 |
| 审批请求 | 不压缩关键内容 | 明确副作用、目标、回滚、风险 |
| 安全/删除/部署 | 不压缩 | 必须完整清楚 |
| 代码/命令/错误 | 不改写 | 原样保留 |
| Evidence | 摘要 + 路径 | 不复制全文，保留可追溯路径 |

## 7. Loop 执行方案

### Loop 0：基线审计

目标：明确当前 token 浪费模式。

任务：

1. 审计最近 3 个长 run 的输出和 evidence。
2. 统计重复读取、大段复制、重复说明、无效进展汇报。
3. 形成 `token-efficiency-baseline.md/json`。

验收：

- 至少列出 5 类 token 浪费来源。
- 每类给出一个证据路径。
- 给出优先级和预期收益。

### Loop 1：指标与模板

目标：让 token 使用率可记录。

任务：

1. 定义 token audit schema。
2. 新增 closeout 的 token 使用率小节模板。
3. 新增 handoff 摘要模板。
4. 更新产品手册和运行规约。

验收：

- 有 `docs/ai-work-orchestration/29-token-efficiency.md`。
- 有 `memory/templates/token-efficient-handoff-template.md`。
- closeout 模板能引用 token 指标。

### Loop 2：本地检测脚本 MVP

目标：自动发现明显浪费。

任务：

1. 新增 `scripts/token-efficiency-audit.sh`。
2. 检测超长 markdown、重复标题、重复路径、长段复制、缺 handoff。
3. 输出 md/json。
4. 接入 `verify-toolchain` 非阻断检查。

验收：

- 能对指定 run 输出审计报告。
- 不访问网络，不写外部系统。
- 能在 fixtures 上跑通。

### Loop 3：输出策略矩阵

目标：自动建议输出压缩等级。

任务：

1. 按 L0-L4 任务等级定义输出策略。
2. 将 `caveman`、`cavecrew` 触发场景纳入策略。
3. 明确安全/审批/部署场景禁止压缩。
4. 在 `config/sinan-capabilities.json` 增加 token governance 能力。

验收：

- `config/token-efficiency-policy.json` 存在。
- 文档说明何时压缩、何时不压缩。
- capability check 通过。

### Loop 4：Handoff 与新会话机制

目标：减少长会话输入 token。

任务：

1. 定义每个长任务的 handoff 触发条件。
2. 规定 handoff 存放路径和字段。
3. 让 final summary 输出“下一会话入口”。
4. 建立 handoff readback 清单。

验收：

- 长任务超过阈值时必须生成 handoff。
- handoff 只引用证据路径，不复制全文。
- 新会话能按 handoff 继续。

### Loop 5：效果回归

目标：证明优化有效。

任务：

1. 选择 3 类任务复测：文档、代码、写回。
2. 记录优化前/后输出长度、重复读取、完成耗时、返工。
3. 形成 token efficiency report。

验收：

- 中间汇报明显变短。
- evidence 完整性不下降。
- 审批边界没有变模糊。
- 至少 2 类任务显示 token 使用改善。

## 8. 任务拆解

| ID | 任务 | 优先级 | 产出 | 估时 |
|---|---|---|---|---|
| TE-01 | 最近长 run token 浪费审计 | P0 | baseline report | 20-40m |
| TE-02 | token 使用率指标定义 | P0 | `29-token-efficiency.md` | 30-45m |
| TE-03 | token audit schema | P0 | schema md/json | 30-45m |
| TE-04 | handoff 模板 | P0 | template | 20-30m |
| TE-05 | token-efficiency-audit 脚本 MVP | P0 | script + fixtures | 60-90m |
| TE-06 | verify-toolchain 接入 | P1 | verify check | 30-45m |
| TE-07 | 输出策略矩阵 | P0 | policy json + docs | 45-60m |
| TE-08 | capability registry 接入 | P1 | config update | 20-30m |
| TE-09 | 长任务 handoff 触发规则 | P1 | protocol update | 30-45m |
| TE-10 | 3 类任务效果复测 | P1 | regression report | 60-120m |
| TE-11 | 飞书/Multica 写回模板瘦身 | P2 | templates | 30-45m |
| TE-12 | token 看板草案 | P2 | dashboard md/json | 45-75m |

## 9. 验收标准

课题第一阶段完成标准：

- 有正式课题文档。
- 有 baseline audit。
- 有指标定义。
- 有至少一个本地审计脚本 MVP。
- 接入能力注册或 verify-toolchain。
- 至少一次真实 run 复测。
- 不破坏 evidence 完整性和审批清晰度。

## 10. 与 v1.1-v2.0 路线关系

该课题属于 v1.2 “估时回归与任务分级”和 v1.4 “记忆与交接升级”的横向能力，也支撑 v1.7 “团队运营看板”。优先级建议为 P0，因为它直接影响长任务成本、执行速度和上下文质量。

## 11. 本轮 Loop 结论

本轮只完成定方案，不做外部写回。下一轮建议先执行 TE-01 和 TE-02：做最近长 run token 浪费基线审计，并固化指标定义。
