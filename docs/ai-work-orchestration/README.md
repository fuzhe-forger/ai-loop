# 司南：AI 工作编排实践总入口

`司南` 是本地 AI 工作编排系统的当前名称。实现层由 Multica、ai-loop、Obsidian、CodeGraph 和本地治理脚本组成；系统目标是让 AI 工作可治理、可审计、可复盘、可持续进化。

## 你应该先看什么

1. `product/sinan-v1-product-manual.md`：v1.0 产品说明与使用手册，面向新人和使用者。
2. `product/sinan-v1-to-v2-roadmap.md`：v1.1 到 v2.0 正式路线图。
3. `product/sinan-token-efficiency-loop-plan.md`：Token 使用率优化课题方案，定义长任务 token 治理指标、Loop 切片和验收标准。
4. `09-north-star.md`：终极效果、2026-06 近期北极星、Phase I 时间校准路线图和当前取舍。
5. `21-local-operating-protocol.md`：本地默认运行总规约。
6. `23-design-output-governance.md`：Phase H 需求沟通、方案设计与产出把控。
7. `10-evidence-standard.md`：AI 工作证据包的正式标准。
8. `11-loop-state-machine.md`：Multica Loop 状态推进规则。
9. `16-controlled-writeback-policy.md`：受控回写策略。
10. `20-automation-enhancement.md`：自动化增强 MVP。
11. `reports/`：每个阶段的正式报告。
12. `24-execution-governance-matrix.md`：执行治理矩阵，统一判断 phase report、operation log、writeback、closeout 和 token 控制。
13. `config/sinan-capabilities.json`：司南能力注册表，统一记录能力、入口、证据、文档和验证方式。
14. `25-execution-time-contract.md`：执行时间契约，规定开工估时、收工实际用时复盘和校准口径。
15. `29-token-efficiency.md`：Token 使用率治理规约，定义指标、阈值、输出策略和 closeout 模板。

## 当前阶段

- 项目：`司南：AI 工作编排实践`。
- 当前重点：v1.0 产品化使用入口、v1.1-v2.0 路线图、可信时间校准和真实 E2E 案例。
- 当前新增课题：Token 使用率优化，用 Loop 治理长会话膨胀、重复读取、冗长汇报和 evidence 大段复制。
- 默认策略：本地优先、证据优先、需求先沟通、方案先评审、产出先验收、估时必复盘、人类最终决策。
- 当前状态：v1.0.0 released，本地治理能力已验收；后续按 `product/sinan-v1-to-v2-roadmap.md` 推进产品化入口、真实 E2E、估时回归、轻重流程自适应和平台化封装。

## 标准入口

正式任务默认按以下顺序进入系统：

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
  -> review-packet
  -> writeback-gate
  -> human decision
  -> optional remote writeback
  -> obsidian-sync
  -> time-estimation-calibration
  -> memory / self-evolution
```

## 推荐阅读顺序

### 理念与规约

- `00-vision.md`
- `01-domain-model.md`
- `09-north-star.md`
- `09-north-star.md#2026-06-重定向近期北极星`
- `21-local-operating-protocol.md`
- `23-design-output-governance.md`
- `29-token-efficiency.md`
- `gates/requirement-gate-spec.md`：需求门禁字段、结果语义和澄清输出标准。
- `gates/design-gate-spec.md`：方案门禁字段、严格模式和执行前准入标准。
- `gates/deliverable-gate-spec.md`：交付门禁字段、run strict 模式和交付准入标准。

### 治理模型

- `10-evidence-standard.md`
- `11-loop-state-machine.md`
- `12-issue-metadata-contract.md`
- `13-agent-crew-model.md`
- `15-project-memory-model.md`
- `16-controlled-writeback-policy.md`
- `20-automation-enhancement.md`
- `22-obsidian-self-evolution.md`

### 实践与分享

- `product/sinan-v1-product-manual.md`
- `product/sinan-v1-to-v2-roadmap.md`
- `product/sinan-token-efficiency-loop-plan.md`
- `05-case-playbook.md`
- `cases/FUZ-554/README.md`
- `share/README.md`
- `share/tech-sharing-outline.md`
- `share/demo-script.md`
- `share/slide-deck.md`
- `share/preflight-checklist.md`

## 当前证据入口

- North Star：`09-north-star.md`
- 本地运行规约：`21-local-operating-protocol.md`
- Token 使用率治理：`29-token-efficiency.md`
- Phase H 规则：`23-design-output-governance.md`
- Phase H 报告：`reports/2026-06-18-phase-60-design-output-governance.md`
- 自动化增强报告：`reports/2026-06-16-phase-58-automation-enhancement.md`
- 本地落地报告：`reports/2026-06-16-phase-59-local-adoption.md`
- FUZ-554 案例：`cases/FUZ-554/README.md`

