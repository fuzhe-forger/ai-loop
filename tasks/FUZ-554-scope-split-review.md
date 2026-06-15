# FUZ-554-U Scope Split Review

## 背景

Phase 23 的提交前 patch summary 显示 strict evidence gate 通过，但 scope check 失败。失败原因是当前工作树同时包含 FUZ-554 工具链/文档/任务产物和早先 AI Loop 核心代码改动，需要在提交前拆分或人工确认范围。

## 目标

生成提交前 scope split 复核包，把当前改动分为：FUZ-554 工具链/文档/任务组、AI Loop 核心代码组、其他 issue 任务草稿组、ignored 本地 evidence 组。

## Scope

允许修改：

- `docs/ai-work-orchestration/reports/2026-06-15-phase-24-scope-split-review.md`
- `runs/FUZ-554-scope-split-review/`
- `tasks/FUZ-554-scope-split-review.md`
- `docs/ai-work-orchestration/logbook.md`

## Out of scope

- 不修改功能代码
- 不删除文件
- 不 git add/commit/stash/reset
- 不读取 Multica issue
- 不自动写 Multica comment/status
- 不 push、不创建 MR

## 验收标准

- 输出 scope split report。
- 明确哪些文件适合进入 FUZ-554 工具链/文档提交。
- 明确哪些文件需要独立复核或拆分提交。
- 明确 `runs/` 被 `.gitignore` 忽略但仍作为本地 evidence 存在。
- 保持 strict evidence gate 通过。

## 验证命令

```bash
git status --porcelain=v1
./scripts/verify-toolchain.sh --case FUZ-554 --pattern 'FUZ-554*' --strict --output runs/FUZ-554-scope-split-review/verification-report.md
```
