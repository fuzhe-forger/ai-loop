# 司南连续执行指南

## 目标

当用户说“执行 / 推 / 继续 / Loop 到需要审批”时，司南默认按任务等级连续推进，不把小脚本、小同步、小验证当作整轮成果。

## 默认判断

任务等级与时间盒的权威配置是 `config/timebox-policy.json`；脚本读取该配置，避免 preflight、closeout、continuation gate 规则漂移。

| 信号 | 等级 | 行为 |
|---|---|---|
| 解释、复查、只读本地事实 | L0 | 直接完成，不写报告 |
| 小文档、小脚本、小修复 | L1 | 至少完成一个可验证切片 |
| 有 issue、task、run、写回或 evidence | L2 | 预估 90 分钟；可验收 closeout + writeback/readback 后立即收口，不为凑时间继续 |
| 需求不清、多系统、高风险 | L3 | 分阶段 closeout，审批边界前停下 |
| Git remote、deploy、install、global config、破坏性操作 | L4 | 停下等单独审批 |

## 执行顺序

1. 读取任务目标、验收标准、边界和已授权副作用。
2. 先输出预计耗时、估时依据和 `started_at`，再运行或更新 `loop-execution-preflight`，明确本轮等级、时间盒、写回策略。
3. 做第一组实质交付：代码、脚本、文档、证据或写回草稿。
4. 运行最小必要验证；验证通过后继续下一组实质交付，不主动汇报收工。
5. 阶段完成时运行 `loop-continuation-gate` 判断是否允许停下。
6. gate 返回 `ALLOW_STOP` 时立即输出最终总结；`loop-closeout` 同步生成 `time-estimation-calibration.md/json`，记录预估耗时、计时来源、时间戳耗时和可信偏差。

长 Loop 中默认开启输出节流：中间进展用短句，重复事实不展开；用户要求压缩、或上下文消耗成为风险时，可使用 Caveman/Cavecrew skill。审批、风险、证据和代码内容保持清晰完整，不为省 token 牺牲可审计性。

## 必跑命令

```bash
./scripts/loop-execution-preflight.sh --issue <issue> --task <task> --repo <repo> --run-id <run> --task-tier L2 --task-type <type> --no-phase-report --no-operation-log
./scripts/loop-closeout.sh --issue <issue> --task <task> --repo <repo> --run-id <run> --task-tier L2 --started-at <iso> --completed-at <iso> --no-phase-report --no-operation-log
./scripts/loop-continuation-gate.sh --issue <issue> --run-id <run> --task-tier L2 --started-at <iso> --completed-at <iso>
```

从 Multica 进入本地 Loop 时，主入口也要带上时间盒参数，让 run 目录自动留下 preflight 与 continuation gate：

```bash
./scripts/multica-loop.sh --issue <issue> --repo <repo> --task-tier L2 --status-policy no-status
```

`loop-closeout.sh` 与 `multica-loop.sh` 默认在脚本启动和 gate 前自动记录 UTC 时间戳；只有时间戳缺失时才允许用 `--elapsed-minutes` 作为 manual 回退，且 manual 不进入可信校准统计。

`loop-closeout.sh` 与 `multica-loop.sh` 都会自动调用 `time-estimation-calibration.sh`，所以正式收口后 run 目录必须同时存在 `continuation-gate.json` 和 `time-estimation-calibration.json`。

Phase I 要求汇报 `absolute_error_minutes` 和 `within_one_minute`。repo-backed 切片统一用 `scripts/execution-timer.sh start/close`，marker 固定写入 `runs/<run-id>/timers/<slice>.start.json`，收工时生成 `execution-time-contract-<slice>.json`；禁止用 `/tmp` 临时 marker 作为可信耗时来源。如果本轮误差超过 1 分钟，下轮应缩小切片或显式选择更准确的 `--task-type` 校准桶。

## 不早停规则

