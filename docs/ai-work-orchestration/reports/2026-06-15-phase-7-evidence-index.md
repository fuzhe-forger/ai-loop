# 阶段报告：Phase 7 跨 run 证据索引试点

## 目标

在单 run evidence checklist 的基础上，生成同一案例下多个 run 的证据索引，方便团队复盘时快速判断证据完整度。

## 任务

新增 `scripts/evidence-index.sh`，按 `runs/<pattern>` 汇总多个 run 的核心证据状态。

## 已完成

- 支持 `--pattern <glob>` 输出 Markdown 表格。
- 支持 `--output <file>` 显式写入本地文件。
- 汇总 `summary.md`、`stage-report.md`、`multica-comment.md`、`writeback-summary.md`。
- 在案例执行指南中加入多 run 索引用法。

## 风险边界

- 只读取本地 `runs/` 目录。
- 只在显式 `--output` 时写本地文件。
- 不读取 Multica issue。
- 不写 Multica comment/status。
- 不 push、不 commit、不创建 MR。

## 验证结果

本阶段验证命令均已通过：

```bash
bash -n scripts/evidence-index.sh
./scripts/evidence-index.sh --pattern 'FUZ-554*'
./scripts/evidence-index.sh --pattern 'FUZ-554*' --output runs/FUZ-554-evidence-index-pilot/index.md
test -s runs/FUZ-554-evidence-index-pilot/index.md
```

同时验证无匹配 pattern 会返回非零退出，避免误报索引存在。

## 结论

跨 run 证据索引试点成立。`FUZ-554` 现在可以通过 `runs/FUZ-554-evidence-index-pilot/index.md` 查看多个 run 的证据完整度。
