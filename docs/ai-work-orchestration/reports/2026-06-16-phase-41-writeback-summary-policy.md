# 阶段报告：Phase 41 Writeback Summary Policy

## 目标

把 Multica Loop 的远端副作用拆成 comment、status、metadata 三类，并确保每次 wrapper 运行都会生成 `writeback-summary.md`。

## 已完成

- 更新 `docs/ai-work-orchestration/04-status-policy.md`。
- 更新 `docs/ai-work-orchestration/12-issue-metadata-contract.md`。
- 更新 `scripts/multica-loop.sh`。
- wrapper 现在生成 `runs/<run-id>/writeback-summary.md`。

## 三类远端副作用

| 类型 | 当前能力 | 默认行为 |
|---|---|---|
| comment | `--write-comment` | 不写 |
| status | `--write-status` | 不写 |
| metadata | 暂不实现远端写入 | 只生成本地草稿 |

## Writeback summary 内容

`writeback-summary.md` 记录：

- issue 和 run id。
- comment draft 路径。
- metadata draft 路径。
- comment/status/metadata 写入请求。
- comment/status/metadata 写入结果。
- 写入失败日志路径。

即使没有任何远端写入请求，也会生成该文件。

## 验证结果

已使用本地 fake Multica 和 fake ai-loop 验证：

- `writeback-summary.md` 可生成。
- `metadata_written=false`。
- `write_metadata_requested=false`。
- 未传 `--write-comment` / `--write-status` 时不发生远端写入。

已执行：

```bash
./scripts/verify-toolchain.sh --case FUZ-554 --pattern 'FUZ-554*' --strict
```

结果：strict toolchain 通过。

## 边界

- metadata 远端写入仍未实现。
- status 写入仍受 `--write-status` 和 `status-policy` 控制。
- comment 写入仍受 `--write-comment` 控制。
- 本阶段只增强 evidence，不扩大远端副作用。

## 下一步

- 让 `evaluate-state` 读取更细的 writeback summary 字段。
- 后续再设计 metadata 远端写入命令和审批策略。
