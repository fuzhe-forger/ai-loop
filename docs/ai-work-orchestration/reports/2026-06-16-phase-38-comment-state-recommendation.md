# 阶段报告：Phase 38 Comment State Recommendation

## 目标

把 Multica Loop 的本地状态判断结果写入 `multica-comment.md` 草稿，让 reviewer 在准备回写前直接看到建议状态和下一角色。

## 已完成

- 更新 `scripts/multica-loop.sh`。
- dry-run 后生成 `state-evaluation.json` 和 `state-evaluation.md`。
- `multica-comment.md` 新增：
  - `Suggested Loop state`
  - `Next actor`
  - `Loop State Recommendation`
- `stage-report.md` 新增状态建议区块和 state evaluation 路径。

## 行为边界

- 默认仍然不写 Multica comment。
- 默认仍然不改 Multica status。
- 状态建议只是本地 recommendation，不是远端状态变更。
- 远端写入仍由 `--write-comment`、`--write-status` 和既有 policy 控制。

## 验证结果

已使用本地 fake Multica 和 fake ai-loop 验证：

- `multica-comment.md` 会出现建议状态。
- `stage-report.md` 会出现建议状态和 state evaluation 路径。
- 未传 `--write-comment` 时不发生远端写入。

已执行工具链校验：

```bash
bash -n scripts/multica-loop.sh
./scripts/verify-toolchain.sh --case FUZ-554 --pattern 'FUZ-554*' --strict
```

结果：strict toolchain 通过。

## 示例输出

```text
Suggested Loop state: evidence_ready
Next actor: execution_agent
Reason: core evidence complete; verification report is not present
```

## 下一步

- 把 comment 草稿中的建议状态进一步接入 issue metadata 设计。
- 仍先保持 metadata 写入为显式授权动作。
