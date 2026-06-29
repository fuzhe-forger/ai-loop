# 执行时间契约：开工估时与收工复盘

## 目标

司南执行任务时，不能只在事后补计时工具；必须在每轮任务开始前给出预计耗时，结束时给出真实用时、偏差和下次校准建议。

这份契约同时约束聊天窗口内执行和正式 Loop 执行。

## 开工前必须输出

每轮开始执行前，先给出简短时间评估：

- **预计耗时**：用分钟或区间表达，例如 `10–15 分钟`。
- **估时依据**：说明任务规模、文件数量、验证范围、是否需要同步或写回。
- **计时起点**：记录 UTC `started_at`；聊天内任务可用当前时间，正式 Loop 由脚本写入。
- **停下条件**：说明何时收口、何时继续、何时必须找人审批。

建议模板：

```text
时间评估
- 预计耗时：10–15 分钟
- 依据：本地文档/脚本小改 + toolchain 验证 + Obsidian generated 同步
- started_at：2026-06-23T02:52:56Z
- 停下条件：验证通过并完成同步即收口；触发远端写入/安装/部署则停下审批
```

## 执行中必须遵守

- 如果实际进展明显偏离估时，及时更新预估，不假装还在原时间盒内。
- 如果已经达到可验收结果，立即 closeout，不为了填满时间继续执行。
- 如果未达到验收结果但仍在授权范围内，继续推进下一组实质切片。
- 如果触发 L4 边界、连续同类失败或缺少不可推断事实，停止并说明原因。

## 收工后必须输出

最终汇报必须包含时间复盘：

- **实际用时**：用真实 `started_at/completed_at` 计算，精确到秒或 0.1 分钟。
- **预估 vs 实际**：说明是否在预估范围内。
- **偏差原因**：如果超出或明显低于预估，说明原因。
- **下次校准**：给出同类任务下次估时建议。

建议模板：

```text
时间复盘
- 预计耗时：10–15 分钟
- 实际用时：848 秒，约 14.1 分钟
- 结果：在预估范围内
- 校准：同类“本地脚本 + 文档 + 验证 + Obsidian 同步”任务仍按 10–15 分钟估计
```

## 可信计时口径

- 正式 Loop 只把 `timing_source=timestamp` 作为可信校准样本。
- `manual` 耗时只能作为审计/debug 信息，不能包装成实际耗时。
- 聊天窗口内任务如果没有正式 run，也必须在最终回复里用本轮真实 `started_at/completed_at` 复盘。
- 司南能力、脚本或文档改动必须接入 `verify-toolchain` 或说明暂未接入原因。

## 和现有工具的关系

| 场景 | 工具 | 要求 |
|---|---|---|
| 聊天内本地任务 | `scripts/execution-timer.sh` | 开工写入 run-local marker，收工配对 marker 并输出真实用时 |
| 底层时间契约 | `scripts/execution-time-contract.sh` | 仅在已有明确 `started_at/completed_at` 时直接生成契约 |
| 正式 Loop closeout | `scripts/loop-closeout.sh` | 自动生成 continuation gate 和 time calibration evidence |
| 估时复盘 | `scripts/time-estimation-calibration.sh` | 只统计 `timing_source=timestamp` 样本 |
| 长任务连续推进 | `docs/ai-work-orchestration/share/sinan-continuous-execution-guide.md` | 先估时，达成可验收结果后立即收口 |

## 本地命令

开工前优先使用 run-local timer，避免复用 `/tmp` 旧时间戳：

```bash
./scripts/execution-timer.sh start \
  --run-id <run-id> \
  --name <slice-name> \
  --estimate-minutes 10-15 \
  --basis "本地脚本小改 + toolchain 验证 + Obsidian generated 同步" \
  --task-type local_script_patch \
  --stop-condition "可验收切片完成或触发审批边界"
```

收工后：

```bash
./scripts/execution-timer.sh close \
  --run-id <run-id> \
  --name <slice-name> \
  --max-age-minutes 180
```

`execution-timer` 会读取 `runs/<run-id>/timers/<slice-name>.start.json`，生成 `runs/<run-id>/execution-time-contract-<slice-name>.md/json`，并把 marker 标记为 `closed`。如果 marker 超过 `--max-age-minutes`，必须拒绝收工，防止把过期计时当成真实耗时。
