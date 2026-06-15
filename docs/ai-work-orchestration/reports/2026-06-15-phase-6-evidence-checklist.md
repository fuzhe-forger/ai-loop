# 阶段报告：Phase 6 证据标准化试点

## 目标

在文档型和脚本型低风险试点之后，进一步标准化每次案例复盘的证据检查方式，降低人工复核成本。

## 任务

新增 `scripts/evidence-checklist.sh`，根据 `runs/<run-id>/` 生成 Markdown 证据清单。

## 已完成

- 支持 `--run-id <run-id>` 输出证据清单。
- 支持 `--output <file>` 显式写入本地文件。
- 检查 `summary.md`、`stage-report.md`、`multica-comment.md`、`writeback-summary.md` 是否存在。
- 在案例执行指南中加入证据清单用法。

## 风险边界

- 只读取本地 `runs/` 目录。
- 只在显式 `--output` 时写本地文件。
- 不读取 Multica issue。
- 不写 Multica comment/status。
- 不 push、不 commit、不创建 MR。

## 验证结果

本阶段验证命令均已通过：

```bash
bash -n scripts/evidence-checklist.sh
./scripts/evidence-checklist.sh --run-id FUZ-554-script-policy-help-pilot
./scripts/evidence-checklist.sh --run-id FUZ-554-script-policy-help-pilot --output runs/FUZ-554-evidence-checklist-pilot/checklist.md
test -s runs/FUZ-554-evidence-checklist-pilot/checklist.md
```

同时验证缺失 run 目录会返回非零退出，避免误报证据完整。

## 结论

证据标准化试点成立。后续每个案例都可以通过 `scripts/evidence-checklist.sh` 生成一份 checklist，作为人工复核入口。
