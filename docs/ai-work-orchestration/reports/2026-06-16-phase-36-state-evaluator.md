# 阶段报告：Phase 36 Local State Evaluator

## 目标

把 Phase 35 的 Multica Loop 状态机落到第一个本地脚本：读取 run evidence，输出建议状态、下一角色和原因。

## 已完成

- 新增 `scripts/evaluate-state.sh`。
- 更新 `scripts/verify-toolchain.sh`，把状态判断脚本纳入 smoke checks。
- 更新 `docs/ai-work-orchestration/11-loop-state-machine.md`，明确 `evaluate-state.sh` 是状态判断落点。

## 用法

```bash
./scripts/evaluate-state.sh \
  --issue FUZ-554 \
  --run-id FUZ-554-scope-split-review \
  --output /tmp/fuz554-state.json \
  --markdown /tmp/fuz554-state.md
```

不传 `--issue` 时，脚本会从 `run-id` 前缀自动识别类似 `FUZ-554` 的 issue。

## 当前判定规则

| 条件 | 建议状态 | 下一角色 |
|---|---|---|
| 缺 Core Evidence | `blocked` | `execution_agent` |
| Core Evidence 齐，缺验证报告 | `evidence_ready` | `execution_agent` |
| Core Evidence 齐，验证报告存在 | `review_ready` | `reviewer` |
| writeback summary 存在 | `done` | `human` |

## 验证结果

已执行：

```bash
bash -n scripts/evaluate-state.sh
./scripts/evaluate-state.sh --issue FUZ-554 --run-id FUZ-554-scope-split-review
./scripts/evaluate-state.sh --run-id FUZ-554-scope-split-review
./scripts/verify-toolchain.sh --case FUZ-554 --pattern 'FUZ-554*' --strict
```

结果：

- 正向 run 输出 `evidence_ready -> review_ready`。
- 缺 core evidence 的临时负向 run 输出 `running -> blocked`。
- 工具链 strict smoke 通过，并包含 `evaluate-state` 检查。

## 边界

- 只读本地 `runs/`。
- 不读取 Multica。
- 不写 Multica comment 或 status。
- `side_effects_allowed` 当前固定为 `false`，后续由 policy 层决定。

## 下一步

- 把 state evaluation 输出写回 run evidence。
- 在 review packet 中展示建议状态。
- 后续再接入 Multica comment 草稿，不直接改远端状态。
