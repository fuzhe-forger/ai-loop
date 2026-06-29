# FUZ-554：北极星任务板治理案例

## 摘要

本案例记录司南在 FUZ-554 run 中把北极星指标拆成全量任务、分片执行、按任务量估时并用历史经验修正的治理实践。

## 背景

用户要求：先根据北极星指标定出所有任务，再分片执行，根据执行经验评估后续任务时间，验证并持续调整，全部完成后输出完整报告。

## 决策

- 不再用“历史桶均值 = 本轮估时”。
- 使用 `task_quantity_first_calibration_second`：先按任务量给 `raw_estimate_minutes`，再用历史桶小权重修正为 `calibrated_estimate_minutes`。
- 任务板必须区分 `todo/done`，不能用已完成任务凑时间。
- 每个阶段都必须留下 md/json evidence，后续阶段从 artifact 接续，不依赖长会话上下文。

## 产物

- `config/north-star-tasks.json`
- `scripts/north-star-task-board.sh`
- `runs/FUZ-554-real-multica-loop-gated-20260622-142303/north-star-task-board.md`
- `runs/FUZ-554-real-multica-loop-gated-20260622-142303/north-star-execution-report.md`

## 经验

### 做对了什么

- 将抽象北极星指标转成机器可读任务。
- 把任务量估时和历史校准拆成两个字段，避免历史均值误导单次任务。
- 通过 Obsidian generated 读回验证知识沉淀。

### 暴露的问题

- 首轮任务量估时仍偏保守：估 `24-30` 分钟，实际 `15.5` 分钟。
- documentation 校准桶样本太少，不能作为强依据。
- 长任务需要阶段 handoff，避免继续堆长上下文。

## 可复用模式

1. 从北极星/目标拆全量任务。
2. 每个任务写明 metric、phase、验收、验证、产物和副作用。
3. 用任务量先估时，再用历史桶小权重修正。
4. 分片执行，每片刷新 evidence。
5. 结束时生成完整报告和下一轮估时调整。

## 状态

- Status: accepted
- Review: human-readable artifact generated; future runs should reuse the pattern
- Tags: north-star, task-board, timing, evidence, sinan
