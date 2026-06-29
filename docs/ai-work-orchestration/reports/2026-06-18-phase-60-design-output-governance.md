# 阶段报告：Phase 60 Design & Output Governance

## 目标

把 Phase H 的“方案设计与产出把控”落成本地 MVP，让 `司南` 在执行前检查方案质量，在交付前检查产出完整性。

## 背景与问题

Phase A-G 已经建立任务、执行、evidence、记忆、回写和自动化增强的基础能力。当前风险是：方案设计不足会放大执行返工，产出摘要不足会降低人类复核效率。

## 核心结论

- 新增 Phase H 文档：`docs/ai-work-orchestration/23-design-output-governance.md`。
- 新增方案设计门禁：`scripts/design-gate.sh`。
- 新增产出把控门禁：`scripts/deliverable-gate.sh`。
- 两个门禁都是 local-only，不读取 Multica，不产生远端副作用。
- 后续建议把 gate 结果接入 review packet 和 Obsidian 摘要卡。

## 方案与设计

### design-gate

`design-gate` 检查设计文档是否覆盖背景、目标、范围、方案、依赖、风险、验证、待决策、负责人和副作用策略。

### deliverable-gate

`deliverable-gate` 检查交付物是否包含目的、结论、证据、验证、负责人、下一步和回写状态。

### 流程集成

设计门禁放在 `generate-plan` 之后、`ai-loop run` 之前；产出门禁放在 `collect-evidence` 之后、`review-packet` / `writeback-gate` 之前。

## 依赖与影响

- 依赖本地 `bash`、`rg` 和现有 markdown 产物。
- 影响 `verify-toolchain.sh` 的本地 smoke check 清单。
- 不影响 Multica、飞书、Git remote、部署或生产系统。

## 风险与回滚

- 风险：关键词检查可能误判，需要在真实任务中继续调优。
- 降级：脚本失败时仍可人工记录例外原因后继续。
- 回滚：删除两个脚本并从 README、north-star、local protocol 中移除 Phase H 入口即可恢复。

## 验收与验证

验证命令：

```bash
bash -n scripts/design-gate.sh
bash -n scripts/deliverable-gate.sh
./scripts/design-gate.sh --input docs/ai-work-orchestration/23-design-output-governance.md --strict
./scripts/deliverable-gate.sh --input docs/ai-work-orchestration/reports/2026-06-18-phase-60-design-output-governance.md
./scripts/verify-toolchain.sh --list-checks
./scripts/verify-toolchain.sh --case FUZ-554 --pattern 'FUZ-554*' --output /tmp/toolchain-phase-h.md
```

验证结果：

- `bash -n scripts/design-gate.sh`：PASSED。
- `bash -n scripts/deliverable-gate.sh`：PASSED。
- `design-gate` 检查 Phase H 规则文档：PASSED，score `100/100`。
- `deliverable-gate` 检查本阶段报告：PASSED，score `100/100`。
- `verify-toolchain.sh --list-checks` 已包含两个新脚本。
- `verify-toolchain.sh --case FUZ-554 --pattern 'FUZ-554*'`：PASSED。

真实样例校准：

- `design-gate` 检查 `runs/FUZ-577-b-policy-review-pack/technical-design-draft.md`：FAILED，原因是设计正文未显式引用 `FUZ-577`，暴露 traceability 缺口。
- `deliverable-gate` 检查 `runs/FUZ-577-b-policy-review-pack/stage-report.md`：FAILED，原因是阶段报告缺少明确 `目的 / 目标` 字段，暴露人类阅读层缺口。
- 这两个失败符合 Phase H 预期：门禁不是追求历史材料全部通过，而是把方案和产出缺口显性化。

## 负责人 / 角色

- Owner / DRI：傅喆。
- Actor：顾实。
- Reviewer：人工复核；后续可交给裴衡按 evidence 复核。

## 待决策 / 开放问题

- 是否把 `design-gate` 设为所有 S2+ 任务的默认强制门禁。
- 是否把 `deliverable-gate` 设为所有 Multica comment/writeback 前置门禁。
- 是否为业务方案、技术方案、代码变更、审计回写配置不同权重。

## 副作用与回写状态

- Network access: false。
- Remote writes: false。
- Multica writeback: none。
- Feishu writeback: none。
- External side effect: none。

## 下一步

- 按 FUZ-577 暴露的问题补强方案模板：必须显式写 issue traceability 和产出目的。
- 将 gate 报告纳入 `review-packet.md`。
- 把高频失败项沉淀到 `memory/`，反哺后续方案模板。
