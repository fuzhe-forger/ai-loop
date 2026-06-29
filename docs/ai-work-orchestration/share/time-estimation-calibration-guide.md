# 估时校准指南

## 目标

让司南同时关注两件事：

- 任务开始前的时间评估要尽量准确。
- 任务达到可验收结果后要尽快收口，不为凑时间继续执行。

## 使用命令

```bash
./scripts/time-estimation-calibration.sh --pattern <run-id-or-glob> --output <report.md> --json-output <report.json>
```

默认读取 `continuation-gate.json`，同时聚合 run 目录下所有 `execution-time-contract*.json`。这样正式 Loop 的 continuation gate、聊天窗口任务和阶段切片的执行时间契约都会进入同一份估时校准报告；只有 `timestamp` 来源会进入可信推荐值计算。

报告会按 `task_type` 生成桶，例如 `local_script_patch`。`loop-execution-preflight` 会优先使用匹配任务类型的桶推荐值；没有匹配桶时才回退到全局可信样本推荐值。

当任务描述同时包含“文档”和“脚本 / evidence / Obsidian”等关键词时，执行前应显式传入 `--task-type documentation` 或 `--task-type local_script_patch`，避免预估时间落入错误桶。

## 判断口径

| 字段 | 含义 |
|---|---|
| `estimated_minutes` | 执行前或策略给出的预估时间 |
| `timing_source` | 计时来源；只有 `timestamp` 是可信校准样本 |
| `started_at` / `completed_at` | 可审计开始 / 结束时间戳 |
| `elapsed_seconds` | 由时间戳计算出的秒级耗时，用于精确审计 |
| `elapsed_minutes` | 由时间戳计算出的执行窗口耗时；`manual` 仅作回退展示 |
| `variance_ratio` | `abs(actual - estimate) / estimate`；只对可信样本统计 |
| `estimate_accuracy` | 可信样本是否在容忍偏差内 |
| `absolute_error_minutes` | 实际耗时与估时区间的绝对误差；命中区间时为 `0.0` |
| `within_one_minute` | 绝对误差是否小于 1 分钟，用于 Phase I 估时收敛目标 |
| `one_minute_hit_rate` | 所有可信样本中 `<1 分钟` 命中的比例 |
| `direction` | `overestimated` / `underestimated` / `accurate` |
| `recommended_next_estimate_minutes` | 基于可信样本给出的下次估时建议 |

## 当前 FUZ-554 样例

- 预估：90 分钟。
- 历史 `elapsed_minutes=30` 是 manual 输入，不是可审计实际耗时。
- 历史 manual 样本只保留为审计/debug 信息，不进入可信校准统计。
- 后续只有 `timing_source=timestamp` 的样本才计算偏差、方向和下次估时建议。

## 执行原则

- 如果 `ALLOW_STOP` 且验收完成，即使低于预估时间，也应快速总结交付。
- 如果未达到验收结果，低于防空转阈值时继续推进下一组实质切片。
- 偏差超出容忍范围不是失败，而是下次估时要调整的证据。
- 禁止把手工填写的耗时包装成“实际耗时”；没有时间戳就明确标为 manual / not measured。