- 小脚本通过、一次 Obsidian 同步完成、单个文档落地，只能算阶段进展。
- L2 不为凑满 90 分钟继续执行；可验收结果完成后尽快收口。
- L2 如果低于防空转阈值且没有可验收结果，则继续推进下一组明确切片。
- L2 到预估时间仍未 closeout / writeback/readback，则继续补齐证据，不用反复询问。
- 连续 3 次同类失败、触发 L4 禁止项、缺少不可推断的外部事实时才停。

## 续跑切片候选

当一个切片完成但不能停下时，按优先级选择下一项：

1. 把刚完成的机制接入 `verify-toolchain`。
2. 补齐 README / share docs 的可发现入口。
3. 跑 closeout 并把 evidence 同步到 Obsidian generated。
4. 把可复用判断脚本化，减少下次 token 与人工审批。
5. 做一次 readback / generated 文件校验，证明写回或同步可复查。

如果用户要求“多安排一些任务”或“连续工作 30 分钟”，先生成 Phase I 任务队列：

```bash
./scripts/phase-i-task-queue.sh --run-id <run> --target-minutes 30 --output runs/<run>/phase-i-task-queue.md --json-output runs/<run>/phase-i-task-queue.json
```

队列按当前 `time-estimation-calibration.json`、`execution-preflight.json` 和能力注册表生成，优先补低样本估时桶、低 `<1 分钟` 命中率、分享/复核可见性和最终 evidence 同步。

队列必须包含 `status`、`status_reason`、`open_minutes` 和 `done_minutes`：

- `todo` 代表仍可执行的下一切片，优先排入 30 分钟窗口。
- `done` 代表已有 evidence 证明完成，不再当作待办消耗窗口。
- `open_minutes` 低于目标时，继续从低样本桶、低命中率桶或本地同步读回补任务。
- `done_minutes` 只用于复盘，不可用来解释“连续工作已排满”。

## 任务量优先估时

北极星任务使用 `task_quantity_first_calibration_second`：先按任务量拆解原始估时，再用历史桶做小权重修正。

```bash
./scripts/north-star-task-board.sh --run-id <run> --target-minutes 30 --output runs/<run>/north-star-task-board.md --json-output runs/<run>/north-star-task-board.json
```

估时字段含义：

- `raw_estimate_minutes`：根据当前任务量、产物数量、验证步骤和同步读回直接估算。
- `calibrated_estimate_minutes`：用历史桶修正后的估时；当桶样本数不少于 3 时，按 `raw*0.8 + bucket*0.2` 计算。
- `calibration_confidence`：历史桶可信度；`high` 只代表修正依据充足，不代表可以跳过任务量拆解。
- `selected_slice`：下一批要执行的开放任务；只选 `todo/partial/blocked`，不把 `done` 项算进待执行时间。

执行后必须用真实 `execution-time-contract*.json` 更新经验；每个契约都要能追溯到 run-local timer marker 或明确的 `started_at/completed_at`。如果实际耗时和 `calibrated_estimate_minutes` 偏差超过 1 分钟，下轮要调整任务拆分或原始估时，而不是只调整历史桶。

## 汇报口径

最终汇报只包含：

- 改了什么文件和行为。
- 哪些验证通过。
- 是否产生外部副作用和 readback。
- continuation gate 为什么允许停下，或为什么必须继续 / 等审批。
- 预计耗时、实际用时、是否命中预估范围、下次估时校准建议。

## 长循环进展压缩

连续工作块内，进展更新遵守“短句 + 证据优先”：

- 中间更新只说当前切片、验证状态和下一动作，不重复完整背景。
- 遇到审批、风险、不可逆动作、外部写入时恢复完整表达，不使用会造成歧义的压缩。
- 代码、命令、文件路径、证据字段保持原样，不用 caveman 风格改写。
- 子任务回传优先使用表格或 JSON evidence，减少散文式总结。
- 最终汇报再集中说明产物、验证、副作用、耗时误差和下一轮估时。
