# 阶段报告：Phase 8 复核包生成试点

## 目标

在 evidence checklist 和 evidence index 的基础上，生成一份更适合人类审阅的 review packet，把证据状态、复核问题和建议决策集中到一个文档中。

## 任务

新增 `scripts/review-packet.sh`，按 case 和 run pattern 生成案例级复核包。

## 已完成

- 支持 `--case <case-id>` 标记案例范围。
- 支持 `--pattern <glob>` 汇总多个 run。
- 支持 `--output <file>` 显式写入本地文件。
- 输出 run 数量、核心证据完整度、writeback 数量、复核问题和建议决策。
- 在案例执行指南中加入复核包用法。

## 风险边界

- 只读取本地 `runs/` 目录。
- 只在显式 `--output` 时写本地文件。
- 不读取 Multica issue。
- 不写 Multica comment/status。
- 不 push、不 commit、不创建 MR。

## 验证结果

本阶段验证命令均已通过：

```bash
bash -n scripts/review-packet.sh
./scripts/review-packet.sh --case FUZ-554 --pattern 'FUZ-554*'
./scripts/review-packet.sh --case FUZ-554 --pattern 'FUZ-554*' --output runs/FUZ-554-review-packet-pilot/review-packet.md
test -s runs/FUZ-554-review-packet-pilot/review-packet.md
```

同时验证无匹配 pattern 会返回非零退出，避免误报复核包存在。

## 结论

复核包生成试点成立。`FUZ-554` 现在可以通过 `runs/FUZ-554-review-packet-pilot/review-packet.md` 作为人工复核入口。
