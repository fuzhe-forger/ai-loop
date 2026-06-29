# 阶段报告：Phase 63 Clarification State Gate

## 目标

把 `clarification.md` 接入 `evaluate-state` 和 `verify-toolchain --state-gate`，让 `needs_clarification` 状态具备强制 evidence 要求。

## 背景与问题

Phase 62 已经让 `clarification.md` 出现在 collect-evidence、evidence checklist、evidence index 和 review packet 中。但如果 state gate 不强制校验，仍可能出现 requirement gate 已失败、状态需要人类澄清，却没有可交给人类的澄清草稿。

## 核心结论

- `evaluate-state.sh` 已读取 `requirement-gate.md` 和 `clarification.md`。
- 当 `requirement-gate.md` 失败且 `clarification.md` 存在时，状态进入 `needs_clarification`，下一角色为 `human`。
- 当 `requirement-gate.md` 失败但 `clarification.md` 缺失时，状态进入 `blocked`，下一角色为 `execution_agent`。
- `verify-toolchain.sh --state-gate` 已要求 `needs_clarification` run 必须包含 `clarification.md`。
- 本阶段仍然 local-only，不读取 Multica，不产生远端副作用。

## 状态规则

| 条件 | To | Next Actor | 原因 |
|---|---|---|---|
| core evidence 缺失 | `blocked` | `execution_agent` | 缺少基础 evidence |
| requirement gate 失败且 clarification 缺失 | `blocked` | `execution_agent` | `needs_clarification` 缺少澄清 evidence |
| requirement gate 失败且 clarification 存在 | `needs_clarification` | `human` | 等待人类补充需求 |
| core evidence 完整但无 verification report | `evidence_ready` | `execution_agent` | 等待验证 evidence |
| verification report 存在但无回写 | `review_ready` | `reviewer` | 等待复核 |
| writeback summary 显示远端写入完成 | `done` | `human` | 等待最终确认 |

## 验收与验证

验证样例：

- `runs/phase-61-clarification-sample`：包含 `requirement-gate.md` 和 `clarification.md`。
- `runs/phase-61-missing-clarification-sample`：包含失败的 `requirement-gate.md`，但缺少 `clarification.md`。

验证命令：

```bash
./scripts/evaluate-state.sh \
  --issue PHASE-61 \
  --run-id phase-61-clarification-sample \
  --write-run

./scripts/evaluate-state.sh \
  --issue PHASE-61 \
  --run-id phase-61-missing-clarification-sample \
  --write-run

./scripts/verify-toolchain.sh \
  --case FUZ-554 \
  --pattern 'FUZ-554*' \
  --output /tmp/toolchain-clarification-state-gate.md

./scripts/verify-toolchain.sh \
  --case PHASE-61 \
  --pattern 'phase-61-clarification-sample' \
  --state-gate \
  --output /tmp/state-gate-present-clarification.md

./scripts/verify-toolchain.sh \
  --case PHASE-61 \
  --pattern 'phase-61-missing-clarification-sample' \
  --state-gate \
  --output /tmp/state-gate-missing-clarification.md
```

验证结果：

- `phase-61-clarification-sample`：To `needs_clarification`，Reason `requirement gate failed; clarification evidence is present`，Next Actor `human`。
- `phase-61-missing-clarification-sample`：To `blocked`，Reason `needs_clarification but clarification evidence is missing`，Next Actor `execution_agent`。
- `verify-toolchain --state-gate` 检查 `phase-61-clarification-sample`：PASSED。
- `verify-toolchain --state-gate` 检查 `phase-61-missing-clarification-sample`：FAILED，缺失 `clarification.md`。
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

- 为 `clarification.md` 增加模板质量检查。
- 将 requirement/design/deliverable 三类 gate 结果统一写入 `evidence.json`。
