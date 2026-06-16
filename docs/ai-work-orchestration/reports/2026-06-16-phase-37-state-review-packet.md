# 阶段报告：Phase 37 State Evidence and Review Packet

## 目标

把状态判断从一次性命令输出推进到可沉淀、可复核的 run evidence，并让 review packet 能直接看到建议状态。

## 已完成

- `scripts/evaluate-state.sh` 新增 `--write-run`。
- `--write-run` 会生成：
  - `runs/<run-id>/state-evaluation.json`
  - `runs/<run-id>/state-evaluation.md`
- `scripts/review-packet.sh` 新增状态列：
  - `Suggested State`
  - `Next Actor`
- 更新 `docs/ai-work-orchestration/11-loop-state-machine.md`，把状态 artifact 写入作为已具备能力。

## 示例

```bash
./scripts/evaluate-state.sh \
  --issue FUZ-554 \
  --run-id FUZ-554-scope-split-review \
  --write-run
```

生成后，review packet 会显示：

```text
FUZ-554-scope-split-review -> review_ready / reviewer
```

## 验证结果

已执行：

```bash
bash -n scripts/evaluate-state.sh
./scripts/evaluate-state.sh --issue FUZ-554 --run-id FUZ-554-scope-split-review --write-run
./scripts/review-packet.sh --case FUZ-554 --pattern 'FUZ-554*'
./scripts/verify-toolchain.sh --case FUZ-554 --pattern 'FUZ-554*' --strict
```

结果：

- `state-evaluation.json` 和 `state-evaluation.md` 可生成。
- review packet 能读取已生成状态，未生成的 run 显示 `not evaluated`。
- strict toolchain 继续通过。

## 边界

- 写入仅限本地 run 目录。
- 不写 Multica。
- 不改变 issue 状态。
- 不把 `not evaluated` 当失败；它只表示该 run 尚未生成状态 artifact。

## 下一步

- 在 Multica comment 草稿里展示建议状态。
- 后续再决定是否把建议状态同步到 issue metadata。
