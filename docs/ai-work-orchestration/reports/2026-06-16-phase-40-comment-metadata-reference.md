# 阶段报告：Phase 40 Comment Metadata Reference

## 目标

让 `multica-comment.md` 草稿不仅展示建议状态，还能引用本地 issue metadata 草稿，形成从 run evidence 到 comment draft 的完整可追踪链路。

## 已完成

- 更新 `scripts/multica-loop.sh`。
- dry-run 后生成：
  - `state-evaluation.json`
  - `state-evaluation.md`
  - `metadata-draft.json`
  - `metadata-draft.md`
- `multica-comment.md` 新增 metadata draft 路径。
- `stage-report.md` 新增 metadata draft JSON 路径。

## 链路

```text
run evidence
  -> state-evaluation.json/md
  -> metadata-draft.json/md
  -> multica-comment.md
  -> stage-report.md
```

## 验证结果

已使用本地 fake Multica 和 fake ai-loop 验证：

- comment 草稿包含 `Metadata draft`。
- stage report 包含 `Metadata draft`。
- metadata draft 生成 `pipeline_status=review_ready`、`next_actor=reviewer`。
- 未传 `--write-comment` 时不发生远端写入。

已执行：

```bash
./scripts/verify-toolchain.sh --case FUZ-554 --pattern 'FUZ-554*' --strict
```

结果：strict toolchain 通过。

## 边界

- metadata 仍然只是本地草稿。
- 不写 Multica issue metadata。
- 不改变 Multica issue status。
- comment 中引用 metadata，不代表 metadata 已同步远端。

## 下一步

- 设计 metadata 写回命令的显式授权策略。
- 在 writeback summary 中区分 comment、status、metadata 三类远端副作用。
