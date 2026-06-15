# 阶段报告：Phase 13 Patch 证据化试点

## 目标

把真实代码改动的 patch 元信息纳入证据体系，让复核者先看到 changed files、diff stat 和复核问题，再决定是否深入查看完整 diff。

## 任务

新增 `scripts/patch-summary.sh`，读取本地 `git diff` 元信息并生成 Markdown patch summary。

## 已完成

- 支持 `--base <git-ref>`，默认 `HEAD`。
- 支持 `--output <file>` 写入本地文件。
- 输出 tracked changed files、untracked files、diff stat 和 review questions。
- 在案例执行指南中加入 patch summary 用法。

## 风险边界

- 只读取本地 git diff 元信息。
- 只在显式 `--output` 时写本地文件。
- 不读取 Multica issue。
- 不写 Multica status。
- 不 push、不 commit、不创建 MR。

## 验证结果

本阶段验证命令均已通过：

```bash
bash -n scripts/patch-summary.sh
./scripts/patch-summary.sh --base HEAD --output runs/FUZ-554-patch-summary-pilot/patch-summary.md
test -s runs/FUZ-554-patch-summary-pilot/patch-summary.md
rg -n "Tracked Changed Files|Untracked Files|Diff Stat|Review Questions" runs/FUZ-554-patch-summary-pilot/patch-summary.md
```

同时验证 invalid git ref 会返回非零退出，避免误生成 patch summary。

## 结论

Patch 证据化试点成立。后续代码改动任务可以先生成 patch summary，再进入完整 diff 复核。当前摘要同时覆盖 tracked diff 和 untracked files，避免遗漏新建证据或脚本文件。
