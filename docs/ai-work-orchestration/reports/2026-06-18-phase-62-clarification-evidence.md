# 阶段报告：Phase 62 Clarification Evidence

## 目标

把 `clarification.md` 从 requirement gate 的附属输出升级为正式 run evidence，并纳入 evidence index、checklist、collect-evidence 和 review packet。

## 背景与问题

Phase 61 已经让 `requirement-gate` 在需求不清时生成 `clarification.md`。但如果该文件不进入 evidence 和 review packet，reviewer 仍然无法从标准复核入口判断需求是否处于 `needs_clarification`，也无法看到应交给人类确认的问题清单。

## 核心结论

- `collect-evidence.sh` 已将 `clarification.md` 纳入 JSON 和 Markdown artifact。
- `evidence-checklist.sh` 已展示 `clarification.md` 是否存在。
- `evidence-index.sh` 已新增 `Clarification` 列。
- `review-packet.sh` 已新增 `Clarification` 列，并增加 `needs_clarification` 复核问题。
- 本阶段仍然 local-only，不读取 Multica，不产生远端副作用。

## 方案与设计

### collect-evidence

新增 artifact：

```json
"clarification": {
  "path": "runs/<run-id>/clarification.md",
  "present": true
}
```

### evidence checklist / index

`clarification.md` 成为可见检查项。缺失不默认阻断所有 run，但对 `needs_clarification` run 应视为必需 evidence。

### review packet

review packet 的 evidence index 新增 `Clarification` 列。reviewer 需要确认：如果 run 是 `needs_clarification`，`clarification.md` 是否存在且可交给人类确认。

## 验收与验证

验证样例：`runs/phase-61-clarification-sample`。

验证命令：

```bash
./scripts/requirement-gate.sh \
  --input /tmp/unclear-requirement.md \
  --output runs/phase-61-clarification-sample/requirement-gate.md \
  --clarification-output runs/phase-61-clarification-sample/clarification.md

./scripts/collect-evidence.sh \
  --issue PHASE-61 \
  --run-id phase-61-clarification-sample \
  --output /tmp/phase61-evidence.json \
  --markdown /tmp/phase61-evidence.md

./scripts/evidence-checklist.sh \
  --run-id phase-61-clarification-sample \
  --output /tmp/phase61-checklist.md

./scripts/evidence-index.sh \
  --pattern 'phase-61-clarification-sample' \
  --output /tmp/phase61-index.md

./scripts/review-packet.sh \
  --case PHASE-61 \
  --pattern 'phase-61-clarification-sample' \
  --output /tmp/phase61-review-packet.md

./scripts/verify-toolchain.sh \
  --case FUZ-554 \
  --pattern 'FUZ-554*' \
  --output /tmp/toolchain-clarification-evidence.md
```

验证结果：

- `collect-evidence` Markdown 显示 `Clarification draft | present`。
- `collect-evidence` JSON 包含 `artifacts.clarification`。
- `evidence-checklist` 显示 `clarification.md: present`。
- `evidence-index` 显示 `Clarification` 列为 `yes`。
- `review-packet` 显示 `Clarification` 列为 `yes`，Suggested State 为 `needs_clarification`，Next Actor 为 `human`。
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

- 将 `clarification.md` 接入 state gate，作为 `needs_clarification` 状态的必需 evidence。
- 将 `clarification.md` 同步到 Obsidian generated run 页面。
- 为 `clarification.md` 增加固定模板和质量检查。
