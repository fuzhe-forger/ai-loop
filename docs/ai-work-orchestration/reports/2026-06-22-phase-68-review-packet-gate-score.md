# 阶段报告：Phase 68 Review Packet Gate Score

## 目标

把 requirement、design、clarification、deliverable 四类 gate score 展示到 `review-packet.md`，让 reviewer 不需要打开 `evidence.json` 就能看到质量状态。

## 背景与问题

Phase 67 已经将四类 gate 结果统一写入 `evidence.json`。但 reviewer 的主要入口是 `review-packet.md`，如果 review packet 只展示 evidence 是否存在，仍然无法快速判断各 gate 是 PASSED、FAILED 还是 MISSING。

## 核心结论

- `review-packet.sh` 的 Evidence Index 新增四列：Requirement Gate、Design Gate、Clarification Gate、Deliverable Gate。
- 每列展示 `RESULT SCORE`，例如 `PASSED 100/100` 或 `FAILED 9/100`。
- 缺失 gate 显示 `MISSING`，兼容历史 run。
- review checklist 增加 gate score 复核问题。
- 本阶段 local-only，不读取 Multica，不产生远端副作用。

## 验收与验证

验证命令：

```bash
./scripts/review-packet.sh \
  --case PHASE-61 \
  --pattern 'phase-61-clarification-sample' \
  --output /tmp/phase68-review-packet.md

./scripts/verify-toolchain.sh \
  --case FUZ-554 \
  --pattern 'FUZ-554*' \
  --output /tmp/toolchain-phase68.md
```

验证结果：

- `phase-61-clarification-sample` review packet 显示 Requirement Gate `FAILED 9/100`。
- `phase-61-clarification-sample` review packet 显示 Clarification Gate `PASSED 100/100`。
- 历史 run 缺 gate 文件时显示 `MISSING`，不阻断 review packet 生成。
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

- 把 gate score 展示到 Obsidian generated run 页面。
- 对不同任务类型配置 gate 权重和最低分。