## 关键脚本

- `scripts/multica-loop.sh`：Multica 到本地 ai-loop 的封装入口，收尾生成 classification、gate policy、execution preflight、continuation gate evidence，并可通过显式参数触发受控 comment/status/metadata 写回。
- `scripts/loop-intake-gate.sh`：任务入口门禁。
- `scripts/requirement-gate.sh`：需求沟通充分性门禁。
- `scripts/design-gate.sh`：方案设计质量门禁。
- `scripts/deliverable-gate.sh`：产出完整性门禁。
- `scripts/gate-policy-check.sh`：按任务类型校验 required gates 和最低分。
- `scripts/gate-policy-exception.sh`：生成本地人工例外 evidence。
- `config/sinan-capabilities.json`：司南能力注册表，供能力发现、自检和 Obsidian 镜像复核使用。
- `scripts/sinan-capability-check.sh`：校验能力注册表中的脚本、配置和文档引用是否存在，并输出能力摘要。
- `docs/ai-work-orchestration/25-execution-time-contract.md`：司南执行时间契约；每轮开始必须估时，结束必须报告真实用时和偏差。
- `config/gate-policy.json`：任务类型门禁策略配置。
- `config/approval-boundary.json`：副作用动作、审批要求和默认决策的统一策略配置。
- `config/timebox-policy.json`：任务等级、连续执行窗口、防空转阈值和停下规则的统一策略配置。
- `scripts/collect-evidence.sh`：执行证据收集。
- `scripts/refresh-run-evidence.sh`：批量刷新 state、metadata 和 gate policy evidence。
- `scripts/evaluate-state.sh`：状态判断。
- `scripts/approval-boundary.sh`：读取 `config/approval-boundary.json`，本地判断动作是否可继续或必须停下等待人类审批。
- `scripts/writeback-gate.sh`：远端回写门禁。
- `scripts/writeback-summary-json.sh`：将回写 Markdown 摘要转换为结构化 JSON evidence，包含 comment/status/metadata 的 approval boundary 引用，供 state/evidence/golden path 优先读取。
- `scripts/metadata-writeback.sh`：受控 Multica metadata KV 回写封装，默认 dry-run，`--write` 必须通过 `approval-boundary` 和 `writeback-gate` 后才产生远端副作用。
- `scripts/smoke-multica-writeback.sh`：使用 fake `multica` 的本地回归，验证审批后 metadata 写回会生成 approval boundary、writeback gate 和 readback evidence。
- `scripts/share-preflight.sh`：本地分享预检入口，可聚合 refresh、verify、review packet、golden path 报告，并输出 `share-preflight-summary.md/json`，直接展示 golden path 结果与 approval boundary 快照；自检场景可用 `--skip-verify` 避免递归调用，分享候选可用 `--persist-to-run` 沉淀到 run evidence。
- `scripts/review-packet.sh`：人工复核包生成器，展示 core evidence、gate、writeback 和 approval boundary 状态。
- `scripts/golden-path-check.sh`：黄金路径校验，验证本地 evidence、approval boundary、writeback artifacts 与 Obsidian generated 是否一致。
- `scripts/loop-continuation-gate.sh`：阶段完成后的续跑门禁，按任务等级、可信计时、closeout、writeback/readback 判断是继续推进、允许停下还是触发审批边界。
- `scripts/execution-time-contract.sh`：执行时间契约生成器，固化开工估时、实际耗时、偏差和下一轮估时建议，并由 evidence checklist/index 展示。
- `scripts/time-estimation-calibration.sh`：司南内建估时校准报表；只统计 `timing_source=timestamp` 的可信样本，manual 耗时仅用于审计/debug。
- `~/.agents/skills/caveman*` / `~/.agents/skills/cavecrew`：司南输出压缩与长上下文节流能力；通过 `token_output_compression` 注册到能力目录，使用前不改变审批、证据或验证规则。
- `scripts/obsidian-sync.sh`：知识库同步，generated run 页面展示 gate policy 和人工例外；同步操作日志写入 `state/operations/`，不反向触发二次同步。

## 模板入口

- `templates/multica-issue-summary-template.md`
- `templates/multica-comment-summary-template.md`
- `templates/loop-handoff-summary-template.md`
- `templates/obsidian-readable-card-template.md`
- `../../memory/templates/requirement-clarification-template.md`

## 使用方式

- 新案例放在 `cases/<issue-or-name>/`。
- 新阶段报告放在 `reports/YYYY-MM-DD-phase-<n>-<name>.md`。
- 通用规则放在编号文档中。
- 新脚本必须接入本地验证或在阶段报告中说明暂未接入原因。

团队成员可以先看总入口，再进入规约、阶段报告、案例和脚本，不需要从零散文件中拼接上下文。
