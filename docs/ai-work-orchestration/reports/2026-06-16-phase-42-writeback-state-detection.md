# 阶段报告：Phase 42 Writeback State Detection

## 目标

修正状态机判断：`writeback-summary.md` 的存在不再直接代表 `done`，必须确认里面有实际远端写入完成标记。

## 背景

Phase 41 后，`scripts/multica-loop.sh` 会在每次运行时生成 `writeback-summary.md`。

如果 `evaluate-state` 仍然只按文件存在判断，就会把“没有远端写入、只是生成 summary”的 run 错判为 `done`。

## 已完成

- 更新 `scripts/evaluate-state.sh`。
- 新增 `remote_write_completed` 检查。
- 兼容旧格式 writeback summary：`Comment ID:`。
- 兼容新格式 writeback summary：`Comment written: true`、`Status written: true`、`Metadata written: true`。
- 失败标记会阻止完成判定：`failed`。

## 新规则

| 条件 | 建议状态 |
|---|---|
| `writeback-summary.md` 不存在 | 按 evidence/verification 判断 |
| `writeback-summary.md` 存在但没有完成标记 | 不判 `done` |
| `writeback-summary.md` 存在且有远端写入完成标记 | `done` |

## 验证结果

已验证三种情况：

- `FUZ-554-scope-split-review`：没有实际远端写入，输出 `review_ready`。
- 旧格式真实回写 run：含 `Comment ID:`，输出 `done`。
- 新格式但全为 `false` 的临时 run：输出 `review_ready`。

已执行：

```bash
./scripts/verify-toolchain.sh --case FUZ-554 --pattern 'FUZ-554*' --strict
```

结果：strict toolchain 通过。

## 结论

状态机现在区分：

- writeback evidence 已生成。
- 远端写入实际完成。

这避免了 evidence 完整性增强后误推进到 `done`。
