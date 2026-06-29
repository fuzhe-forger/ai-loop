# 阶段报告：Phase 66 Clarification Gate State Integration

## 目标

把 `clarification-gate.md` 接入 `evaluate-state` 和 `verify-toolchain --state-gate`，确保 `needs_clarification` handoff 给人类前，澄清草稿不仅存在，而且质量检查已通过。

## 背景与问题

Phase 65 已经新增 `clarification-gate`，可以判断 `clarification.md` 是否可回答、可推进。但如果 state gate 只检查 `clarification.md` 存在，仍可能把质量不合格的问题清单交给人类，造成沟通成本和返工。

## 核心结论

- `evaluate-state.sh` 已读取 `clarification-gate.md`。
- `requirement-gate.md` 失败且 `clarification.md`、`clarification-gate.md` 均存在且通过时，状态进入 `needs_clarification`，下一角色为 `human`。
- `clarification-gate.md` 缺失时，状态进入 `blocked`，下一角色为 `execution_agent`。
- `clarification-gate.md` 存在但未通过时，状态进入 `blocked`，下一角色为 `execution_agent`。
- `verify-toolchain.sh --state-gate` 已校验 `clarification-gate.md` 存在且结果为 PASSED。

## 状态规则

| 条件 | To | Next Actor | 原因 |
|---|---|---|---|
| requirement gate 失败，clarification 缺失 | `blocked` | `execution_agent` | 缺少澄清草稿 |
| requirement gate 失败，clarification gate 缺失 | `blocked` | `execution_agent` | 缺少质量检查 evidence |
| requirement gate 失败，clarification gate 未通过 | `blocked` | `execution_agent` | 澄清草稿不可交付 |
| requirement gate 失败，clarification 和 gate 均通过 | `needs_clarification` | `human` | 可交给人类补充需求 |

## Evidence 可见性

- `collect-evidence.sh` 已展示 `clarification-gate.md`。
- `evidence-checklist.sh` 已展示 `clarification-gate.md`。
- `evidence-index.sh` 已新增 `Clarification Gate` 列。
- `review-packet.sh` 已新增 `Clarification Gate` 列。
- `obsidian-sync.sh` 已在 generated run index 和 run page 中展示 clarification gate。

## 验收与验证

验证样例：

- `phase-61-clarification-sample`：有 clarification 且 gate 通过。
- `phase-61-missing-clarification-gate-sample`：有 clarification 但缺 gate。
- `phase-61-failed-clarification-gate-sample`：有 clarification 但 gate 失败。

验证命令：

```bash
./scripts/evaluate-state.sh --issue PHASE-61 --run-id phase-61-clarification-sample --write-run
./scripts/evaluate-state.sh --issue PHASE-61 --run-id phase-61-missing-clarification-gate-sample --write-run
./scripts/evaluate-state.sh --issue PHASE-61 --run-id phase-61-failed-clarification-gate-sample --write-run

./scripts/verify-toolchain.sh --case PHASE-61 --pattern 'phase-61-clarification-sample' --state-gate --output /tmp/state-gate-clarification-quality-ok.md
./scripts/verify-toolchain.sh --case PHASE-61 --pattern 'phase-61-missing-clarification-gate-sample' --state-gate --output /tmp/state-gate-phase-61-missing-clarification-gate-sample.md
./scripts/verify-toolchain.sh --case PHASE-61 --pattern 'phase-61-failed-clarification-gate-sample' --state-gate --output /tmp/state-gate-phase-61-failed-clarification-gate-sample.md
```

验证结果：

- `phase-61-clarification-sample`：To `needs_clarification`，Reason `requirement gate failed; clarification evidence and quality gate are present`，Next Actor `human`。
- `phase-61-missing-clarification-gate-sample`：To `blocked`，Reason `needs_clarification but clarification gate evidence is missing`，Next Actor `execution_agent`。
- `phase-61-failed-clarification-gate-sample`：To `blocked`，Reason `needs_clarification but clarification gate did not pass`，Next Actor `execution_agent`。
- `verify-toolchain --state-gate` 对通过样例：PASSED。
- `verify-toolchain --state-gate` 对缺 gate 样例：FAILED，缺失 `clarification-gate.md`。
- `verify-toolchain --state-gate` 对 gate 失败样例：FAILED，缺失 `clarification-gate.result`。
- `collect-evidence` JSON / Markdown 已显示 `clarification_gate`。
- `evidence-index` 和 `review-packet` 已显示 `Clarification Gate` 列。
- fake vault Obsidian generated run page 已显示 `## Clarification Gate`。
- fake vault Obsidian run index 已显示 `Clarification Gate` 列，`phase-61-clarification-sample` 为 `✓`。
- `verify-toolchain.sh --case FUZ-554 --pattern 'FUZ-554*'`：PASSED。

## 负责人 / 角色

- Owner / DRI：傅喆。
- Actor：顾实。
- Reviewer：人工复核；后续可交给裴衡按 evidence 复核。

## 副作用与回写状态

- Network access: false。
- Remote writes: false。
- Multica writeback: none。
- Feishu writeback: none。
- External side effect: none。

## 下一步

- 将 clarification gate 分数展示到 Obsidian generated run 页面。
- 将 requirement/design/deliverable/clarification 四类 gate 结果统一写入 `evidence.json`。
